<?php
declare(strict_types=1);

/**
 * Bearer-пользователь (user_profiles): валидный токен и не заблокирован.
 * Подключать после api_bootstrap.php.
 */

function tp_json_user_blocked(): void
{
    tp_json_response(403, [
        'error' => 'forbidden',
        'code' => 'user_blocked',
        'message' => 'Аккаунт заблокирован. Обратитесь в поддержку.',
    ]);
}

/**
 * Проверка токена: 401 при отсутствии/невалидном, 403 при блокировке, иначе id пользователя.
 */
function tp_user_require_active_json(PDO $pdo): int
{
    $token = tp_bearer_token();
    if ($token === null || $token === '') {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    $st = $pdo->prepare(
        'SELECT id, COALESCE(is_blocked, 0) AS is_blocked
         FROM user_profiles
         WHERE token = ?
         LIMIT 1'
    );
    $st->execute([$token]);
    $row = $st->fetch(PDO::FETCH_ASSOC);
    if ($row === false) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    if ((int) ($row['is_blocked'] ?? 0) === 1) {
        tp_json_user_blocked();
        exit;
    }

    return (int) $row['id'];
}

/**
 * Для сценариев без немедленного JSON exit: null — нет/невалидный токен; ключ 'blocked'=>true.
 *
 * @return array{id: int, blocked: bool}|null
 */
function tp_user_resolve_bearer(PDO $pdo): ?array
{
    $token = tp_bearer_token();
    if ($token === null || $token === '') {
        return null;
    }
    $st = $pdo->prepare(
        'SELECT id, COALESCE(is_blocked, 0) AS is_blocked
         FROM user_profiles
         WHERE token = ?
         LIMIT 1'
    );
    $st->execute([$token]);
    $row = $st->fetch(PDO::FETCH_ASSOC);
    if ($row === false) {
        return null;
    }

    return [
        'id' => (int) $row['id'],
        'blocked' => ((int) ($row['is_blocked'] ?? 0) === 1),
    ];
}
