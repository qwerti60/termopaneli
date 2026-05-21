<?php
declare(strict_types=1);

/**
 * Подписчики: пользователи с активной подпиской (строка в user_subscriptions) или флагом is_pro=1.
 *
 * @return list<array<string, mixed>>
 */
function tp_admin_subscribers_list(PDO $pdo, int $limit): array
{
    if ($limit < 1) {
        $limit = 100;
    }
    if ($limit > 500) {
        $limit = 500;
    }
    $lim = (int) $limit;
    $sql = 'SELECT u.id, u.phone, u.last_name, u.first_name, u.middle_name, u.email,
                   COALESCE(u.is_pro, 0) AS is_pro,
                   s.id AS subscription_id, s.plan_code, s.status AS subscription_status,
                   s.price_rub, s.started_at, s.expires_at, s.cancelled_at, s.created_at AS subscription_created
            FROM user_profiles u
            LEFT JOIN user_subscriptions s
              ON s.user_id = u.id
             AND s.status = \'active\'
             AND (s.expires_at IS NULL OR s.expires_at > UTC_TIMESTAMP())
            WHERE COALESCE(u.is_pro, 0) = 1
               OR s.id IS NOT NULL
            ORDER BY u.id DESC
            LIMIT ' . $lim;

    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}

/**
 * Журнал событий оплаты / подписки.
 *
 * @return list<array<string, mixed>>
 */
function tp_admin_subscription_events_list(PDO $pdo, int $limit, int $userIdFilter): array
{
    if ($limit < 1) {
        $limit = 200;
    }
    if ($limit > 2000) {
        $limit = 2000;
    }
    $lim = (int) $limit;
    if ($userIdFilter > 0) {
        $st = $pdo->prepare(
            'SELECT e.id, e.user_id, e.subscription_id, e.plan_code, e.amount_rub, e.event_type, e.detail, e.created_at,
                    u.phone, u.last_name, u.first_name
             FROM subscription_payment_events e
             JOIN user_profiles u ON u.id = e.user_id
             WHERE e.user_id = ?
             ORDER BY e.id DESC
             LIMIT ' . $lim
        );
        $st->execute([$userIdFilter]);

        return $st->fetchAll(PDO::FETCH_ASSOC) ?: [];
    }
    $sql = 'SELECT e.id, e.user_id, e.subscription_id, e.plan_code, e.amount_rub, e.event_type, e.detail, e.created_at,
                   u.phone, u.last_name, u.first_name
            FROM subscription_payment_events e
            JOIN user_profiles u ON u.id = e.user_id
            ORDER BY e.id DESC
            LIMIT ' . $lim;
    $st = $pdo->query($sql);

    return $st === false ? [] : $st->fetchAll(PDO::FETCH_ASSOC);
}
