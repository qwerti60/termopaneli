<?php
declare(strict_types=1);

/**
 * GET — профиль текущего пользователя (без пароля и токена).
 * Заголовок: Authorization: Bearer <token>
 *
 * Ответ 200:
 * {
 *   "id": 1,
 *   "phone": "79991234567",
 *   "first_name": "...",
 *   "last_name": "...",
 *   "middle_name": "...",
 *   "email": "...",
 *   "display_name": "Фамилия Имя Отчество",
 *   "is_pro": false
 * }
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/user_bearer_guard.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$token = tp_bearer_token();
if ($token === null || $token === '') {
    tp_json_response(401, ['error' => 'Нет токена']);
    exit;
}

try {
    $pdo = tp_pdo();
    $st = $pdo->prepare(
        'SELECT id, phone, first_name, last_name, middle_name, email, COALESCE(is_pro, 0) AS is_pro,
                COALESCE(is_blocked, 0) AS is_blocked
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

    require_once dirname(__DIR__, 3) . '/include/subscriptions_repo.php';
    $uid = (int) $row['id'];
    tp_subscription_refresh_is_pro($pdo, $uid);
    $stPro = $pdo->prepare('SELECT COALESCE(is_pro, 0) AS is_pro FROM user_profiles WHERE id = ? LIMIT 1');
    $stPro->execute([$uid]);
    $proRow = $stPro->fetch(PDO::FETCH_ASSOC);
    if ($proRow !== false) {
        $row['is_pro'] = $proRow['is_pro'];
    }

    $parts = array_filter(
        [
            trim((string) ($row['last_name'] ?? '')),
            trim((string) ($row['first_name'] ?? '')),
            trim((string) ($row['middle_name'] ?? '')),
        ],
        static fn(string $s): bool => $s !== ''
    );
    $displayName = implode(' ', $parts);
    if ($displayName === '') {
        $displayName = 'Пользователь';
    }

    tp_json_response(200, [
        'id' => (int) $row['id'],
        'phone' => (string) $row['phone'],
        'first_name' => (string) $row['first_name'],
        'last_name' => (string) $row['last_name'],
        'middle_name' => (string) $row['middle_name'],
        'email' => (string) $row['email'],
        'display_name' => $displayName,
        'is_pro' => (bool) ((int) ($row['is_pro'] ?? 0) === 1),
    ]);
} catch (Throwable $e) {
    error_log('Profile me error: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
