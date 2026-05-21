<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_panels.php');
tp_admin_web_require_include('admin_audit_log.php');

$pdo = tp_admin_web_require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['delete_panel'])) {
    header('Location: catalog_panels.php', true, 303);
    exit;
}

if (!tp_admin_web_csrf_check($_POST['csrf'] ?? null)) {
    http_response_code(403);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'CSRF';
    exit;
}

$id = (int) ($_POST['id'] ?? 0);
$res = tp_admin_panel_catalog_delete($pdo, $id);
if ($res !== true) {
    http_response_code(400);
    header('Content-Type: text/plain; charset=utf-8');
    echo is_string($res) ? $res : 'Ошибка';
    exit;
}

tp_admin_audit_log_write($pdo, 'catalog_panel_delete', 'panel', $id > 0 ? $id : null, null);

header('Location: catalog_panels.php', true, 303);
exit;
