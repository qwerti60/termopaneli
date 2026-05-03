<?php
declare(strict_types=1);

/**
 * GET — список панелей из thermo_panel_catalog.
 * Ответ:
 * {
 *   "items": [ { ...сырой ряд таблицы... } ],
 *   "count": 10
 * }
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

try {
    $pdo = tp_pdo();
    $sql = 'SELECT * FROM thermo_panel_catalog LIMIT :limit OFFSET :offset';
    $st = $pdo->prepare($sql);
    $st->bindValue(':limit', $limit, PDO::PARAM_INT);
    $st->bindValue(':offset', $offset, PDO::PARAM_INT);
    $st->execute();
    $rows = $st->fetchAll();
    tp_json_response(200, [
        'items' => $rows,
        'count' => count($rows),
    ]);
} catch (Throwable $e) {
    tp_json_response(500, ['error' => 'Ошибка чтения каталога']);
}
