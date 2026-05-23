<?php
declare(strict_types=1);

require_once __DIR__ . '/admin_mail.php';

/** Минимальная длина нового пароля админки. */
const TP_ADMIN_PASSWORD_MIN_LEN = 10;

/**
 * Email для кода сброса: колонка admin_accounts.email или mail.password_reset_fallback в config.
 */
function tp_admin_password_reset_recipient(PDO $pdo, string $login): ?string
{
    $login = trim($login);
    if ($login === '') {
        return null;
    }
    $st = $pdo->prepare('SELECT email FROM admin_accounts WHERE login = ? LIMIT 1');
    $st->execute([$login]);
    $row = $st->fetch(PDO::FETCH_ASSOC);
    if ($row !== false) {
        $em = trim((string) ($row['email'] ?? ''));
        if ($em !== '' && filter_var($em, FILTER_VALIDATE_EMAIL)) {
            return $em;
        }
    }
    $cfg = tp_config()['mail'] ?? [];
    if (!is_array($cfg)) {
        return null;
    }
    $fb = trim((string) ($cfg['password_reset_fallback'] ?? ''));

    return $fb !== '' && filter_var($fb, FILTER_VALIDATE_EMAIL) ? $fb : null;
}

/**
 * @return true|string
 */
function tp_admin_password_validate_new(string $newPassword, string $newPassword2): bool|string
{
    if ($newPassword !== $newPassword2) {
        return 'Новый пароль и подтверждение не совпадают';
    }
    if (strlen($newPassword) < TP_ADMIN_PASSWORD_MIN_LEN) {
        return 'Новый пароль не короче ' . TP_ADMIN_PASSWORD_MIN_LEN . ' символов';
    }

    return true;
}

/**
 * Создать OTP и отправить письмо. Не раскрывает, существует ли логин (для публичной формы).
 *
 * @return array{ok: true, message: string}|array{ok: false, message: string}
 */
function tp_admin_password_request_reset_otp(PDO $pdo, string $login): array
{
    $login = trim($login);
    $genericOk = [
        'ok' => true,
        'message' => 'Если учётная запись с таким логином найдена и для неё задан email (или в config указан mail.password_reset_fallback), на почту отправлен код. Проверьте папку «Спам».',
    ];
    if ($login === '') {
        return $genericOk;
    }

    $st = $pdo->prepare('SELECT id FROM admin_accounts WHERE login = ? LIMIT 1');
    $st->execute([$login]);
    if ($st->fetch() === false) {
        return $genericOk;
    }

    $to = tp_admin_password_reset_recipient($pdo, $login);
    if ($to === null) {
        return $genericOk;
    }

    $ttl = (int) (tp_config()['admin_password_otp_ttl_seconds'] ?? 900);
    if ($ttl < 120) {
        $ttl = 900;
    }
    if ($ttl > 3600) {
        $ttl = 3600;
    }

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $pdo->prepare('DELETE FROM admin_password_reset_otp WHERE login = ?')->execute([$login]);
    $ins = $pdo->prepare(
        'INSERT INTO admin_password_reset_otp (login, code, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))'
    );
    $ins->execute([$login, $code, $ttl]);

    $body = "Код для сброса пароля веб-админки: {$code}\n\n"
        . "Срок действия кода: несколько минут. Если вы не запрашивали сброс, проигнорируйте письмо.\n"
        . 'Логин: ' . $login . "\n";

    $send = tp_admin_mail_send_plain($to, 'Код сброса пароля админки', $body);
    if ($send !== true) {
        error_log('admin reset mail: ' . $send);

        return ['ok' => false, 'message' => 'Не удалось отправить письмо: ' . $send];
    }

    return $genericOk;
}

/**
 * Сброс пароля по коду (без входа в сессию).
 *
 * @return true|string
 */
function tp_admin_password_complete_reset(
    PDO $pdo,
    string $login,
    string $code,
    string $newPassword,
    string $newPassword2
): bool|string {
    $v = tp_admin_password_validate_new($newPassword, $newPassword2);
    if ($v !== true) {
        return $v;
    }
    $login = trim($login);
    $code = preg_replace('/\D/', '', $code) ?? '';
    if ($login === '' || strlen($code) !== 6) {
        return 'Укажите логин и 6-значный код из письма';
    }

    $st = $pdo->prepare(
        'SELECT id FROM admin_password_reset_otp WHERE login = ? AND code = ? AND expires_at > NOW() ORDER BY id DESC LIMIT 1'
    );
    $st->execute([$login, $code]);
    $otp = $st->fetch(PDO::FETCH_ASSOC);
    if ($otp === false) {
        return 'Код неверен или истёк. Запросите новый.';
    }

    $st = $pdo->prepare('SELECT id FROM admin_accounts WHERE login = ? LIMIT 1');
    $st->execute([$login]);
    $acc = $st->fetch(PDO::FETCH_ASSOC);
    if ($acc === false) {
        return 'Учётная запись не найдена';
    }
    $id = (int) $acc['id'];
    $hash = password_hash($newPassword, PASSWORD_DEFAULT);
    $pdo->prepare('UPDATE admin_accounts SET password_hash = ?, token = NULL, token_updated_at = NULL WHERE id = ?')
        ->execute([$hash, $id]);
    $pdo->prepare('DELETE FROM admin_password_reset_otp WHERE login = ?')->execute([$login]);

    return true;
}

/**
 * Смена пароля при известном старом (вошедший админ по сессии).
 *
 * @return true|string
 */
function tp_admin_password_change_with_old(
    PDO $pdo,
    int $adminId,
    string $oldPassword,
    string $newPassword,
    string $newPassword2
): bool|string {
    $v = tp_admin_password_validate_new($newPassword, $newPassword2);
    if ($v !== true) {
        return $v;
    }
    $st = $pdo->prepare('SELECT password_hash FROM admin_accounts WHERE id = ? LIMIT 1');
    $st->execute([$adminId]);
    $row = $st->fetch(PDO::FETCH_ASSOC);
    if ($row === false) {
        return 'Учётная запись не найдена';
    }
    if (!password_verify($oldPassword, (string) $row['password_hash'])) {
        return 'Неверный текущий пароль';
    }
    $hash = password_hash($newPassword, PASSWORD_DEFAULT);
    $pdo->prepare('UPDATE admin_accounts SET password_hash = ?, token = NULL, token_updated_at = NULL WHERE id = ?')
        ->execute([$hash, $adminId]);

    return true;
}

/**
 * Сброс пароля по коду для уже вошедшего админа (тот же логин, что в сессии).
 *
 * @return true|string
 */
function tp_admin_password_reset_logged_in_with_code(
    PDO $pdo,
    string $login,
    string $code,
    string $newPassword,
    string $newPassword2
): bool|string {
    return tp_admin_password_complete_reset($pdo, $login, $code, $newPassword, $newPassword2);
}
