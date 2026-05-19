<?php
declare(strict_types=1);

/**
 * Админ-операции над thermo_panel_catalog (веб-админка).
 * Схема таблицы на разных серверах может отличаться — список колонок берём из DESCRIBE.
 */

function tp_admin_catalog_pick(array $row, array $keys, string $fallback = ''): string
{
    foreach ($keys as $key) {
        if (isset($row[$key]) && trim((string) $row[$key]) !== '') {
            return trim((string) $row[$key]);
        }
    }

    return $fallback;
}

/**
 * @return list<array<string, string>>|null
 */
function tp_admin_panel_catalog_describe(PDO $pdo): ?array
{
    try {
        $st = $pdo->query('DESCRIBE thermo_panel_catalog');
        if ($st === false) {
            return null;
        }
        $rows = $st->fetchAll(PDO::FETCH_ASSOC);
        return $rows === false ? null : $rows;
    } catch (Throwable $e) {
        return null;
    }
}

function tp_admin_panel_catalog_row_title(array $row): string
{
    return tp_admin_catalog_pick(
        $row,
        ['title', 'name', 'panel_name', 'model', 'model_code', 'code', 'article'],
        '—'
    );
}

function tp_admin_panel_catalog_row_sku(array $row): string
{
    return tp_admin_catalog_pick($row, ['sku', 'article', 'code', 'model_code', 'id'], '');
}

function tp_admin_panel_catalog_row_price(array $row): string
{
    return tp_admin_catalog_pick($row, ['price_m2', 'price', 'price_per_m2_rub', 'panel_price'], '');
}

function tp_admin_panel_catalog_row_image(array $row): string
{
    return tp_admin_catalog_pick($row, ['image_path', 'image_url', 'image', 'photo', 'img', 'preview', 'picture'], '');
}

/**
 * @return array{rows: list<array<string, mixed>>, total: int}|array{error: string}
 */
