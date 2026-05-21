<?php
declare(strict_types=1);

/**
 * GET — статус подписки PRO и активная запись (если есть).
 * Authorization: Bearer <token>
 *
 * 200: { "is_pro": bool, "subscription": null | { id, plan_code, plan_title, status, price_rub, started_at, expires_at } }
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/user_bearer_guard.php';
require_once dirname(__DIR__, 3) . '/include/subscriptions_repo.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $pdo = tp_pdo();
    $userId = tp_user_require_active_json($pdo);
    $payload = tp_subscription_status_payload($pdo, $userId);
    tp_json_response(200, $payload);
} catch (Throwable $e) {
    error_log('subscription/status: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
