<?php
declare(strict_types=1);

/**
 * Авторизация пользователя для API смет (Bearer → user_profiles.id).
 * Подключать после api_bootstrap.php.
 */
function tp_estimates_auth_user_id(): ?int
{
    if (function_exists('tp_auth_user_id')) {
        return tp_auth_user_id();
    }

    $token = tp_bearer_token();
    if ($token === null || $token === '') {
        return null;
    }
    $pdo = tp_pdo();
    $st = $pdo->prepare('SELECT id FROM user_profiles WHERE token = ? LIMIT 1');
    $st->execute([$token]);
    $row = $st->fetch();
    if ($row === false) {
        return null;
    }

    return (int) $row['id'];
}
