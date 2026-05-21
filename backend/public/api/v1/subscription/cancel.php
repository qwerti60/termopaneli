<?php
declare(strict_types=1);

/**
 * POST — отмена активной подписки (снимает PRO после синхронизации).
 * Authorization: Bearer <token>
 *
 * 200: { "ok": true }
 * 400: { "ok": false, "message": "..." } — нет активной подписки
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
    $res = tp_subscription_cancel_active($pdo, $userId);
    if ($res !== true) {
        tp_json_response(400, ['ok' => false, 'message' => (string) $res]);
        exit;
    }
    tp_json_response(200, ['ok' => true]);
} catch (Throwable $e) {
    error_log('subscription/cancel: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
