<?php
declare(strict_types=1);

/**
 * Админ-операции над catalog_materials (веб-админка).
 */

/** @return array<string, string> slug => подпись */
function tp_admin_catalog_material_categories(): array
{
    return [
        'all' => 'Все материалы',
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
}

/**
 * @return array{rows: list<array<string, mixed>>, total: int}|array{error: string}
 */
function tp_admin_catalog_materials_list(PDO $pdo, string $category, int $offset, int $limit): array
{
    $cats = tp_admin_catalog_material_categories();
    $category = trim($category);
    if ($category === '') {
        $category = 'all';
    }
    if (!array_key_exists($category, $cats)) {
        return ['error' => 'Некорректная категория'];
    }
    if ($limit < 1) {
        $limit = 50;
    }
    if ($limit > 500) {
        $limit = 500;
    }
    if ($offset < 0) {
        $offset = 0;
    }

    $where = '1=1';
    $params = [];
    if ($category !== 'all') {
        $where .= ' AND category = ?';
        $params[] = $category;
    }

    $cntSt = $pdo->prepare('SELECT COUNT(*) AS c FROM catalog_materials WHERE ' . $where);
    $cntSt->execute($params);
    $total = (int) ($cntSt->fetch()['c'] ?? 0);

    $sql = 'SELECT id, sku, category, name, description, material, color, texture,
                   thickness_mm, width_mm, length_mm, package_qty, unit, price, image_path,
                   is_active, sort_order, updated_at
            FROM catalog_materials WHERE ' . $where . '
            ORDER BY category, sort_order, id
            LIMIT ' . (int) $limit . ' OFFSET ' . (int) $offset;
    $st = $pdo->prepare($sql);
    $st->execute($params);
    $rows = $st->fetchAll();

    return ['rows' => $rows, 'total' => $total];
}

/**
 * @return array<string, mixed>|null
 */
function tp_admin_catalog_material_get(PDO $pdo, int $id): ?array
{
    if ($id <= 0) {
        return null;
    }
    $st = $pdo->prepare(
        'SELECT * FROM catalog_materials WHERE id = ? LIMIT 1'
    );
    $st->execute([$id]);
    $row = $st->fetch();
    return $row === false ? null : $row;
}

function tp_admin_catalog_decimal_or_null(string $raw): ?string
{
    $t = trim(str_replace(',', '.', $raw));
    if ($t === '') {
        return null;
    }
    if (!is_numeric($t)) {
        return null;
    }
    return (string) (float) $t;
}

/**
 * @param array<string, string> $p поля из $_POST (уже как строки)
 * @return true|string
 */
function tp_admin_catalog_material_update(PDO $pdo, int $id, array $p)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $cur = tp_admin_catalog_material_get($pdo, $id);
    if ($cur === null) {
        return 'Позиция не найдена';
    }

    $name = trim((string) ($p['name'] ?? ''));
    if ($name === '') {
        return 'Название не может быть пустым';
    }

    $priceRaw = str_replace(',', '.', trim((string) ($p['price'] ?? '0')));
    if (!is_numeric($priceRaw) || (float) $priceRaw < 0) {
        return 'Некорректная цена';
    }
    $price = round((float) $priceRaw, 2);

    $sortOrder = (int) ($p['sort_order'] ?? 100);
    $isActive = isset($p['is_active']) && (string) $p['is_active'] === '1' ? 1 : 0;

    $description = trim((string) ($p['description'] ?? ''));
    $material = trim((string) ($p['material'] ?? ''));
    $color = trim((string) ($p['color'] ?? ''));
    $texture = trim((string) ($p['texture'] ?? ''));
    $unit = trim((string) ($p['unit'] ?? 'шт'));
    if ($unit === '') {
        $unit = 'шт';
    }
    if (mb_strlen($unit, 'UTF-8') > 50) {
        return 'Единица измерения слишком длинная';
    }

    $imagePath = trim((string) ($p['image_path'] ?? ''));
    if (mb_strlen($imagePath, 'UTF-8') > 255) {
        return 'Путь к картинке слишком длинный';
    }

    $pkgRaw = trim((string) ($p['package_qty'] ?? ''));
    $packageQty = null;
    if ($pkgRaw !== '' && is_numeric($pkgRaw)) {
        $pq = (int) $pkgRaw;
        if ($pq >= 2) {
            $packageQty = $pq;
        }
    }

    $th = tp_admin_catalog_decimal_or_null((string) ($p['thickness_mm'] ?? ''));
    $wm = tp_admin_catalog_decimal_or_null((string) ($p['width_mm'] ?? ''));
    $lm = tp_admin_catalog_decimal_or_null((string) ($p['length_mm'] ?? ''));

    $sql = 'UPDATE catalog_materials SET
        name = ?, description = ?, material = ?, color = ?, texture = ?,
        thickness_mm = ?, width_mm = ?, length_mm = ?, package_qty = ?,
        unit = ?, price = ?, image_path = ?, is_active = ?, sort_order = ?,
        updated_at = NOW()
        WHERE id = ?';

    $st = $pdo->prepare($sql);
    $st->execute([
        $name,
        $description === '' ? null : $description,
        $material === '' ? null : $material,
        $color === '' ? null : $color,
        $texture === '' ? null : $texture,
        $th,
        $wm,
        $lm,
        $packageQty,
        $unit,
        $price,
        $imagePath === '' ? null : $imagePath,
        $isActive,
        $sortOrder,
        $id,
    ]);

    return true;
}

