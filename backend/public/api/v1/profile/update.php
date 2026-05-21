<?php
declare(strict_types=1);

/**
 * POST JSON — обновление ФИО и email текущего пользователя (телефон не меняется).
 * Заголовок: Authorization: Bearer <token>
 *
 * Тело:
 * {
 *   "last_name": "Иванов",
 *   "first_name": "Иван",
 *   "middle_name": "Иванович",
 *   "email": "ivan@example.com"
 * }
 *
 * Ответ 200: тот же JSON, что у GET profile/me.php.
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/user_bearer_guard.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$token = tp_bearer_token();
if ($token === null || $token === '') {
    tp_json_response(401, ['error' => 'Нет токена']);
    exit;
}

$raw = file_get_contents('php://input');
$data = json_decode($raw ?: '[]', true);
if (!is_array($data)) {
    tp_json_response(400, ['message' => 'Некорректный JSON']);
    exit;
}

$lastName = trim((string) ($data['last_name'] ?? ''));
$firstName = trim((string) ($data['first_name'] ?? ''));
$middleName = trim((string) ($data['middle_name'] ?? ''));
$email = trim((string) ($data['email'] ?? ''));

if ($lastName === '' || $firstName === '') {
    tp_json_response(400, ['message' => 'Укажите фамилию и имя']);
    exit;
}

if (mb_strlen($lastName, 'UTF-8') > 100 || mb_strlen($firstName, 'UTF-8') > 100 || mb_strlen($middleName, 'UTF-8') > 100) {
    tp_json_response(400, ['message' => 'ФИО не длиннее 100 символов']);
    exit;
}

if ($email === '') {
    tp_json_response(400, ['message' => 'Укажите эл. почту']);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    tp_json_response(400, ['message' => 'Некорректный email']);
    exit;
}

try {
    $pdo = tp_pdo();
    tp_user_require_active_json($pdo);

    $st = $pdo->prepare(
        'UPDATE user_profiles
         SET last_name = ?, first_name = ?, middle_name = ?, email = ?
         WHERE token = ?'
    );
    $st->execute([$lastName, $firstName, $middleName, $email, $token]);

    $sel = $pdo->prepare(
        'SELECT id, phone, first_name, last_name, middle_name, email
         FROM user_profiles
         WHERE token = ?
         LIMIT 1'
    );
    $sel->execute([$token]);
    $row = $sel->fetch(PDO::FETCH_ASSOC);
    if ($row === false) {
        tp_json_response(500, ['message' => 'Не удалось прочитать профиль']);
        exit;
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
    ]);
} catch (Throwable $e) {
    error_log('Profile update error: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
