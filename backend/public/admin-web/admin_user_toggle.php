<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_users.php');
tp_admin_web_require_include('admin_audit_log.php');

$pdo = tp_admin_web_require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['toggle_user_blocked'])) {
    header('Location: admin_users.php', true, 303);
    exit;
}

if (!tp_admin_web_csrf_check($_POST['csrf'] ?? null)) {
    header('Location: admin_users.php?err=' . rawurlencode('CSRF'), true, 303);
    exit;
}

$id = (int) ($_POST['id'] ?? 0);
$blocked = isset($_POST['blocked']) && (string) $_POST['blocked'] === '1';
$res = tp_admin_user_set_blocked($pdo, $id, $blocked);
if ($res !== true) {
    $msg = is_string($res) ? $res : 'Ошибка';
    header('Location: admin_users.php?err=' . rawurlencode($msg), true, 303);
    exit;
}

tp_admin_audit_log_write(
    $pdo,
    $blocked ? 'user_block' : 'user_unblock',
    'user_profile',
    $id,
    null
);

header('Location: admin_users.php?ok=1', true, 303);
exit;
