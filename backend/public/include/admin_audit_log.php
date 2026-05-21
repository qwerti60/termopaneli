<?php
declare(strict_types=1);

/**
 * Журнал действий администратора (веб-админка). Таблица: admin_audit_log.
 * Запись не должна ломать основной сценарий при ошибке БД — ошибки в error_log.
 */

function tp_admin_audit_client_ip(): string
{
    $xff = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? '';
    if (is_string($xff) && $xff !== '') {
        $first = trim(explode(',', $xff, 2)[0]);
        if ($first !== '' && strlen($first) <= 45) {
            return $first;
        }
    }
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';

    return is_string($ip) && strlen($ip) <= 45 ? $ip : '';
}

/**
 * @param non-empty-string $action
 */
function tp_admin_audit_log_write(
    PDO $pdo,
    string $action,
    ?string $targetType = null,
    ?int $targetId = null,
    ?string $detail = null,
    ?string $adminLoginOverride = null
): void {
    try {
        $login = $adminLoginOverride ?? (string) ($_SESSION['admin_web_login'] ?? '');
        if (strlen($action) > 80) {
            $action = substr($action, 0, 80);
        }
        if ($targetType !== null && strlen($targetType) > 40) {
            $targetType = substr($targetType, 0, 40);
        }
        if (strlen($login) > 64) {
            $login = substr($login, 0, 64);
        }
        $st = $pdo->prepare(
            'INSERT INTO admin_audit_log (admin_login, action, target_type, target_id, ip, detail)
             VALUES (?, ?, ?, ?, ?, ?)'
        );
        $st->execute([
            $login,
            $action,
            $targetType,
            $targetId,
            tp_admin_audit_client_ip(),
            $detail,
        ]);
    } catch (Throwable $e) {
        error_log('tp_admin_audit_log_write: ' . $e->getMessage());
    }
}

/**
 * @return list<array<string, mixed>>
 */
function tp_admin_audit_log_list(PDO $pdo, int $limit): array
{
    if ($limit < 1) {
        $limit = 100;
    }
    if ($limit > 500) {
        $limit = 500;
    }
    $lim = (int) $limit;
    $sql = 'SELECT id, created_at, admin_login, action, target_type, target_id, ip, detail
            FROM admin_audit_log
            ORDER BY id DESC
            LIMIT ' . $lim;
    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}
