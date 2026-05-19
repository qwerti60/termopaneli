<?php
declare(strict_types=1);

/**
 * POST JSON — смена статуса заявки администратором.
 * Заголовок: Authorization: Bearer <admin_api_token из config ИЛИ token из POST .../admin/auth/login.php>
 * Тело:
 * {
 *   "request_id": 123,
 *   "status": "in_work"
 * }
 */
require_once dirname(__DIR__, 4) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 4) . '/include/admin_auth.php';
require_once dirname(__DIR__, 4) . '/include/admin_requests_service.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$pdo = tp_pdo();
if (!tp_admin_authorized($pdo)) {
    tp_json_response(401, ['error' => 'Недействительный admin token']);
    exit;
}

try {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw ?: '[]', true);
    if (!is_array($data)) {
        tp_json_response(400, ['message' => 'Некорректный JSON']);
        exit;
    }

    $requestId = (int) ($data['request_id'] ?? 0);
    $status = trim((string) ($data['status'] ?? ''));

    $upd = tp_admin_update_request_status($pdo, $requestId, $status);
    if ($upd !== true) {
        $code = $upd === 'Заявка не найдена' ? 404 : 400;
        tp_json_response($code, ['message' => $upd]);
        exit;
    }

    tp_json_response(200, [
        'ok' => true,
        'request_id' => $requestId,
        'status' => $status,
    ]);
} catch (Throwable $e) {
    error_log('Admin request status error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка изменения статуса заявки',
        'message' => $debug ? $e->getMessage() : 'Попробуйте повторить позже',
    ]);
}
