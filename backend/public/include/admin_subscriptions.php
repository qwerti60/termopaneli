<?php
declare(strict_types=1);

/**
 * Подписчики: пользователи с активной подпиской (строка в user_subscriptions) или флагом is_pro=1.
 *
 * @return list<array<string, mixed>>
 */
function tp_admin_subscribers_list(PDO $pdo, int $limit): array
{
    if ($limit < 1) {
        $limit = 100;
    }
    if ($limit > 500) {
        $limit = 500;
    }
    $lim = (int) $limit;
    $sql = 'SELECT u.id, u.phone, u.last_name, u.first_name, u.middle_name, u.email,
                   COALESCE(u.is_pro, 0) AS is_pro,
                   s.id AS subscription_id, s.plan_code, s.status AS subscription_status,
                   s.price_rub, s.started_at, s.expires_at, s.cancelled_at, s.created_at AS subscription_created
            FROM user_profiles u
            LEFT JOIN user_subscriptions s
              ON s.user_id = u.id
             AND s.status = \'active\'
             AND (s.expires_at IS NULL OR s.expires_at > NOW())
            WHERE COALESCE(u.is_pro, 0) = 1
               OR s.id IS NOT NULL
            ORDER BY u.id DESC
            LIMIT ' . $lim;

    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}

/**
 * Краткая сводка для главной страницы раздела «Подписки» в веб-админке.
 * Запросы независимы: при отсутствии таблицы/колонки по миграции соответствующий счётчик = 0 и в [warnings] попадает пояснение.
 *
 * @return array{active_subs: int, is_pro_users: int, events_last_30d: int, warnings: list<string>}
 */
function tp_admin_subscriptions_stats(PDO $pdo): array
{
    $out = [
        'active_subs' => 0,
        'is_pro_users' => 0,
        'events_last_30d' => 0,
        'warnings' => [],
    ];

    try {
        $st = $pdo->query(
            "SELECT COUNT(*) FROM user_subscriptions
             WHERE status = 'active'
               AND (expires_at IS NULL OR expires_at > NOW())"
        );
        if ($st !== false) {
            $out['active_subs'] = (int) $st->fetchColumn();
        }
    } catch (Throwable $e) {
        error_log('tp_admin_subscriptions_stats active_subs: ' . $e->getMessage());
        $out['warnings'][] = tp_admin_subscriptions_stats_hint($e, 'user_subscriptions');
    }

    try {
        $st = $pdo->query('SELECT COUNT(*) FROM user_profiles WHERE COALESCE(is_pro, 0) = 1');
        if ($st !== false) {
            $out['is_pro_users'] = (int) $st->fetchColumn();
        }
    } catch (Throwable $e) {
        error_log('tp_admin_subscriptions_stats is_pro: ' . $e->getMessage());
        $out['warnings'][] = tp_admin_subscriptions_stats_hint($e, 'user_profiles.is_pro');
    }

    try {
        $st = $pdo->query(
            "SELECT COUNT(*) FROM subscription_payment_events
             WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)"
        );
        if ($st !== false) {
            $out['events_last_30d'] = (int) $st->fetchColumn();
        }
    } catch (Throwable $e) {
        error_log('tp_admin_subscriptions_stats events: ' . $e->getMessage());
        $out['warnings'][] = tp_admin_subscriptions_stats_hint($e, 'subscription_payment_events');
    }

    return $out;
}

/**
 * Краткое сообщение для администратора по ошибке SQL.
 */
function tp_admin_subscriptions_stats_hint(Throwable $e, string $what): string
{
    $msg = $e->getMessage();
    if ($e instanceof PDOException) {
        $state = isset($e->errorInfo[0]) ? (string) $e->errorInfo[0] : '';
        if ($state === '42S02') {
            return 'Нет таблицы для «' . $what . '». Выполните на БД backend/sql/migrate_user_subscriptions.sql (и при необходимости migrate_user_profiles_is_pro.sql).';
        }
        if ($state === '42S22') {
            return 'Нет колонки в БД («' . $what . '»). Выполните backend/sql/migrate_user_profiles_is_pro.sql.';
        }
    }
    if (stripos($msg, 'Base table or view not found') !== false
        || (stripos($msg, "doesn't exist") !== false && stripos($msg, 'Table') !== false)
        || stripos($msg, '1146') !== false) {
        return 'Нет таблицы для «' . $what . '». Выполните на БД backend/sql/migrate_user_subscriptions.sql (и при необходимости migrate_user_profiles_is_pro.sql).';
    }
    if (stripos($msg, 'Unknown column') !== false || stripos($msg, '1054') !== false) {
        return 'Нет колонки в БД («' . $what . '»). Выполните backend/sql/migrate_user_profiles_is_pro.sql.';
    }

    return 'Сводка «' . $what . '»: ' . $msg;
}

/**
 * Журнал событий оплаты / подписки.
 *
 * @return list<array<string, mixed>>
 */
function tp_admin_subscription_events_list(PDO $pdo, int $limit, int $userIdFilter): array
{
    if ($limit < 1) {
        $limit = 200;
    }
    if ($limit > 2000) {
        $limit = 2000;
    }
    $lim = (int) $limit;
    if ($userIdFilter > 0) {
        $st = $pdo->prepare(
            'SELECT e.id, e.user_id, e.subscription_id, e.plan_code, e.amount_rub, e.event_type, e.detail, e.created_at,
                    u.phone, u.last_name, u.first_name
             FROM subscription_payment_events e
             JOIN user_profiles u ON u.id = e.user_id
             WHERE e.user_id = ?
             ORDER BY e.id DESC
             LIMIT ' . $lim
        );
        $st->execute([$userIdFilter]);

        return $st->fetchAll(PDO::FETCH_ASSOC) ?: [];
    }
    $sql = 'SELECT e.id, e.user_id, e.subscription_id, e.plan_code, e.amount_rub, e.event_type, e.detail, e.created_at,
                   u.phone, u.last_name, u.first_name
            FROM subscription_payment_events e
            JOIN user_profiles u ON u.id = e.user_id
            ORDER BY e.id DESC
            LIMIT ' . $lim;
    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}
