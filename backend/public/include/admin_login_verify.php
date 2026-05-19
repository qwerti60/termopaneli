<?php
declare(strict_types=1);

/**
 * Проверка логина/пароля админа и выдача session-токена (общее для API и веб-админки).
 *
 * @return array{ok: true, token: string, login: string}|array{ok: false, message: string}
 */
function tp_admin_perform_login(PDO $pdo, string $login, string $password): array
{
    $login = trim($login);
    if ($login === '' || $password === '') {
        return ['ok' => false, 'message' => 'Укажите логин и пароль'];
    }

    $st = $pdo->prepare(
        'SELECT id, login, password_hash FROM admin_accounts WHERE login = ? LIMIT 1'
    );
    $st->execute([$login]);
    $row = $st->fetch();
    if ($row === false || !password_verify($password, (string) $row['password_hash'])) {
        return ['ok' => false, 'message' => 'Неверный логин или пароль'];
    }

    $id = (int) $row['id'];
    $token = bin2hex(random_bytes(32));
    $upd = $pdo->prepare(
        'UPDATE admin_accounts SET token = ?, token_updated_at = NOW() WHERE id = ?'
    );
    $upd->execute([$token, $id]);

    return [
        'ok' => true,
        'token' => $token,
        'login' => (string) $row['login'],
    ];
}
