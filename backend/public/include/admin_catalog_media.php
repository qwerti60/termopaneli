<?php
declare(strict_types=1);

/**
 * Загрузка картинок каталога в public/catalog_uploads/ (веб-админка).
 * В БД хранится путь относительно корня public, напр. catalog_uploads/materials/abc.jpg
 */

/** Удалить файл только если путь внутри catalog_uploads/ (безопасность). */
function tp_admin_catalog_upload_is_managed(string $relativePath): bool
{
    $p = str_replace('\\', '/', trim($relativePath));

    return $p !== '' && !str_contains($p, '..') && str_starts_with($p, 'catalog_uploads/');
}

function tp_admin_catalog_upload_try_unlink(?string $relativePath): void
{
    if ($relativePath === null || $relativePath === '') {
        return;
    }
    if (!tp_admin_catalog_upload_is_managed($relativePath)) {
        return;
    }
    $full = TP_PUBLIC_ROOT . '/' . $relativePath;
    if (is_file($full)) {
        @unlink($full);
    }
}

/**
 * @param array|null $file элемент $_FILES['…']
 * @return array{ok: true, relative_path: string}|array{ok: false, error: string}
 */
function tp_admin_catalog_upload_save_image(?array $file, string $subdir): array
{
    $subdir = preg_replace('/[^a-z0-9_-]/', '', strtolower($subdir));
    if ($subdir === '') {
        $subdir = 'misc';
    }

    if ($file === null || !isset($file['error']) || (int) $file['error'] === UPLOAD_ERR_NO_FILE) {
        return ['ok' => false, 'error' => 'Файл не выбран'];
    }
    if ((int) $file['error'] !== UPLOAD_ERR_OK) {
        return ['ok' => false, 'error' => 'Ошибка загрузки файла'];
    }

    $tmp = (string) ($file['tmp_name'] ?? '');
    if ($tmp === '' || !is_uploaded_file($tmp)) {
        return ['ok' => false, 'error' => 'Некорректная загрузка'];
    }

    $size = (int) ($file['size'] ?? 0);
    if ($size > 5 * 1024 * 1024) {
        return ['ok' => false, 'error' => 'Файл больше 5 МБ'];
    }

    $mime = '';
    if (class_exists('finfo')) {
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mime = $finfo->file($tmp) ?: '';
    }
    if ($mime === '') {
        $imgInfo = @getimagesize($tmp);
        if (is_array($imgInfo) && isset($imgInfo['mime'])) {
            $mime = (string) $imgInfo['mime'];
        }
    }
    $extMap = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];
    if (!isset($extMap[$mime])) {
        return ['ok' => false, 'error' => 'Допустимы только JPEG, PNG, WebP'];
    }
    $ext = $extMap[$mime];

    $baseDir = TP_PUBLIC_ROOT . '/catalog_uploads/' . $subdir;
    if (!is_dir($baseDir)) {
        if (!@mkdir($baseDir, 0775, true) && !is_dir($baseDir)) {
            return ['ok' => false, 'error' => 'Не удалось создать каталог catalog_uploads (права на запись?)'];
        }
    }

    $name = 'img_' . bin2hex(random_bytes(8)) . '.' . $ext;
    $destFs = $baseDir . '/' . $name;
    $relative = 'catalog_uploads/' . $subdir . '/' . $name;

    if (!@move_uploaded_file($tmp, $destFs)) {
        return ['ok' => false, 'error' => 'Не удалось сохранить файл'];
    }
    @chmod($destFs, 0664);

    return ['ok' => true, 'relative_path' => $relative];
}
