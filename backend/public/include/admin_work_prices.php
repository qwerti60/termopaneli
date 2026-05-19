<?php
declare(strict_types=1);

/**
 * Админ-операции над work_prices (веб-админка).
 */

/** @return list<string> */
function tp_admin_work_price_calc_rules(): array
{
    return [
        'manual',
        'facade_area_m2',
        'fixed_once',
        'opening_perimeter_lm',
        'window_count',
        'corner_length_lm',
        'sealing_length_lm',
    ];
}

/**
 * @return array{rows: list<array<string, mixed>>, total: int}|array{error: string}
 */
function tp_admin_work_prices_list(PDO $pdo, int $offset, int $limit): array
{
    if ($limit < 1) {
        $limit = 50;
    }
    if ($limit > 500) {
        $limit = 500;
    }
    if ($offset < 0) {
        $offset = 0;
    }

    try {
        $cntSt = $pdo->query('SELECT COUNT(*) AS c FROM work_prices');
        $total = (int) ($cntSt !== false ? ($cntSt->fetch(PDO::FETCH_ASSOC)['c'] ?? 0) : 0);

        $sql = 'SELECT * FROM work_prices
                ORDER BY sort_order, id
                LIMIT ' . (int) $limit . ' OFFSET ' . (int) $offset;
        $st = $pdo->query($sql);
        if ($st === false) {
            return ['error' => 'Не удалось прочитать work_prices'];
        }
        $rows = $st->fetchAll(PDO::FETCH_ASSOC);

        return ['rows' => $rows, 'total' => $total];
    } catch (Throwable $e) {
        return ['error' => 'Таблица work_prices недоступна. Выполните backend/sql/schema_work_prices.sql'];
    }
}

/**
 * @return array<string, mixed>|null
 */
function tp_admin_work_price_get(PDO $pdo, int $id): ?array
{
    if ($id <= 0) {
        return null;
    }
    try {
        $st = $pdo->prepare('SELECT * FROM work_prices WHERE id = ? LIMIT 1');
        $st->execute([$id]);
        $row = $st->fetch(PDO::FETCH_ASSOC);

        return $row === false ? null : $row;
    } catch (Throwable $e) {
        return null;
    }
}

/**
 * @param array<string, string> $p
 * @return true|string
 */
function tp_admin_work_price_update(PDO $pdo, int $id, array $p)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $cur = tp_admin_work_price_get($pdo, $id);
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

    $unit = trim((string) ($p['unit'] ?? 'шт'));
    if ($unit === '') {
        $unit = 'шт';
    }
    if (mb_strlen($unit, 'UTF-8') > 50) {
        return 'Единица измерения слишком длинная';
    }

    $calcRule = trim((string) ($p['calc_rule'] ?? 'manual'));
    $allowed = tp_admin_work_price_calc_rules();
    if (!in_array($calcRule, $allowed, true)) {
        return 'Некорректное правило расчёта количества';
    }

    $description = trim((string) ($p['description'] ?? ''));
    $imagePath = trim((string) ($p['image_path'] ?? ''));
    if (mb_strlen($imagePath, 'UTF-8') > 255) {
        return 'Путь к картинке слишком длинный';
    }

    $sortOrder = (int) ($p['sort_order'] ?? 100);
    $isActive = isset($p['is_active']) && (string) $p['is_active'] === '1' ? 1 : 0;
    $isDefault = isset($p['is_default']) && (string) $p['is_default'] === '1' ? 1 : 0;

    $sql = 'UPDATE work_prices SET
        name = ?, description = ?, image_path = ?, unit = ?, price = ?, calc_rule = ?,
        is_default = ?, is_active = ?, sort_order = ?,
        updated_at = NOW()
        WHERE id = ?';

    $st = $pdo->prepare($sql);
    try {
        $st->execute([
            $name,
            $description === '' ? null : $description,
            $imagePath === '' ? null : $imagePath,
            $unit,
            $price,
            $calcRule,
            $isDefault,
            $isActive,
            $sortOrder,
            $id,
        ]);
    } catch (Throwable $e) {
        if (stripos($e->getMessage(), 'image_path') !== false) {
            return 'Выполните SQL: backend/sql/migrate_work_prices_image_path.sql';
        }

        return 'Ошибка сохранения';
    }

    return true;
}

/**
 * @param array<string, string> $p
 * @return array{ok: true, id: int}|array{ok: false, error: string}
 */
function tp_admin_work_price_insert(PDO $pdo, array $p)
{
    $sku = trim((string) ($p['sku'] ?? ''));
    if ($sku === '' || mb_strlen($sku, 'UTF-8') > 64) {
        return ['ok' => false, 'error' => 'SKU обязателен, до 64 символов'];
    }
    $st = $pdo->prepare('SELECT 1 FROM work_prices WHERE sku = ? LIMIT 1');
    $st->execute([$sku]);
    if ($st->fetch()) {
        return ['ok' => false, 'error' => 'Такой SKU уже есть'];
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

    $unit = trim((string) ($p['unit'] ?? 'шт'));
    if ($unit === '') {
        $unit = 'шт';
    }
    if (mb_strlen($unit, 'UTF-8') > 50) {
        return ['ok' => false, 'error' => 'Единица измерения слишком длинная'];
    }

    $calcRule = trim((string) ($p['calc_rule'] ?? 'manual'));
    if (!in_array($calcRule, tp_admin_work_price_calc_rules(), true)) {
        return ['ok' => false, 'error' => 'Некорректное правило расчёта'];
    }

    $description = trim((string) ($p['description'] ?? ''));
    $imagePath = trim((string) ($p['image_path'] ?? ''));
    if (mb_strlen($imagePath, 'UTF-8') > 255) {
        return ['ok' => false, 'error' => 'Путь к картинке слишком длинный'];
    }

    $sortOrder = (int) ($p['sort_order'] ?? 100);
    $isActive = isset($p['is_active']) && (string) $p['is_active'] === '1' ? 1 : 0;
    $isDefault = isset($p['is_default']) && (string) $p['is_default'] === '1' ? 1 : 0;

    $sql = 'INSERT INTO work_prices (sku, name, description, image_path, unit, price, calc_rule, is_default, is_active, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
    $st = $pdo->prepare($sql);
    try {
        $st->execute([
            $sku,
            $name,
            $description === '' ? null : $description,
            $imagePath === '' ? null : $imagePath,
            $unit,
            $price,
            $calcRule,
            $isDefault,
            $isActive,
            $sortOrder,
        ]);
    } catch (Throwable $e) {
        if (stripos($e->getMessage(), 'image_path') !== false) {
            return ['ok' => false, 'error' => 'Выполните SQL: backend/sql/migrate_work_prices_image_path.sql'];
        }
        if (stripos($e->getMessage(), 'Duplicate') !== false) {
            return ['ok' => false, 'error' => 'SKU уже занят'];
        }

        return ['ok' => false, 'error' => 'Ошибка вставки'];
    }

    return ['ok' => true, 'id' => (int) $pdo->lastInsertId()];
}

/**
 * @return true|string
 */
function tp_admin_work_price_delete(PDO $pdo, int $id)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $row = tp_admin_work_price_get($pdo, $id);
    if ($row === null) {
        return 'Позиция не найдена';
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
    $st = $pdo->prepare('DELETE FROM work_prices WHERE id = ? LIMIT 1');
    $st->execute([$id]);

    return true;
}
