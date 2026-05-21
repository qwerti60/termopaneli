<?php
declare(strict_types=1);

/**
 * Список пользователей приложения (user_profiles) для веб-админки.
 */

/**
 * @return list<array<string, mixed>>
 */
function tp_admin_users_list(PDO $pdo, int $limit): array
{
    if ($limit < 1) {
        $limit = 100;
    }
    if ($limit > 500) {
        $limit = 500;
    }
    $lim = (int) $limit;
    $sql = 'SELECT u.id, u.phone, u.last_name, u.first_name, u.middle_name, u.email,
                   u.is_pro, COALESCE(u.is_blocked, 0) AS is_blocked, u.created_at, u.token_updated_at,
                   (SELECT COUNT(*) FROM estimates e WHERE e.user_id = u.id) AS estimates_count
            FROM user_profiles u
            ORDER BY u.id DESC
            LIMIT ' . $lim;
    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}

/**
 * @return true|string
 */
function tp_admin_user_set_blocked(PDO $pdo, int $userId, bool $blocked)
{
    if ($userId <= 0) {
        return 'Некорректный пользователь';
    }
    $v = $blocked ? 1 : 0;
    $st = $pdo->prepare('UPDATE user_profiles SET is_blocked = ? WHERE id = ? LIMIT 1');
    $st->execute([$v, $userId]);
    if ($st->rowCount() !== 1) {
        return 'Пользователь не найден';
    }

    return true;
}
