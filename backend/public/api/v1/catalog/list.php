<?php
declare(strict_types=1);

/**
 * GET — список панелей и дополнительных материалов.
 * Параметры:
 * - category=all|panel|slope|corner|grout|ebb|soffit|soffit_lining|front_overhang|plinth|fastener|consumable
 * - limit=100
 * - offset=0
 * - material=… — необязательно; для строк из catalog_materials: точное совпадение поля material (после trim)
 * - color=… — необязательно; для catalog_materials: точное совпадение поля color (после trim)
 * - thickness=… — необязательно; для catalog_materials: числовое совпадение с thickness_mm,
 *   либо (если thickness_mm NULL) с width_mm для категорий slope, ebb, corner
 *   Фильтры material/color/thickness к запросу панелей (thermo_panel_catalog) не применяются.
 *
 * Ответ:
 * {
 *   "items": [ { ...нормализованная позиция каталога... } ],
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
$category = isset($_GET['category']) ? trim((string) $_GET['category']) : 'all';
if ($limit <= 0) {
    $limit = 100;
}
if ($limit > 500) {
    $limit = 500;
}
if ($offset < 0) {
    $offset = 0;
}

$filterMaterial = isset($_GET['material']) ? trim((string) $_GET['material']) : '';
$filterColor = isset($_GET['color']) ? trim((string) $_GET['color']) : '';
$filterThicknessRaw = isset($_GET['thickness']) ? trim((string) $_GET['thickness']) : '';
$matLen = function_exists('mb_strlen')
    ? mb_strlen($filterMaterial, 'UTF-8')
    : strlen($filterMaterial);
$colLen = function_exists('mb_strlen')
    ? mb_strlen($filterColor, 'UTF-8')
    : strlen($filterColor);
$thLen = function_exists('mb_strlen')
    ? mb_strlen($filterThicknessRaw, 'UTF-8')
    : strlen($filterThicknessRaw);
if ($matLen > 100) {
    $filterMaterial = '';
}
if ($colLen > 100) {
    $filterColor = '';
}
if ($thLen > 32) {
    $filterThicknessRaw = '';
}
$filterThicknessMm = null;
if ($filterThicknessRaw !== '' && is_numeric($filterThicknessRaw)) {
    $ft = (float) $filterThicknessRaw;
    if ($ft > 0) {
        $filterThicknessMm = $ft;
    }
}

function tp_catalog_pick(array $row, array $keys, string $fallback = ''): string
{
    foreach ($keys as $key) {
        if (isset($row[$key]) && trim((string) $row[$key]) !== '') {
            return trim((string) $row[$key]);
        }
    }
    return $fallback;
}

function tp_normalize_panel_row(array $row): array
{
    $title = tp_catalog_pick(
        $row,
        ['title', 'name', 'panel_name', 'model', 'model_code', 'code', 'article', 'id'],
        'Термопанель'
    );
    $description = tp_catalog_pick(
        $row,
        ['color_description', 'description', 'collection_style', 'collection', 'color']
    );
    $price = tp_catalog_pick($row, ['price_m2', 'price', 'price_per_m2_rub', 'panel_price']);
    $image = tp_catalog_pick($row, ['image_path', 'image_url', 'image', 'photo', 'img', 'preview']);

    return [
        'source' => 'thermo_panel_catalog',
        'category' => 'panel',
        'category_label' => 'Термопанели',
        'sku' => tp_catalog_pick($row, ['sku', 'article', 'code', 'model_code', 'id']),
        'name' => $title,
        'title' => $title,
        'description' => $description,
        'material' => 'Термопанель',
        'color' => tp_catalog_pick($row, ['color', 'color_description']),
        'texture' => tp_catalog_pick($row, ['texture', 'collection_style', 'collection']),
        'unit' => 'м²',
        'price' => $price,
        'image_path' => $image,
        'is_active' => true,
        'raw' => $row,
    ];
}

function tp_normalize_material_row(array $row): array
{
    $categoryLabels = [
        'slope' => 'Откосы',
        'corner' => 'Уголки',
        'grout' => 'Затирка',
        'ebb' => 'Отливы',
        'soffit' => 'Софиты',
        'soffit_lining' => 'Подшивка софитов',
        'front_overhang' => 'Фронтальные свесы',
        'plinth' => 'Цоколь',
        'fastener' => 'Крепеж',
        'consumable' => 'Расходники',
    ];
    $category = (string) ($row['category'] ?? '');

    return [
        'source' => 'catalog_materials',
        'category' => $category,
        'category_label' => $categoryLabels[$category] ?? $category,
        'sku' => (string) ($row['sku'] ?? ''),
        'name' => (string) ($row['name'] ?? ''),
        'title' => (string) ($row['name'] ?? ''),
        'description' => (string) ($row['description'] ?? ''),
        'material' => (string) ($row['material'] ?? ''),
        'color' => (string) ($row['color'] ?? ''),
        'texture' => (string) ($row['texture'] ?? ''),
        'thickness_mm' => $row['thickness_mm'] ?? null,
        'width_mm' => $row['width_mm'] ?? null,
        'length_mm' => $row['length_mm'] ?? null,
        'unit' => (string) ($row['unit'] ?? 'шт'),
        'price' => $row['price'] ?? 0,
        'image_path' => (string) ($row['image_path'] ?? ''),
        'is_active' => (bool) ($row['is_active'] ?? false),
        'sort_order' => (int) ($row['sort_order'] ?? 100),
        'raw' => $row,
    ];
}

try {
    $pdo = tp_pdo();
    $items = [];

    if ($category === 'all' || $category === '' || $category === 'panel') {
        $sql = 'SELECT * FROM thermo_panel_catalog LIMIT :limit OFFSET :offset';
        $st = $pdo->prepare($sql);
        $st->bindValue(':limit', $limit, PDO::PARAM_INT);
        $st->bindValue(':offset', $offset, PDO::PARAM_INT);
        $st->execute();
        foreach ($st->fetchAll() as $row) {
            $items[] = tp_normalize_panel_row($row);
        }
    }

    if ($category !== 'panel') {
        try {
            $sql = 'SELECT * FROM catalog_materials WHERE is_active = 1';
            $params = [];
            if ($category !== 'all' && $category !== '') {
                $sql .= ' AND category = :category';
                $params['category'] = $category;
            }
            if ($filterMaterial !== '') {
                $sql .= ' AND TRIM(material) = :filter_material';
                $params['filter_material'] = $filterMaterial;
            }
            if ($filterColor !== '') {
                $sql .= ' AND TRIM(color) = :filter_color';
                $params['filter_color'] = $filterColor;
            }
            if ($filterThicknessMm !== null) {
                $sql .= ' AND (
                    (thickness_mm IS NOT NULL AND thickness_mm = :filter_thickness_mm)
                    OR (
                        thickness_mm IS NULL
                        AND width_mm = :filter_thickness_mm_w
                        AND category IN (\'slope\', \'ebb\', \'corner\')
                    )
                )';
                $params['filter_thickness_mm'] = $filterThicknessMm;
                $params['filter_thickness_mm_w'] = $filterThicknessMm;
            }
            $sql .= ' ORDER BY sort_order, name LIMIT :limit OFFSET :offset';
            $st = $pdo->prepare($sql);
            foreach ($params as $key => $value) {
                $st->bindValue(':' . $key, $value);
            }
            $st->bindValue(':limit', $limit, PDO::PARAM_INT);
            $st->bindValue(':offset', $offset, PDO::PARAM_INT);
            $st->execute();
            foreach ($st->fetchAll() as $row) {
                $items[] = tp_normalize_material_row($row);
            }
        } catch (Throwable) {
            // Если миграция catalog_materials еще не выполнена, старый каталог панелей
            // должен продолжать работать.
        }
    }

    tp_json_response(200, [
        'items' => $items,
        'count' => count($items),
    ]);
} catch (Throwable $e) {
    tp_json_response(500, ['error' => 'Ошибка чтения каталога']);
}
