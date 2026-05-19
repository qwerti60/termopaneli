<?php
declare(strict_types=1);

/**
 * GET — тестовый прайс работ для сметы.
 * Параметры:
 * - limit=100
 * - offset=0
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 100;
$offset = isset($_GET['offset']) ? (int) $_GET['offset'] : 0;
if ($limit <= 0) {
    $limit = 100;
}
if ($limit > 500) {
    $limit = 500;
}
if ($offset < 0) {
    $offset = 0;
}

function tp_normalize_work_price_row(array $row): array
{
    return [
        'source' => 'work_prices',
        'category' => 'work',
        'category_label' => 'Работы',
        'sku' => (string) ($row['sku'] ?? ''),
        'name' => (string) ($row['name'] ?? ''),
        'title' => (string) ($row['name'] ?? ''),
        'description' => (string) ($row['description'] ?? ''),
        'image_path' => (string) ($row['image_path'] ?? ''),
        'unit' => (string) ($row['unit'] ?? 'шт'),
        'price' => $row['price'] ?? 0,
        'calc_rule' => (string) ($row['calc_rule'] ?? 'manual'),
        'is_default' => (bool) ($row['is_default'] ?? false),
        'is_active' => (bool) ($row['is_active'] ?? false),
        'sort_order' => (int) ($row['sort_order'] ?? 100),
        'raw' => $row,
    ];
}

try {
    $pdo = tp_pdo();
    $st = $pdo->prepare(
        'SELECT *
         FROM work_prices
         WHERE is_active = 1
         ORDER BY sort_order, name
         LIMIT :limit OFFSET :offset'
    );
    $st->bindValue(':limit', $limit, PDO::PARAM_INT);
    $st->bindValue(':offset', $offset, PDO::PARAM_INT);
    $st->execute();

    $items = [];
    foreach ($st->fetchAll() as $row) {
        $items[] = tp_normalize_work_price_row($row);
    }

    tp_json_response(200, [
        'items' => $items,
        'count' => count($items),
    ]);
} catch (Throwable $e) {
    error_log('Work prices list error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка чтения прайса работ',
        'message' => $debug ? $e->getMessage() : 'Проверьте, что выполнен sql/schema_work_prices.sql',
    ]);
}
