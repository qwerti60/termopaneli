<?php
declare(strict_types=1);

/**
 * POST — намерение оплатить выбранный тариф (заглушка: эквайринг не подключён).
 * Тело JSON: { "plan_code": "1m" | "3m" | "6m" | "1y" }
 *
 * Всегда пишет событие в subscription_payment_events и отвечает 200 с ok:false и кодом acquiring_not_configured.
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
    tp_subscription_log_event(
        $pdo,
        $userId,
        null,
        $code,
        $price,
        'checkout_stub',
        'Эквайринг не подключён; оплата недоступна (заглушка).'
    );
    tp_json_response(200, [
        'ok' => false,
        'code' => 'acquiring_not_configured',
        'message' => 'Онлайн-оплата пока не подключена. Выберите другой способ или свяжитесь с офисом — после подключения эквайринга оплата заработает в приложении.',
    ]);
} catch (Throwable $e) {
    error_log('subscription/checkout: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
