<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_auth.php');

$pdo = tp_pdo();
$bearer = (string) ($_SESSION['admin_web_token'] ?? '');
if ($bearer !== '') {
    $cfg = tp_config();
    $cfgToken = trim((string) ($cfg['admin_api_token'] ?? ''));
    if ($cfgToken === '' || !hash_equals($cfgToken, $bearer)) {
        $session = tp_admin_session_from_bearer($pdo, $bearer);
        if ($session !== null) {
            $st = $pdo->prepare(
                'UPDATE admin_accounts SET token = NULL, token_updated_at = NULL WHERE id = ?'
            );
            $st->execute([$session['id']]);
        }
    }
}

$_SESSION = [];
if (session_status() === PHP_SESSION_ACTIVE) {
    session_destroy();
}

header('Location: login.php', true, 302);
exit;
