<?php
declare(strict_types=1);

/**
 * POST JSON — завершение регистрации нового пользователя.
 * Тело:
 * {
 *   "phone":"79991234567",
 *   "code":"123456",
 *   "last_name":"Иванов",
 *   "first_name":"Иван",
 *   "middle_name":"Иванович",
 *   "email":"ivan@example.com",
 *   "accepted_user_agreement": true
 * }
 *
 * Создаёт запись в user_profiles только при полном наборе данных.
 * Успех 200: { "token":"...", "is_new_user": true }
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$raw = file_get_contents('php://input');
$data = json_decode($raw ?: '[]', true);
if (!is_array($data)) {
    tp_json_response(400, ['error' => 'Некорректный JSON']);
    exit;
}

$phone = tp_normalize_phone((string) ($data['phone'] ?? ''));
$code = preg_replace('/\D/', '', (string) ($data['code'] ?? ''));
$lastName = trim((string) ($data['last_name'] ?? ''));
$firstName = trim((string) ($data['first_name'] ?? ''));
$middleName = trim((string) ($data['middle_name'] ?? ''));
$email = trim((string) ($data['email'] ?? ''));
$rawAccepted = $data['accepted_user_agreement'] ?? false;
$acceptedAgreement = $rawAccepted === true
    || $rawAccepted === 1
    || $rawAccepted === '1'
    || $rawAccepted === 'true';

if (!$acceptedAgreement) {
    tp_json_response(400, ['message' => 'Необходимо принять пользовательское соглашение']);
    exit;
}

if ($phone === null || strlen($code) !== 6) {
    tp_json_response(400, ['message' => 'Укажите телефон и 6-значный код']);
    exit;
}

if ($lastName === '' || $firstName === '' || $middleName === '' || $email === '') {
    tp_json_response(400, ['message' => 'Заполните ФИО и эл. почту']);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    tp_json_response(400, ['message' => 'Некорректный email']);
    exit;
}

try {
    $pdo = tp_pdo();
    $pdo->beginTransaction();

    $cfg = tp_config();
    $staticOtp = trim((string) ($cfg['dev_static_otp_code'] ?? ''));
    $otpRow = null;
    $isStaticOtp = $staticOtp !== '' && $code === $staticOtp;

    if (!$isStaticOtp) {
        $st = $pdo->prepare(
            'SELECT id FROM sms_otp WHERE phone = ? AND code = ? AND expires_at > NOW() ORDER BY id DESC LIMIT 1'
        );
        $st->execute([$phone, $code]);
        $otpRow = $st->fetch();
        if ($otpRow === false) {
            $pdo->rollBack();
            tp_json_response(401, ['message' => 'Неверный код или срок кода истёк']);
            exit;
        }
    }

    $st = $pdo->prepare('SELECT id FROM user_profiles WHERE phone = ?');
    $st->execute([$phone]);
    $existing = $st->fetch();
    if ($existing !== false) {
        $pdo->rollBack();
        tp_json_response(409, ['message' => 'Пользователь уже существует']);
        exit;
    }

    $token = bin2hex(random_bytes(32));
    $ins = $pdo->prepare(
        'INSERT INTO user_profiles (phone, last_name, first_name, middle_name, email, token, token_updated_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW())'
    );
    $ins->execute([$phone, $lastName, $firstName, $middleName, $email, $token]);

    if (is_array($otpRow) && isset($otpRow['id'])) {
        $pdo->prepare('DELETE FROM sms_otp WHERE id = ?')->execute([(int) $otpRow['id']]);
    }

    $pdo->commit();
    tp_json_response(200, [
        'token' => $token,
        'is_new_user' => true,
    ]);
} catch (Throwable $e) {
    try {
        if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
            $pdo->rollBack();
        }
    } catch (Throwable) {
    }
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
