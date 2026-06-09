<?php
declare(strict_types=1);

function tp_admin_app_settings_local_path(): string
{
    return dirname(__DIR__) . '/config.local.php';
}

/**
 * @return array<string, mixed>
 */
function tp_admin_app_settings_local_config(): array
{
    $path = tp_admin_app_settings_local_path();
    if (!is_readable($path)) {
        return [];
    }

    $cfg = require $path;
    return is_array($cfg) ? $cfg : [];
}

function tp_admin_app_settings_yandex_banner_id(): string
{
    $cfg = tp_config();
    $appManifest = $cfg['app_manifest'] ?? null;
    if (!is_array($appManifest)) {
        return '';
    }

    $value = $appManifest['yandex_banner_ad_unit_id'] ?? '';
    return is_string($value) ? trim($value) : '';
}

function tp_admin_app_settings_validate_yandex_banner_id(string $value): string
{
    $value = trim($value);
    if ($value === '') {
        return '';
    }
    if (!preg_match('/^R-M-\d+(?:-\d+)?$/', $value)) {
        throw new InvalidArgumentException('ID блока РСЯ должен быть в формате R-M-19410021-1.');
    }

    return $value;
}

function tp_admin_app_settings_save_yandex_banner_id(string $adUnitId): void
{
    $adUnitId = tp_admin_app_settings_validate_yandex_banner_id($adUnitId);
    $cfg = tp_admin_app_settings_local_config();
    if (!isset($cfg['app_manifest']) || !is_array($cfg['app_manifest'])) {
        $cfg['app_manifest'] = [];
    }
    $cfg['app_manifest']['yandex_banner_ad_unit_id'] = $adUnitId;

    $path = tp_admin_app_settings_local_path();
    $dir = dirname($path);
    if (!is_dir($dir) || !is_writable($dir)) {
        throw new RuntimeException('Каталог public недоступен для записи config.local.php.');
    }
    if (is_file($path) && !is_writable($path)) {
        throw new RuntimeException('Файл config.local.php недоступен для записи.');
    }

    $php = "<?php\n"
        . "/**\n"
        . " * Локальные переопределения config.php. Файл создан веб-админкой.\n"
        . " * Не публикуйте его в git: здесь могут быть серверные настройки.\n"
        . " */\n"
        . "declare(strict_types=1);\n\n"
        . 'return ' . var_export($cfg, true) . ";\n";

    $tmp = $path . '.tmp';
    if (file_put_contents($tmp, $php, LOCK_EX) === false) {
        throw new RuntimeException('Не удалось записать временный файл config.local.php.');
    }
    if (!rename($tmp, $path)) {
        @unlink($tmp);
        throw new RuntimeException('Не удалось заменить config.local.php.');
    }
}