function tp_admin_panel_catalog_list(PDO $pdo, int $offset, int $limit): array
{
    if (tp_admin_panel_catalog_describe($pdo) === null) {
        return ['error' => 'Таблица thermo_panel_catalog не найдена или недоступна'];
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

    $cntSt = $pdo->query('SELECT COUNT(*) AS c FROM thermo_panel_catalog');
    $total = (int) ($cntSt !== false ? ($cntSt->fetch(PDO::FETCH_ASSOC)['c'] ?? 0) : 0);

    $sql = 'SELECT * FROM thermo_panel_catalog ORDER BY id ASC LIMIT ' . (int) $limit . ' OFFSET ' . (int) $offset;
    $st = $pdo->query($sql);
    if ($st === false) {
        return ['error' => 'Не удалось прочитать каталог панелей'];
    }
    $rows = $st->fetchAll(PDO::FETCH_ASSOC);

    return ['rows' => $rows, 'total' => $total];
}

/**
 * @return array<string, mixed>|null
 */
function tp_admin_panel_catalog_get(PDO $pdo, int $id): ?array
{
    if ($id <= 0 || tp_admin_panel_catalog_describe($pdo) === null) {
        return null;
    }
    $st = $pdo->prepare('SELECT * FROM thermo_panel_catalog WHERE id = ? LIMIT 1');
    $st->execute([$id]);
    $row = $st->fetch(PDO::FETCH_ASSOC);

    return $row === false ? null : $row;
}

function tp_admin_panel_type_is_boolish(string $mysqlType): bool
{
    $t = strtolower($mysqlType);

    return str_starts_with($t, 'tinyint(1)') || str_starts_with($t, 'bit(1)');
}

function tp_admin_panel_type_is_numeric(string $mysqlType): bool
{
    $t = strtolower($mysqlType);

    return (bool) preg_match('/^(tinyint|smallint|mediumint|int|bigint|decimal|float|double)/', $t);
}

/** Целочисленные типы MySQL (кроме tinyint(1) / bit(1) — см. boolish). */
function tp_admin_panel_type_is_integerish(string $mysqlType): bool
{
    if (tp_admin_panel_type_is_boolish($mysqlType)) {
        return false;
    }
    $t = strtolower($mysqlType);

    return (bool) preg_match('/^(tinyint|smallint|mediumint|int|bigint)/', $t);
}

function tp_admin_panel_type_skip_edit(string $mysqlType): bool
{
    $t = strtolower($mysqlType);

    return str_contains($t, 'blob') || str_contains($t, 'binary') || str_contains($t, 'geometry');
}

/**
 * @param array<string, string> $p
 * @return true|string
 */
function tp_admin_panel_catalog_update(PDO $pdo, int $id, array $p)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $describe = tp_admin_panel_catalog_describe($pdo);
    if ($describe === null) {
        return 'Таблица thermo_panel_catalog недоступна';
    }
    $cur = tp_admin_panel_catalog_get($pdo, $id);
    if ($cur === null) {
        return 'Позиция не найдена';
    }

    $hasUpdatedAt = false;
    foreach ($describe as $col) {
        if (($col['Field'] ?? '') === 'updated_at') {
            $hasUpdatedAt = true;
            break;
        }
    }

    $sets = [];
    $params = [];

    foreach ($describe as $col) {
        $field = (string) ($col['Field'] ?? '');
        if ($field === '' || $field === 'id' || $field === 'created_at' || $field === 'updated_at') {
            continue;
        }
        $type = (string) ($col['Type'] ?? '');
        if (tp_admin_panel_type_skip_edit($type)) {
            continue;
        }
        $nullOk = (($col['Null'] ?? '') === 'YES');

        if (!array_key_exists($field, $p)) {
            if (tp_admin_panel_type_is_boolish($type)) {
                $p[$field] = '0';
            } else {
                continue;
            }
        }

        $raw = trim((string) $p[$field]);

        if (tp_admin_panel_type_is_boolish($type)) {
            $sets[] = '`' . str_replace('`', '``', $field) . '` = ?';
            $params[] = ($raw === '1' || strtolower($raw) === 'on' || strtolower($raw) === 'true') ? 1 : 0;
        } elseif (tp_admin_panel_type_is_numeric($type)) {
            if ($raw === '' && $nullOk) {
                $sets[] = '`' . str_replace('`', '``', $field) . '` = ?';
                $params[] = null;
            } elseif ($raw === '' && !$nullOk) {
                return 'Поле «' . $field . '» не может быть пустым';
            } else {
                $norm = str_replace(',', '.', $raw);
                if (!is_numeric($norm)) {
                    return 'Поле «' . $field . '»: ожидается число';
                }
                $sets[] = '`' . str_replace('`', '``', $field) . '` = ?';
                if (tp_admin_panel_type_is_integerish($type)) {
                    $params[] = (int) round((float) $norm);
                } else {
                    $params[] = 0 + (float) $norm;
                }
            }
        } else {
            if ($raw === '' && $nullOk) {
                $sets[] = '`' . str_replace('`', '``', $field) . '` = ?';
                $params[] = null;
            } else {
                $sets[] = '`' . str_replace('`', '``', $field) . '` = ?';
                $params[] = $raw;
            }
        }
    }

    if ($hasUpdatedAt) {
        $sets[] = '`updated_at` = NOW()';
    }

    if ($sets === []) {
        return 'Нет полей для сохранения (проверьте схему таблицы)';
    }

    $sql = 'UPDATE thermo_panel_catalog SET ' . implode(', ', $sets) . ' WHERE id = ?';
    $params[] = $id;
    $st = $pdo->prepare($sql);
    $st->execute($params);

    return true;
}

/** @return list<string> */
function tp_admin_panel_catalog_image_field_candidates(): array
{
    return ['image_path', 'image_url', 'image', 'photo', 'img', 'preview', 'picture'];
}

function tp_admin_panel_catalog_resolve_image_column(?array $describe): ?string
{
    if ($describe === null) {
        return null;
    }
    $fields = [];
    foreach ($describe as $c) {
        $fields[] = (string) ($c['Field'] ?? '');
    }
    foreach (tp_admin_panel_catalog_image_field_candidates() as $c) {
        if (in_array($c, $fields, true)) {
            return $c;
        }
    }

    return null;
}

/**
 * @param array<string, string> $p
 * @return array{ok: true, id: int}|array{ok: false, error: string}
 */
