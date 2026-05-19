<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_materials.php');

$pdo = tp_admin_web_require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['delete_material'])) {
    header('Location: catalog_materials.php', true, 303);
    exit;
}

if (!tp_admin_web_csrf_check($_POST['csrf'] ?? null)) {
    http_response_code(403);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'CSRF';
    exit;
}

$id = (int) ($_POST['id'] ?? 0);
$res = tp_admin_catalog_material_delete($pdo, $id);
if ($res !== true) {
    http_response_code(400);
    header('Content-Type: text/plain; charset=utf-8');
    echo is_string($res) ? $res : 'Ошибка';
    exit;
}

header('Location: catalog_materials.php', true, 303);
exit;
