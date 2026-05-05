<?php
declare(strict_types=1);

/**
 * POST JSON — сохранение сметы текущего пользователя.
 * Заголовок: Authorization: Bearer <token>
 * Тело:
 * {
 *   "title": "Смета",
 *   "items": [
 *     {
 *       "key": "panel:VS-2a",
 *       "category": "panel",
 *       "sku": "VS-2a",
 *       "name": "Термопанель",
 *       "description": "...",
 *       "material": "Термопанель",
 *       "color": "Серый",
 *       "unit": "шт",
 *       "quantity": 2,
 *       "unit_price": 676,
 *       "raw": {}
 *     }
 *   ]
 * }
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw ?: '[]', true);
    if (!is_array($data)) {
        tp_json_response(400, ['message' => 'Некорректный JSON']);
        exit;
    }

    $title = trim((string) ($data['title'] ?? 'Смета'));
    if ($title === '') {
        $title = 'Смета';
    }
    $items = $data['items'] ?? null;
    if (!is_array($items) || count($items) === 0) {
        tp_json_response(400, ['message' => 'Смета пустая']);
        exit;
    }

    $pdo = tp_pdo();
    $userId = tp_auth_user_id();
    if ($userId === null) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    $pdo->beginTransaction();

    $total = 0.0;
    $normalizedItems = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }
        $quantity = max(1, (int) ($item['quantity'] ?? 1));
        $unitPrice = max(0.0, (float) ($item['unit_price'] ?? 0));
        $lineTotal = $quantity * $unitPrice;
        $total += $lineTotal;
        $normalizedItems[] = [
            'item_key' => trim((string) ($item['key'] ?? '')),
            'category' => trim((string) ($item['category'] ?? '')),
            'sku' => trim((string) ($item['sku'] ?? '')),
            'name' => trim((string) ($item['name'] ?? 'Позиция сметы')),
            'description' => trim((string) ($item['description'] ?? '')),
            'material' => trim((string) ($item['material'] ?? '')),
            'color' => trim((string) ($item['color'] ?? '')),
            'unit' => trim((string) ($item['unit'] ?? 'шт')),
            'quantity' => $quantity,
            'unit_price' => $unitPrice,
            'total_price' => $lineTotal,
            'raw_json' => json_encode($item['raw'] ?? $item, JSON_UNESCAPED_UNICODE),
        ];
    }

    if (count($normalizedItems) === 0) {
        $pdo->rollBack();
        tp_json_response(400, ['message' => 'Смета пустая']);
        exit;
    }

    $st = $pdo->prepare(
        'INSERT INTO estimates (user_id, title, status, total_amount)
         VALUES (?, ?, ?, ?)'
    );
    $st->execute([$userId, $title, 'draft', $total]);
    $estimateId = (int) $pdo->lastInsertId();

    $itemSt = $pdo->prepare(
        'INSERT INTO estimate_items
         (estimate_id, item_key, category, sku, name, description, material, color, unit, quantity, unit_price, total_price, raw_json)
         VALUES
         (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    );
    foreach ($normalizedItems as $item) {
        $itemSt->execute([
            $estimateId,
            $item['item_key'],
            $item['category'],
            $item['sku'] !== '' ? $item['sku'] : null,
            $item['name'],
            $item['description'] !== '' ? $item['description'] : null,
            $item['material'] !== '' ? $item['material'] : null,
            $item['color'] !== '' ? $item['color'] : null,
            $item['unit'] !== '' ? $item['unit'] : 'шт',
            $item['quantity'],
            $item['unit_price'],
            $item['total_price'],
            $item['raw_json'],
        ]);
    }

    $pdo->commit();
    tp_json_response(200, [
        'ok' => true,
        'estimate_id' => $estimateId,
        'total_amount' => $total,
    ]);
} catch (Throwable $e) {
    try {
        if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
            $pdo->rollBack();
        }
    } catch (Throwable) {
    }
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка сохранения сметы',
        'message' => $debug ? $e->getMessage() : 'Проверьте, что выполнен sql/schema_estimates.sql',
    ]);
}
