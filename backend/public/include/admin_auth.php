<?php
declare(strict_types=1);

/**
 * Авторизация админских API: Bearer = admin_api_token из config ИЛИ token из admin_accounts.
 */
function tp_admin_bearer(): ?string
{
    $fromHeader = tp_bearer_token();
    if ($fromHeader !== null && $fromHeader !== '') {
        return $fromHeader;
    }
    // Веб-админка: токен в PHP-сессии (см. public/admin-web/).
    if (session_status() === PHP_SESSION_ACTIVE) {
        $t = $_SESSION['admin_web_token'] ?? '';
        if (is_string($t) && $t !== '') {
            return $t;
        }
    }
    return null;
}

function tp_admin_authorized(PDO $pdo): bool
{
    $actual = tp_admin_bearer();
    if ($actual === null || $actual === '') {
        return false;
    }
    $cfg = tp_config();
    $cfgToken = trim((string) ($cfg['admin_api_token'] ?? ''));
    if ($cfgToken !== '' && hash_equals($cfgToken, $actual)) {
        return true;
    }
    try {
        $st = $pdo->prepare(
            'SELECT id FROM admin_accounts WHERE token = ? AND token IS NOT NULL AND token != \'\' LIMIT 1'
        );
        $st->execute([$actual]);
        return $st->fetch() !== false;
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * @return array{id: int, login: string}|null
 */
function tp_admin_session_from_bearer(PDO $pdo, string $bearer): ?array
{
    $st = $pdo->prepare(
        'SELECT id, login FROM admin_accounts WHERE token = ? AND token IS NOT NULL AND token != \'\' LIMIT 1'
    );
    $st->execute([$bearer]);
    $row = $st->fetch();
    if ($row === false) {
        return null;
    }
    return ['id' => (int) $row['id'], 'login' => (string) $row['login']];
}
