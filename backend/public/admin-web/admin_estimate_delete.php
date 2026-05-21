<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_estimates.php');
tp_admin_web_require_include('admin_audit_log.php');

$pdo = tp_admin_web_require_login();

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['delete_estimate'])) {
    header('Location: admin_estimates.php', true, 303);
    exit;
}

if (!tp_admin_web_csrf_check($_POST['csrf'] ?? null)) {
    header('Location: admin_estimates.php?err=' . rawurlencode('CSRF'), true, 303);
    exit;
}

$id = (int) ($_POST['id'] ?? 0);
$res = tp_admin_estimate_delete_by_id($pdo, $id);
if ($res !== true) {
    $msg = is_string($res) ? $res : 'Ошибка';
    header('Location: admin_estimates.php?err=' . rawurlencode($msg), true, 303);
    exit;
}

tp_admin_audit_log_write($pdo, 'estimate_delete', 'estimate', $id > 0 ? $id : null, null);

header('Location: admin_estimates.php?ok=1', true, 303);
exit;
