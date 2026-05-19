<?php
declare(strict_types=1);

/**
 * Общая логика списка заявок и смены статуса (admin API и веб-админка).
 */

require_once __DIR__ . '/admin_estimate_calc.php';

function tp_admin_allowed_request_statuses(): array
{
    return ['new', 'in_work', 'need_info', 'done', 'closed', 'cancelled'];
}

function tp_admin_normalize_request_limit($value): int
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

/**
 * @return array{ok: true, items: array<int, array<string, mixed>>}|array{ok: false, message: string}
 */
function tp_admin_fetch_requests_list(PDO $pdo, string $status, int $limit): array
{
    $allowedStatuses = tp_admin_allowed_request_statuses();
    $status = trim($status);
    if ($status !== '' && !in_array($status, $allowedStatuses, true)) {
        return ['ok' => false, 'message' => 'Некорректный статус заявки'];
    }

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
            LIMIT ' . (int) $limit;
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

    return ['ok' => true, 'items' => $requests];
}

/**
 * Одна заявка с позициями сметы (для веб-просмотра).
 *
 * @return array{ok: true, request: array<string, mixed>}|array{ok: false, message: string}
 */
function tp_admin_fetch_request_detail(PDO $pdo, int $requestId): array
{
    if ($requestId <= 0) {
        return ['ok' => false, 'message' => 'Некорректная заявка'];
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
            WHERE r.id = ?
            LIMIT 1';
    $st = $pdo->prepare($sql);
    $st->execute([$requestId]);
    $row = $st->fetch();
    if ($row === false) {
        return ['ok' => false, 'message' => 'Заявка не найдена'];
    }

    $itemSt = $pdo->prepare(
        'SELECT id, estimate_id, item_key, category, sku, name, description,
                material, color, unit, quantity, unit_price, total_price, raw_json
         FROM estimate_items
         WHERE estimate_id = ?
         ORDER BY id'
    );
    $itemSt->execute([(int) $row['estimate_id']]);
    $row['items'] = $itemSt->fetchAll();

    return ['ok' => true, 'request' => $row];
}

/**
 * @return true|string true при успехе, иначе текст ошибки
 */
function tp_admin_update_request_status(PDO $pdo, int $requestId, string $status)
{
    $allowedStatuses = tp_admin_allowed_request_statuses();
    if (!in_array($status, $allowedStatuses, true)) {
        return 'Некорректный статус заявки';
    }
    if ($requestId <= 0) {
        return 'Некорректная заявка';
    }

    $checkSt = $pdo->prepare(
        'SELECT id FROM estimate_requests WHERE id = ? LIMIT 1'
    );
    $checkSt->execute([$requestId]);
    if ($checkSt->fetch() === false) {
        return 'Заявка не найдена';
    }

    $st = $pdo->prepare(
        'UPDATE estimate_requests
         SET status = ?, updated_at = NOW()
         WHERE id = ?'
    );
    $st->execute([$status, $requestId]);

    return true;
}
