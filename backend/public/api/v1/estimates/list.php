<?php
declare(strict_types=1);

/**
 * GET — список сохраненных смет текущего пользователя.
 * Заголовок: Authorization: Bearer <token>
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/estimates_user_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $userId = tp_estimates_auth_user_id();
    if ($userId === null) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    $pdo = tp_pdo();
    $st = $pdo->prepare(
        'SELECT id, title, status, total_amount, raw_json, created_at, updated_at
         FROM estimates
         WHERE user_id = ?
         ORDER BY created_at DESC
         LIMIT 100'
    );
    $st->execute([$userId]);
    $estimates = $st->fetchAll();

    $itemSt = $pdo->prepare(
        'SELECT id, estimate_id, item_key, category, sku, name, description,
                material, color, unit, quantity, unit_price, total_price, raw_json
         FROM estimate_items
         WHERE estimate_id = ?
         ORDER BY id'
    );
    $requestSt = $pdo->prepare(
        'SELECT id, status, comment, created_at
         FROM estimate_requests
         WHERE estimate_id = ? AND user_id = ?
         ORDER BY id DESC
         LIMIT 1'
    );
    /** Без строки estimate_requests админка не видит заявку — снимаем ложный submitted. */
    $fixOrphanSubmittedSt = $pdo->prepare(
        'UPDATE estimates SET status = ?, updated_at = NOW()
         WHERE id = ? AND user_id = ? AND status = ?'
    );

    foreach ($estimates as &$estimate) {
        $itemSt->execute([(int) $estimate['id']]);
        $estimate['items'] = $itemSt->fetchAll();
        $requestSt->execute([(int) $estimate['id'], $userId]);
        $request = $requestSt->fetch();
        $requestSt->closeCursor();
        $estimate['request'] = $request !== false ? $request : null;
        if (($estimate['status'] ?? '') === 'submitted' && $estimate['request'] === null) {
            $fixOrphanSubmittedSt->execute(['draft', (int) $estimate['id'], $userId, 'submitted']);
            $estimate['status'] = 'draft';
        }
    }
    unset($estimate);

    tp_json_response(200, [
        'items' => $estimates,
        'count' => count($estimates),
    ]);
} catch (Throwable $e) {
    error_log('Estimate list error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка чтения смет',
        'message' => $debug ? $e->getMessage() : 'Проверьте, что выполнен sql/schema_estimates.sql',
    ]);
}
