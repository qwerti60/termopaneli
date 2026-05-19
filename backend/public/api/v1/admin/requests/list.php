<?php
declare(strict_types=1);

/**
 * GET — список заявок для администратора.
 * Заголовок: Authorization: Bearer <admin_api_token из config ИЛИ token из POST .../admin/auth/login.php>
 * Query:
 * - status=new|in_work|need_info|done|closed|cancelled
 * - limit=1..200
 */
require_once dirname(__DIR__, 4) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 4) . '/include/admin_auth.php';
require_once dirname(__DIR__, 4) . '/include/admin_requests_service.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$pdo = tp_pdo();
if (!tp_admin_authorized($pdo)) {
    tp_json_response(401, ['error' => 'Недействительный admin token']);
    exit;
}

try {
    $status = trim((string) ($_GET['status'] ?? ''));
    $limit = tp_admin_normalize_request_limit($_GET['limit'] ?? null);

    $result = tp_admin_fetch_requests_list($pdo, $status, $limit);
    if ($result['ok'] !== true) {
        tp_json_response(400, ['message' => $result['message']]);
        exit;
    }

    $items = $result['items'];
    tp_json_response(200, [
        'items' => $items,
        'count' => count($items),
    ]);
} catch (Throwable $e) {
    error_log('Admin requests list error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка чтения заявок',
        'message' => $debug ? $e->getMessage() : 'Попробуйте повторить позже',
    ]);
}
