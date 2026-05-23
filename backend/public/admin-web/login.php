<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';

$error = '';
$flashOk = '';
if (isset($_GET['reset']) && (string) $_GET['reset'] === '1') {
    $flashOk = 'Пароль изменён. Войдите с новым паролем.';
} elseif (isset($_GET['pw']) && (string) $_GET['pw'] === '1') {
    $flashOk = 'Пароль изменён. Войдите снова с новым паролем.';
}

if (isset($_SESSION['admin_web_token']) && is_string($_SESSION['admin_web_token']) && $_SESSION['admin_web_token'] !== '') {
    header('Location: requests.php', true, 302);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    tp_admin_web_require_include('admin_login_verify.php');
    $login = (string) ($_POST['login'] ?? '');
    $password = (string) ($_POST['password'] ?? '');
    $pdo = tp_pdo();
    $result = tp_admin_perform_login($pdo, $login, $password);
    if ($result['ok'] === true) {
        session_regenerate_id(true);
        $_SESSION['admin_web_token'] = $result['token'];
        $_SESSION['admin_web_login'] = $result['login'];
        tp_admin_web_require_include('admin_audit_log.php');
        tp_admin_audit_log_write(tp_pdo(), 'admin_login', null, null, null);
        header('Location: requests.php', true, 302);
        exit;
    }
    $error = (string) $result['message'];
}

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Вход администратора</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 28rem; margin: 2rem auto; padding: 0 1rem; }
        h1 { font-size: 1.25rem; }
        label { display: block; margin-top: 1rem; font-weight: 600; }
        input[type=text], input[type=password] { width: 100%; box-sizing: border-box; padding: 0.5rem; margin-top: 0.25rem; }
        button { margin-top: 1.25rem; padding: 0.5rem 1rem; cursor: pointer; }
        .err { color: #b00020; margin-top: 1rem; }
        .ok { color: #15803d; margin-top: 1rem; }
    </style>
</head>
<body>
    <h1>Вход администратора</h1>
    <?php if ($flashOk !== '') { ?>
        <p class="ok"><?= tp_admin_web_h($flashOk) ?></p>
    <?php } ?>
    <?php if ($error !== '') { ?>
        <p class="err"><?= tp_admin_web_h($error) ?></p>
    <?php } ?>
    <form method="post" action="login.php" autocomplete="off">
        <label for="login">Логин</label>
        <input id="login" name="login" type="text" required maxlength="64" value="">
        <label for="password">Пароль</label>
        <input id="password" name="password" type="password" required maxlength="256" value="">
        <button type="submit">Войти</button>
    </form>
    <p style="margin-top:1.25rem;"><a href="login_reset.php">Забыли пароль? Сброс по коду из e-mail</a></p>
</body>
</html>
