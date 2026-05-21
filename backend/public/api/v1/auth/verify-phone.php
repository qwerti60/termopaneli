<?php
declare(strict_types=1);

/**
 * POST JSON — проверка телефона и кода.
 * Тело: { "phone": "79991234567", "code": "123456" }
 * Успех 200:
 * - существующий пользователь: { "token": "...", "is_new_user": false }
 * - новый пользователь: { "is_new_user": true } (без создания записи)
 *
 * Код должен быть ранее сохранён через request-sms.php (серверная отправка SMS).
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/user_bearer_guard.php';

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

if ($phone === null || strlen($code) !== 6) {
    tp_json_response(400, ['message' => 'Укажите телефон и 6-значный код']);
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

    $st = $pdo->prepare('SELECT id, COALESCE(is_blocked, 0) AS is_blocked FROM user_profiles WHERE phone = ?');
    $st->execute([$phone]);
    $profileRow = $st->fetch(PDO::FETCH_ASSOC);
    if ($profileRow === false) {
        $pdo->commit();
        tp_json_response(200, [
            'is_new_user' => true,
        ]);
        exit;
    }

    if ((int) ($profileRow['is_blocked'] ?? 0) === 1) {
        $pdo->rollBack();
        tp_json_user_blocked();
        exit;
    }

    $userId = (int) $profileRow['id'];
    if (is_array($otpRow) && isset($otpRow['id'])) {
        $pdo->prepare('DELETE FROM sms_otp WHERE id = ?')->execute([(int) $otpRow['id']]);
    }

    $token = bin2hex(random_bytes(32));
    $pdo->prepare('UPDATE user_profiles SET token = ?, token_updated_at = NOW() WHERE id = ?')
        ->execute([$token, $userId]);

    $pdo->commit();
    tp_json_response(200, [
        'token' => $token,
        'is_new_user' => false,
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
