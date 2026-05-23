<?php
declare(strict_types=1);

/**
 * Смена пароля (старый + новый) и сброс по коду из e-mail — для вошедшего администратора.
 */
require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_password_service.php');
tp_admin_web_require_include('admin_audit_log.php');

$pdo = tp_admin_web_require_login();
$bearer = (string) ($_SESSION['admin_web_token'] ?? '');
$session = tp_admin_session_from_bearer($pdo, $bearer);
if ($session === null) {
    header('Location: login.php', true, 302);
    exit;
}

$adminId = (int) $session['id'];
$adminLogin = (string) $session['login'];
$flashOk = '';
$flashErr = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = (string) ($_POST['csrf'] ?? '');
    if (!tp_admin_web_csrf_check($csrf)) {
        $flashErr = 'Сессия устарела. Обновите страницу.';
    } else {
        $action = (string) ($_POST['action'] ?? '');
        if ($action === 'change_old') {
            $old = (string) ($_POST['old_password'] ?? '');
            $p1 = (string) ($_POST['new_password'] ?? '');
            $p2 = (string) ($_POST['new_password2'] ?? '');
            $r = tp_admin_password_change_with_old($pdo, $adminId, $old, $p1, $p2);
            if ($r === true) {
                tp_admin_audit_log_write($pdo, 'admin_password_change', 'admin_account', $adminId, 'session');
                $_SESSION = [];
                if (session_status() === PHP_SESSION_ACTIVE) {
                    session_destroy();
                }
                header('Location: login.php?pw=1', true, 303);
                exit;
            }
            $flashErr = (string) $r;
        } elseif ($action === 'request_otp') {
            $r = tp_admin_password_request_reset_otp($pdo, $adminLogin);
            if ($r['ok'] === true) {
                $flashOk = (string) $r['message'];
            } else {
                $flashErr = (string) $r['message'];
            }
        } elseif ($action === 'reset_code') {
            $code = (string) ($_POST['code'] ?? '');
            $p1 = (string) ($_POST['new_password'] ?? '');
            $p2 = (string) ($_POST['new_password2'] ?? '');
            $r = tp_admin_password_reset_logged_in_with_code($pdo, $adminLogin, $code, $p1, $p2);
            if ($r === true) {
                tp_admin_audit_log_write($pdo, 'admin_password_reset_email', 'admin_account', $adminId, 'code');
                $_SESSION = [];
                if (session_status() === PHP_SESSION_ACTIVE) {
                    session_destroy();
                }
                header('Location: login.php?pw=1', true, 303);
                exit;
            }
            $flashErr = (string) $r;
        }
    }
}

$csrfNew = tp_admin_web_csrf_token();
tp_admin_web_layout_start('Пароль учётной записи', 'pw', $adminLogin);
?>
<?php if ($flashErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($flashErr) ?></p>
<?php } ?>
<?php if ($flashOk !== '') { ?>
    <p class="ok"><?= tp_admin_web_h($flashOk) ?></p>
<?php } ?>

<p class="meta">Логин: <strong><?= tp_admin_web_h($adminLogin) ?></strong>. После успешной смены пароля сессия завершается — войдите снова.</p>

<div class="card">
    <h2>Смена пароля (знаю текущий)</h2>
    <form method="post" action="admin_password.php" autocomplete="off">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h($csrfNew) ?>">
        <input type="hidden" name="action" value="change_old">
        <label class="b" for="old_password">Текущий пароль</label>
        <input class="in" id="old_password" name="old_password" type="password" required maxlength="256" autocomplete="current-password">
        <label class="b" for="new1">Новый пароль (не короче <?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?> символов)</label>
        <input class="in" id="new1" name="new_password" type="password" required minlength="<?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?>" maxlength="256" autocomplete="new-password">
        <label class="b" for="new1b">Повторите новый пароль</label>
        <input class="in" id="new1b" name="new_password2" type="password" required minlength="<?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?>" maxlength="256" autocomplete="new-password">
        <div class="form-actions">
            <button class="btn" type="submit">Сменить пароль</button>
        </div>
    </form>
</div>

<div class="card" style="margin-top:1rem;">
    <h2>Сброс по коду из e-mail</h2>
    <p class="meta">На почту из <code>admin_accounts.email</code> или <code>mail.password_reset_fallback</code> в config придёт код (как на странице входа).</p>
    <form method="post" action="admin_password.php" style="margin-bottom:1rem;">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h($csrfNew) ?>">
        <input type="hidden" name="action" value="request_otp">
        <button class="btn secondary" type="submit">Выслать код на email</button>
    </form>
    <form method="post" action="admin_password.php" autocomplete="off">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h($csrfNew) ?>">
        <input type="hidden" name="action" value="reset_code">
        <label class="b" for="code">Код из письма</label>
        <input class="in" id="code" name="code" type="text" required maxlength="6" pattern="[0-9]{6}" inputmode="numeric" placeholder="000000">
        <label class="b" for="new2">Новый пароль</label>
        <input class="in" id="new2" name="new_password" type="password" required minlength="<?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?>" maxlength="256" autocomplete="new-password">
        <label class="b" for="new2b">Повторите пароль</label>
        <input class="in" id="new2b" name="new_password2" type="password" required minlength="<?= (int) TP_ADMIN_PASSWORD_MIN_LEN ?>" maxlength="256" autocomplete="new-password">
        <div class="form-actions">
            <button class="btn" type="submit">Установить пароль по коду</button>
        </div>
    </form>
</div>

<p class="meta"><a href="requests.php">← В заявки</a></p>
<?php
tp_admin_web_layout_end();
