#!/usr/bin/env php
<?php
/**
 * Проверка готовности админки к работе.
 *
 *   php admin-kit/verify_deploy.php --public=/path/to/tp_api
 *   php admin-kit/verify_deploy.php --public=backend/public
 */
declare(strict_types=1);

$public = '';
$url = '';
foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--public=')) {
        $public = rtrim(substr($arg, 9), '/');
    } elseif (str_starts_with($arg, '--url=')) {
        $url = rtrim(substr($arg, 6), '/');
    }
}

if ($public === '') {
    $public = dirname(__DIR__) . '/backend/public';
}

$errors = [];
$warnings = [];

function check_path(string $base, string $rel, array &$errors, string $label = ''): void
{
    $path = $base . '/' . ltrim($rel, '/');
    if (!is_readable($path)) {
        $errors[] = ($label !== '' ? $label . ': ' : '') . $path;
    }
}

$coreAdminWeb = [
    'admin-web/bootstrap_web.php',
    'admin-web/login.php',
    'admin-web/logout.php',
    'admin-web/admin_journal.php',
];
$coreInclude = [
    'include/api_bootstrap.php',
    'include/admin_auth.php',
    'include/admin_login_verify.php',
    'include/admin_audit_log.php',
];

foreach ($coreAdminWeb as $f) {
    check_path($public, $f, $errors, 'admin-web');
}
foreach ($coreInclude as $f) {
    check_path($public, $f, $errors, 'include');
}

$configPath = $public . '/config.php';
if (!is_readable($configPath)) {
    $errors[] = 'config.php не найден: ' . $configPath;
} else {
    /** @var array $cfg */
    $cfg = require $configPath;
    $db = $cfg['db'] ?? null;
    if (!is_array($db) || empty($db['name'])) {
        $errors[] = 'В config.php не задана секция db';
    } else {
        try {
            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                $db['host'] ?? 'localhost',
                (int) ($db['port'] ?? 3306),
                $db['name'],
                $db['charset'] ?? 'utf8mb4'
            );
            $pdo = new PDO($dsn, $db['user'] ?? '', $db['pass'] ?? '', [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            ]);
            $st = $pdo->query("SHOW TABLES LIKE 'admin_accounts'");
            if ($st->fetchColumn() === false) {
                $errors[] = 'Таблица admin_accounts отсутствует — выполните migrate_admin_accounts.sql';
            } else {
                $cnt = (int) $pdo->query('SELECT COUNT(*) FROM admin_accounts')->fetchColumn();
                if ($cnt === 0) {
                    $warnings[] = 'admin_accounts пуста — выполните migrate_admin_accounts.sql';
                }
            }
            if ($pdo->query("SHOW TABLES LIKE 'admin_audit_log'")->fetchColumn() === false) {
                $warnings[] = 'Нет admin_audit_log — журнал не будет работать';
            }
        } catch (Throwable $e) {
            $errors[] = 'MySQL: ' . $e->getMessage();
        }
    }
    if (empty($cfg['mail']['from'])) {
        $warnings[] = 'mail.from не задан — сброс пароля по email не сработает';
    }
}

$vendorCandidates = [
    dirname($public) . '/vendor/autoload.php',
    $public . '/vendor/autoload.php',
];
$hasDompdf = false;
foreach ($vendorCandidates as $v) {
    if (is_readable($v)) {
        require_once $v;
        $hasDompdf = class_exists(\Dompdf\Dompdf::class);
        break;
    }
}
if (!$hasDompdf && is_readable($public . '/admin-web/request_pdf.php')) {
    $warnings[] = 'Dompdf не найден — PDF заявок будет 503 (composer install dompdf/dompdf)';
}

$uploads = $public . '/catalog_uploads';
if (is_dir($uploads) && !is_writable($uploads)) {
    $warnings[] = 'catalog_uploads/ не доступен для записи';
}

echo "Проверка админки\n";
echo "Public root: {$public}\n";
if ($url !== '') {
    echo "Login URL: {$url}/admin-web/login.php\n";
}
echo "\n";

if ($warnings !== []) {
    echo "Предупреждения:\n";
    foreach ($warnings as $w) {
        echo "  ⚠ {$w}\n";
    }
    echo "\n";
}

if ($errors !== []) {
    echo "Ошибки:\n";
    foreach ($errors as $e) {
        echo "  ✗ {$e}\n";
    }
    exit(1);
}

echo "OK — ядро админки на месте, БД доступна.\n";
exit(0);
