<?php
declare(strict_types=1);

require_once __DIR__ . '/subscription_plans.php';

/**
 * Оформляет PRO без эквайринга: при отсутствии активной подписки создаёт новую active на срок тарифа, обновляет is_pro.
 * Если уже есть неистёкшая active — возвращает строку ALREADY_ACTIVE (не заменяет подписку).
 *
 * @return array{subscription_id: int, plan_code: string, expires_at: string}|string сообщение об ошибке или ALREADY_ACTIVE
 */
function tp_subscription_activate_without_acquiring(
    PDO $pdo,
    int $userId,
    string $planCode
): array|string {
    if ($userId <= 0) {
        return 'Некорректный пользователь';
    }
    $plan = tp_subscription_plan_by_code($planCode);
    if ($plan === null) {
        return 'Неизвестный тариф';
    }
    $code = strtolower(trim($planCode));
    $price = round((float) $plan['price_rub'], 2);
    $months = (int) $plan['months'];
    if ($months < 1) {
        $months = 1;
    }

    tp_subscription_refresh_is_pro($pdo, $userId);
    if (tp_subscription_active_row($pdo, $userId) !== null) {
        return 'ALREADY_ACTIVE';
    }

    $pdo->beginTransaction();
    try {
        $end = $pdo->prepare(
            'SELECT DATE_ADD(NOW(), INTERVAL ? MONTH) AS e'
        );
        $end->execute([$months]);
        $expRow = $end->fetch(PDO::FETCH_ASSOC);
        $expiresAt = $expRow === false ? null : (string) ($expRow['e'] ?? '');
        if ($expiresAt === '') {
            $pdo->rollBack();

            return 'Не удалось вычислить дату окончания';
        }

        $ins = $pdo->prepare(
            "INSERT INTO user_subscriptions
                (user_id, plan_code, status, price_rub, started_at, expires_at, created_at, updated_at)
             VALUES (?, ?, 'active', ?, NOW(), ?, NOW(), NOW())"
        );
        $ins->execute([$userId, $code, $price, $expiresAt]);
        $subId = (int) $pdo->lastInsertId();

        tp_subscription_log_event(
            $pdo,
            $userId,
            $subId > 0 ? $subId : null,
            $code,
            $price,
            'activated_no_acquiring',
            'Подписка оформлена без оплаты: эквайринг не подключён, активация по кнопке в приложении.'
        );
        tp_subscription_refresh_is_pro($pdo, $userId);
        $pdo->commit();

        return [
            'subscription_id' => $subId,
            'plan_code' => $code,
            'expires_at' => $expiresAt,
        ];
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        error_log('tp_subscription_activate_without_acquiring: ' . $e->getMessage());

        return 'Ошибка записи подписки';
    }
}

/**
 * Помечает просроченные active как expired, затем выставляет user_profiles.is_pro по наличию активной подписки.
 */
function tp_subscription_refresh_is_pro(PDO $pdo, int $userId): void
{
    if ($userId <= 0) {
        return;
    }
    $now = gmdate('Y-m-d H:i:s');
    $upd = $pdo->prepare(
        "UPDATE user_subscriptions
         SET status = 'expired', updated_at = NOW()
         WHERE user_id = ? AND status = 'active'
           AND expires_at IS NOT NULL AND expires_at <= NOW()"
    );
    $upd->execute([$userId]);

    $st = $pdo->prepare(
        "SELECT COUNT(*) FROM user_subscriptions
         WHERE user_id = ? AND status = 'active'
           AND (expires_at IS NULL OR expires_at > NOW())"
    );
    $st->execute([$userId]);
    $n = (int) $st->fetchColumn();
    $pro = $n > 0 ? 1 : 0;
    $u = $pdo->prepare('UPDATE user_profiles SET is_pro = ? WHERE id = ? LIMIT 1');
    $u->execute([$pro, $userId]);
}

function tp_subscription_log_event(
    PDO $pdo,
    int $userId,
    ?int $subscriptionId,
    string $planCode,
    float $amountRub,
    string $eventType,
    ?string $detail = null
): void {
    if ($userId <= 0) {
        return;
    }
    $st = $pdo->prepare(
        'INSERT INTO subscription_payment_events
            (user_id, subscription_id, plan_code, amount_rub, event_type, detail, created_at)
         VALUES (?, ?, ?, ?, ?, ?, UTC_TIMESTAMP())'
    );
    $st->execute([
        $userId,
        $subscriptionId,
        $planCode,
        round($amountRub, 2),
        $eventType,
        $detail !== null && $detail !== '' ? mb_substr($detail, 0, 512) : null,
    ]);
}

/**
 * @return array<string, mixed>|null активная строка user_subscriptions или null
 */
function tp_subscription_active_row(PDO $pdo, int $userId): ?array
{
    if ($userId <= 0) {
        return null;
    }
    $st = $pdo->prepare(
        "SELECT id, user_id, plan_code, status, price_rub, started_at, expires_at, cancelled_at, created_at
         FROM user_subscriptions
         WHERE user_id = ? AND status = 'active'
           AND (expires_at IS NULL OR expires_at > NOW())
         ORDER BY id DESC
         LIMIT 1"
    );
    $st->execute([$userId]);
    $row = $st->fetch(PDO::FETCH_ASSOC);

    return $row === false ? null : $row;
}

/**
 * @return array{is_pro: bool, subscription: array<string, mixed>|null}
 */
function tp_subscription_status_payload(PDO $pdo, int $userId): array
{
    tp_subscription_refresh_is_pro($pdo, $userId);
    $st = $pdo->prepare('SELECT COALESCE(is_pro, 0) AS is_pro FROM user_profiles WHERE id = ? LIMIT 1');
    $st->execute([$userId]);
    $proRow = $st->fetch(PDO::FETCH_ASSOC);
    $isPro = (int) ($proRow['is_pro'] ?? 0) === 1;

    $active = tp_subscription_active_row($pdo, $userId);
    $sub = null;
    if ($active !== null) {
        $code = (string) ($active['plan_code'] ?? '');
        $meta = tp_subscription_plan_by_code($code);
        $sub = [
            'id' => (int) $active['id'],
            'plan_code' => $code,
            'plan_title' => $meta['title'] ?? $code,
            'status' => (string) $active['status'],
            'price_rub' => (float) $active['price_rub'],
            'started_at' => $active['started_at'] !== null ? (string) $active['started_at'] : null,
            'expires_at' => $active['expires_at'] !== null ? (string) $active['expires_at'] : null,
        ];
    }

    return ['is_pro' => $isPro, 'subscription' => $sub];
}

/**
 * @return true|string
 */
function tp_subscription_cancel_active(PDO $pdo, int $userId)
{
    if ($userId <= 0) {
        return 'Некорректный пользователь';
    }
    $now = gmdate('Y-m-d H:i:s');
    $st = $pdo->prepare(
        "UPDATE user_subscriptions
         SET status = 'cancelled', cancelled_at = ?, updated_at = ?
         WHERE user_id = ? AND status = 'active'"
    );
    $st->execute([$now, $now, $userId]);
    if ($st->rowCount() < 1) {
        return 'Нет активной подписки';
    }
    tp_subscription_log_event($pdo, $userId, null, '', 0.0, 'subscription_cancelled', 'Пользователь отменил в приложении');
    tp_subscription_refresh_is_pro($pdo, $userId);

    return true;
}
