<?php
declare(strict_types=1);

/**
 * GET — список заявок для администратора.
 * Заголовок: Authorization: Bearer <admin_api_token>
 * Query:
 * - status=new|in_work|need_info|done|closed|cancelled
 * - limit=1..200
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

function tp_admin_normalize_limit($value): int
{
    $limit = (int) ($value ?? 100);
    if ($limit < 1) {
        return 1;
    }
    if ($limit > 200) {
        return 200;
    }
    return $limit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

if (!tp_admin_authorized()) {
    tp_json_response(401, ['error' => 'Недействительный admin token']);
    exit;
}

try {
    $allowedStatuses = ['new', 'in_work', 'need_info', 'done', 'closed', 'cancelled'];
    $status = trim((string) ($_GET['status'] ?? ''));
    if ($status !== '' && !in_array($status, $allowedStatuses, true)) {
        tp_json_response(400, ['message' => 'Некорректный статус заявки']);
        exit;
    }

    $limit = tp_admin_normalize_limit($_GET['limit'] ?? null);
    $pdo = tp_pdo();

    $where = '';
    $params = [];
    if ($status !== '') {
        $where = 'WHERE r.status = ?';
        $params[] = $status;
    }

    $sql = 'SELECT r.id, r.estimate_id, r.user_id, r.status, r.contact_name,
                   r.contact_phone, r.contact_email, r.comment, r.raw_json,
                   r.created_at, r.updated_at,
                   e.title AS estimate_title, e.total_amount, e.status AS estimate_status,
                   e.raw_json AS estimate_raw_json,
                   u.phone AS user_phone, u.last_name, u.first_name, u.middle_name, u.email
            FROM estimate_requests r
            INNER JOIN estimates e ON e.id = r.estimate_id
            INNER JOIN user_profiles u ON u.id = r.user_id
            ' . $where . '
            ORDER BY r.created_at DESC
            LIMIT ' . $limit;
    $st = $pdo->prepare($sql);
    $st->execute($params);
    $requests = $st->fetchAll();

    $itemSt = $pdo->prepare(
        'SELECT id, estimate_id, item_key, category, sku, name, description,
                material, color, unit, quantity, unit_price, total_price, raw_json
         FROM estimate_items
         WHERE estimate_id = ?
         ORDER BY id'
    );

    foreach ($requests as &$request) {
        $itemSt->execute([(int) $request['estimate_id']]);
        $request['items'] = $itemSt->fetchAll();
    }
    unset($request);

    tp_json_response(200, [
        'items' => $requests,
        'count' => count($requests),
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
