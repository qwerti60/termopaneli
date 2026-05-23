<?php
declare(strict_types=1);

/**
 * Сброс пароля админки без входа: запрос кода на email → ввод кода и нового пароля.
 */
require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_password_service.php');

if (isset($_SESSION['admin_web_token']) && is_string($_SESSION['admin_web_token']) && $_SESSION['admin_web_token'] !== '') {
    header('Location: requests.php', true, 302);
    exit;
}

$error = '';
$info = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = (string) ($_POST['csrf'] ?? '');
    if (!tp_admin_web_csrf_check($csrf)) {
        $error = 'Сессия устарела. Обновите страницу.';
    } else {
        $action = (string) ($_POST['action'] ?? '');
        $pdo = tp_pdo();
        if ($action === 'request') {
            $login = (string) ($_POST['login'] ?? '');
            $r = tp_admin_password_request_reset_otp($pdo, $login);
            if ($r['ok'] === true) {
                $info = (string) $r['message'];
            } else {
                $error = (string) $r['message'];
            }
        } elseif ($action === 'complete') {
            $login = (string) ($_POST['login'] ?? '');
            $code = (string) ($_POST['code'] ?? '');
            $p1 = (string) ($_POST['new_password'] ?? '');
            $p2 = (string) ($_POST['new_password2'] ?? '');
            $done = tp_admin_password_complete_reset($pdo, $login, $code, $p1, $p2);
            if ($done === true) {
                header('Location: login.php?reset=1', true, 303);
                exit;
            }
            $error = (string) $done;
        }
    }
}

header('Content-Type: text/html; charset=utf-8');
$csrfNew = tp_admin_web_csrf_token();
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Сброс пароля администратора</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 32rem; margin: 2rem auto; padding: 0 1rem; }
        h1 { font-size: 1.25rem; }
        label { display: block; margin-top: 1rem; font-weight: 600; }
        input[type=text], input[type=password] { width: 100%; box-sizing: border-box; padding: 0.5rem; margin-top: 0.25rem; }
        button { margin-top: 1rem; padding: 0.5rem 1rem; cursor: pointer; }
        .err { color: #b00020; margin-top: 1rem; }
        .info { color: #0f766e; margin-top: 1rem; }
        .meta { color: #64748b; font-size: 0.9rem; margin-top: 1.5rem; }
        a { color: #0369a1; }
    </style>
</head>
<body>
    <h1>Сброс пароля администратора</h1>
    <p class="meta">Укажите логин. На email из учётной записи (колонка <code>admin_accounts.email</code>) или на адрес из <code>config.php → mail.password_reset_fallback</code> придёт 6-значный код.</p>
    <?php if ($error !== '') { ?>
        <p class="err"><?= tp_admin_web_h($error) ?></p>
    <?php } ?>
    <?php if ($info !== '') { ?>
        <p class="info"><?= tp_admin_web_h($info) ?></p>
    <?php } ?>

    <h2 style="font-size:1rem;margin-top:1.5rem;">Шаг 1 — запрос кода</h2>
    <form method="post" action="login_reset.php" autocomplete="off">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h($csrfNew) ?>">
        <input type="hidden" name="action" value="request">
        <label for="login">Логин</label>
        <input id="login" name="login" type="text" required maxlength="64" value="">
        <button type="submit">Выслать код</button>
    </form>

    <h2 style="font-size:1rem;margin-top:2rem;">Шаг 2 — новый пароль</h2>
    <form method="post" action="login_reset.php" autocomplete="off">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h($csrfNew) ?>">
        <input type="hidden" name="action" value="complete">
        <label for="login2">Логин</label>
        <input id="login2" name="login" type="text" required maxlength="64" value="">
        <label for="code">Код из письма</label>
        <input id="code" name="code" type="text" required maxlength="6" pattern="[0-9]{6}" inputmode="numeric" placeholder="000000">
        <label for="np">Новый пароль</label>
        <input id="np" name="new_password" type="password" required minlength="<?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?>" maxlength="256" autocomplete="new-password">
        <label for="np2">Повторите пароль</label>
        <input id="np2" name="new_password2" type="password" required minlength="<?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?>" maxlength="256" autocomplete="new-password">
        <button type="submit">Сохранить новый пароль</button>
    </form>

    <p class="meta"><a href="login.php">← Вход в админку</a></p>
</body>
</html>
