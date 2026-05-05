<?php
declare(strict_types=1);

/**
 * GET — список сохраненных смет текущего пользователя.
 * Заголовок: Authorization: Bearer <token>
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $pdo = tp_pdo();
    $userId = tp_auth_user_id();
    if ($userId === null) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    $st = $pdo->prepare(
        'SELECT id, title, status, total_amount, created_at, updated_at
         FROM estimates
         WHERE user_id = ?
         ORDER BY created_at DESC
         LIMIT 100'
    );
    $st->execute([$userId]);
    $estimates = $st->fetchAll();

    $itemSt = $pdo->prepare(
        'SELECT id, estimate_id, item_key, category, sku, name, description,
                material, color, unit, quantity, unit_price, total_price
         FROM estimate_items
         WHERE estimate_id = ?
         ORDER BY id'
    );

    foreach ($estimates as &$estimate) {
        $itemSt->execute([(int) $estimate['id']]);
        $estimate['items'] = $itemSt->fetchAll();
    }
    unset($estimate);

    tp_json_response(200, [
        'items' => $estimates,
        'count' => count($estimates),
    ]);
} catch (Throwable $e) {
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка чтения смет',
        'message' => $debug ? $e->getMessage() : 'Проверьте, что выполнен sql/schema_estimates.sql',
    ]);
}
