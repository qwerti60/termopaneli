<?php
declare(strict_types=1);

/**
 * POST JSON — смена статуса заявки администратором.
 * Заголовок: Authorization: Bearer <admin_api_token>
 * Тело:
 * {
 *   "request_id": 123,
 *   "status": "in_work"
 * }
 */
require_once dirname(__DIR__, 4) . '/include/api_bootstrap.php';

function tp_admin_request_token(): ?string
{
    return tp_bearer_token();
}

function tp_admin_authorized(): bool
{
    $cfg = tp_config();
    $expected = trim((string) ($cfg['admin_api_token'] ?? ''));
    $actual = tp_admin_request_token();
    return $expected !== '' && $actual !== null && hash_equals($expected, $actual);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

if (!tp_admin_authorized()) {
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
    if ($requestId <= 0) {
        tp_json_response(400, ['message' => 'Некорректная заявка']);
        exit;
    }

    $allowedStatuses = ['new', 'in_work', 'need_info', 'done', 'closed', 'cancelled'];
    $status = trim((string) ($data['status'] ?? ''));
    if (!in_array($status, $allowedStatuses, true)) {
        tp_json_response(400, ['message' => 'Некорректный статус заявки']);
        exit;
    }

    $pdo = tp_pdo();
    $checkSt = $pdo->prepare(
        'SELECT id
         FROM estimate_requests
         WHERE id = ?
         LIMIT 1'
    );
    $checkSt->execute([$requestId]);
    if ($checkSt->fetch() === false) {
        tp_json_response(404, ['message' => 'Заявка не найдена']);
        exit;
    }

    $st = $pdo->prepare(
        'UPDATE estimate_requests
         SET status = ?, updated_at = NOW()
         WHERE id = ?'
    );
    $st->execute([$status, $requestId]);

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
