<?php
declare(strict_types=1);

/**
 * Сметы (estimates) в веб-админке: список всех пользователей, удаление.
 */

/**
 * @return list<array<string, mixed>>
 */
function tp_admin_estimates_list(PDO $pdo, int $limit): array
{
    if ($limit < 1) {
        $limit = 100;
    }
    if ($limit > 500) {
        $limit = 500;
    }

    $lim = (int) $limit;
    $sql = 'SELECT e.id, e.user_id, e.title, e.status, e.total_amount, e.created_at, e.updated_at,
                   u.phone AS user_phone,
                   TRIM(CONCAT_WS(\' \', u.last_name, u.first_name, u.middle_name)) AS user_fio
            FROM estimates e
            INNER JOIN user_profiles u ON u.id = e.user_id
            ORDER BY e.id DESC
            LIMIT ' . $lim;

    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}

/**
 * @return true|string
 */
function tp_admin_estimate_delete_by_id(PDO $pdo, int $id)
{
    if ($id <= 0) {
        return 'Некорректный id';
    }
    $st = $pdo->prepare('DELETE FROM estimates WHERE id = ? LIMIT 1');
    $st->execute([$id]);
    if ($st->rowCount() !== 1) {
        return 'Смета не найдена';
    }

    return true;
}
