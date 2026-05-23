<?php
declare(strict_types=1);

/**
 * POST — оформление подписки при отсутствии эквайринга: сразу активирует PRO на срок тарифа.
 * Тело JSON: { "plan_code": "1m" | "3m" | "6m" | "1y" }
 *
 * Поведение: при отсутствии активной подписки создаётся новая active, is_pro обновляется,
 * в subscription_payment_events пишется activated_no_acquiring.
 * Если уже есть активная неистёкшая подписка — 409 { ok:false, code: already_subscribed } (повторно не оформляется).
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/user_bearer_guard.php';
require_once dirname(__DIR__, 3) . '/include/subscriptions_repo.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $pdo = tp_pdo();
    $userId = tp_user_require_active_json($pdo);
    $raw = file_get_contents('php://input') ?: '';
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        tp_json_response(400, ['ok' => false, 'message' => 'Ожидался JSON']);
        exit;
    }
    $code = strtolower(trim((string) ($data['plan_code'] ?? '')));
    $plan = tp_subscription_plan_by_code($code);
    if ($plan === null) {
        tp_json_response(400, ['ok' => false, 'message' => 'Неизвестный тариф']);
        exit;
    }
    $price = (float) $plan['price_rub'];
    $result = tp_subscription_activate_without_acquiring($pdo, $userId, $code);
    if ($result === 'ALREADY_ACTIVE') {
        tp_json_response(409, [
            'ok' => false,
            'code' => 'already_subscribed',
            'message' => 'У вас уже есть активная подписка PRO. Чтобы оформить другой срок, сначала отмените текущую подписку в приложении.',
        ]);
        exit;
    }
    if (is_string($result)) {
        tp_json_response(500, ['ok' => false, 'message' => $result]);
        exit;
    }
    $msg = sprintf(
        'Подписка PRO оформлена на срок тарифа. Онлайн-оплата не списывалась (эквайринг не подключён). Действует до %s.',
        $result['expires_at']
    );
    $payload = tp_subscription_status_payload($pdo, $userId);
    tp_json_response(200, [
        'ok' => true,
        'code' => 'activated_without_payment',
        'message' => $msg,
        'subscription_id' => $result['subscription_id'],
        'plan_code' => $result['plan_code'],
        'expires_at' => $result['expires_at'],
        'is_pro' => (bool) ($payload['is_pro'] ?? false),
        'subscription' => $payload['subscription'] ?? null,
    ]);
} catch (Throwable $e) {
    error_log('subscription/checkout: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