/** Категории для INSERT (без «все»). */
function tp_admin_catalog_material_category_slugs(): array
{
    $c = tp_admin_catalog_material_categories();
    unset($c['all']);

    return array_keys($c);
}

/**
 * @param array<string, string> $p
 * @return array{ok: true, id: int}|array{ok: false, error: string}
 */
function tp_admin_catalog_material_insert(PDO $pdo, array $p)
{
    $sku = trim((string) ($p['sku'] ?? ''));
    if ($sku === '' || mb_strlen($sku, 'UTF-8') > 64) {
        return ['ok' => false, 'error' => 'SKU обязателен, до 64 символов'];
    }
    $category = trim((string) ($p['category'] ?? ''));
    if (!in_array($category, tp_admin_catalog_material_category_slugs(), true)) {
        return ['ok' => false, 'error' => 'Выберите категорию'];
    }

    $st = $pdo->prepare('SELECT 1 FROM catalog_materials WHERE sku = ? LIMIT 1');
    $st->execute([$sku]);
    if ($st->fetch()) {
        return ['ok' => false, 'error' => 'Такой SKU уже есть в базе'];
    }

    $name = trim((string) ($p['name'] ?? ''));
    if ($name === '') {
        return ['ok' => false, 'error' => 'Название не может быть пустым'];
    }

    $priceRaw = str_replace(',', '.', trim((string) ($p['price'] ?? '0')));
    if (!is_numeric($priceRaw) || (float) $priceRaw < 0) {
        return ['ok' => false, 'error' => 'Некорректная цена'];
    }
    $price = round((float) $priceRaw, 2);

    $sortOrder = (int) ($p['sort_order'] ?? 100);
    $isActive = isset($p['is_active']) && (string) $p['is_active'] === '1' ? 1 : 0;

    $description = trim((string) ($p['description'] ?? ''));
    $material = trim((string) ($p['material'] ?? ''));
    $color = trim((string) ($p['color'] ?? ''));
    $texture = trim((string) ($p['texture'] ?? ''));
    $unit = trim((string) ($p['unit'] ?? 'шт'));
    if ($unit === '') {
        $unit = 'шт';
    }
    if (mb_strlen($unit, 'UTF-8') > 50) {
        return ['ok' => false, 'error' => 'Единица измерения слишком длинная'];
    }

    $imagePath = trim((string) ($p['image_path'] ?? ''));
    if (mb_strlen($imagePath, 'UTF-8') > 255) {
        return ['ok' => false, 'error' => 'Путь к картинке слишком длинный'];
    }

    $pkgRaw = trim((string) ($p['package_qty'] ?? ''));
    $packageQty = null;
    if ($pkgRaw !== '' && is_numeric($pkgRaw)) {
        $pq = (int) $pkgRaw;
        if ($pq >= 2) {
            $packageQty = $pq;
        }
    }

    $th = tp_admin_catalog_decimal_or_null((string) ($p['thickness_mm'] ?? ''));
    $wm = tp_admin_catalog_decimal_or_null((string) ($p['width_mm'] ?? ''));
    $lm = tp_admin_catalog_decimal_or_null((string) ($p['length_mm'] ?? ''));

    $sql = 'INSERT INTO catalog_materials (
        sku, category, name, description, material, color, texture,
        thickness_mm, width_mm, length_mm, package_qty, unit, price, image_path, is_active, sort_order
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

    $st = $pdo->prepare($sql);
    $st->execute([
        $sku,
        $category,
        $name,
        $description === '' ? null : $description,
        $material === '' ? null : $material,
        $color === '' ? null : $color,
        $texture === '' ? null : $texture,
        $th,
        $wm,
        $lm,
        $packageQty,
        $unit,
        $price,
        $imagePath === '' ? null : $imagePath,
        $isActive,
        $sortOrder,
    ]);

    return ['ok' => true, 'id' => (int) $pdo->lastInsertId()];
}

/**
 * Удалить позицию; файл в catalog_uploads/ при необходимости снимается с диска.
 * @return true|string
 */
function tp_admin_catalog_material_delete(PDO $pdo, int $id)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $row = tp_admin_catalog_material_get($pdo, $id);
    if ($row === null) {
        return 'Позиция не найдена';
    }
    if (!defined('TP_PUBLIC_ROOT')) {
        return 'Внутренняя ошибка конфигурации';
    }
    $img = trim((string) ($row['image_path'] ?? ''));
    if ($img !== '' && defined('TP_PUBLIC_ROOT')) {
        $rel = str_replace('\\', '/', $img);
        if (!str_contains($rel, '..') && str_starts_with($rel, 'catalog_uploads/')) {
            $full = TP_PUBLIC_ROOT . '/' . $rel;
            if (is_file($full)) {
                @unlink($full);
            }
        }
    }
    $st = $pdo->prepare('DELETE FROM catalog_materials WHERE id = ? LIMIT 1');
    $st->execute([$id]);

    return true;
}