function tp_admin_panel_catalog_insert(PDO $pdo, array $p)
{
    $describe = tp_admin_panel_catalog_describe($pdo);
    if ($describe === null) {
        return ['ok' => false, 'error' => 'Таблица thermo_panel_catalog недоступна'];
    }

    $cols = [];
    $holders = [];
    $params = [];

    foreach ($describe as $col) {
        $field = (string) ($col['Field'] ?? '');
        if ($field === '' || $field === 'id' || $field === 'created_at' || $field === 'updated_at') {
            continue;
        }
        $type = (string) ($col['Type'] ?? '');
        if (tp_admin_panel_type_skip_edit($type)) {
            continue;
        }
        $nullOk = (($col['Null'] ?? '') === 'YES');
        $default = $col['Default'] ?? null;

        if (!array_key_exists($field, $p)) {
            if (tp_admin_panel_type_is_boolish($type)) {
                $p[$field] = '0';
            } elseif ($nullOk) {
                $p[$field] = '';
            } elseif ($default !== null) {
                continue;
            } else {
                return ['ok' => false, 'error' => 'Не заполнено обязательное поле: ' . $field];
            }
        }

        $raw = trim((string) $p[$field]);
        $val = null;

        if (tp_admin_panel_type_is_boolish($type)) {
            $val = ($raw === '1' || strtolower($raw) === 'on' || strtolower($raw) === 'true') ? 1 : 0;
        } elseif (tp_admin_panel_type_is_numeric($type)) {
            if ($raw === '' && $nullOk) {
                $val = null;
            } elseif ($raw === '' && !$nullOk) {
                if ($default !== null) {
                    continue;
                }

                return ['ok' => false, 'error' => 'Поле «' . $field . '» не может быть пустым'];
            } else {
                $norm = str_replace(',', '.', $raw);
                if (!is_numeric($norm)) {
                    return ['ok' => false, 'error' => 'Поле «' . $field . '»: ожидается число'];
                }
                $val = tp_admin_panel_type_is_integerish($type)
                    ? (int) round((float) $norm)
                    : (0 + (float) $norm);
            }
        } else {
            if ($raw === '' && $nullOk) {
                $val = null;
            } elseif ($raw === '' && !$nullOk) {
                if ($default !== null) {
                    continue;
                }

                return ['ok' => false, 'error' => 'Поле «' . $field . '» не может быть пустым'];
            } else {
                $val = $raw;
            }
        }

        $cols[] = '`' . str_replace('`', '``', $field) . '`';
        $holders[] = '?';
        $params[] = $val;
    }

    if ($cols === []) {
        return ['ok' => false, 'error' => 'Нет колонок для вставки'];
    }

    $sql = 'INSERT INTO thermo_panel_catalog (' . implode(', ', $cols) . ') VALUES (' . implode(', ', $holders) . ')';
    $st = $pdo->prepare($sql);
    $st->execute($params);

    return ['ok' => true, 'id' => (int) $pdo->lastInsertId()];
}

/**
 * @return true|string
 */
function tp_admin_panel_catalog_delete(PDO $pdo, int $id)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $describe = tp_admin_panel_catalog_describe($pdo);
    if ($describe === null) {
        return 'Таблица недоступна';
    }
    $row = tp_admin_panel_catalog_get($pdo, $id);
    if ($row === null) {
        return 'Позиция не найдена';
    }
    $imgCol = tp_admin_panel_catalog_resolve_image_column($describe);
    if ($imgCol !== null && defined('TP_PUBLIC_ROOT')) {
        $img = trim((string) ($row[$imgCol] ?? ''));
        if ($img !== '') {
            $rel = str_replace('\\', '/', $img);
            if (!str_contains($rel, '..') && str_starts_with($rel, 'catalog_uploads/')) {
                $full = TP_PUBLIC_ROOT . '/' . $rel;
                if (is_file($full)) {
                    @unlink($full);
                }
            }
        }
    }
    $st = $pdo->prepare('DELETE FROM thermo_panel_catalog WHERE id = ? LIMIT 1');
    $st->execute([$id]);

    return true;
}
