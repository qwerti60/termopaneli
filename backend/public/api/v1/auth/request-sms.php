<?php
declare(strict_types=1);

/**
 * POST JSON — запрос кода: сохраняет OTP и шлёт SMS через smsc.ru (если задан sms в config).
 * Тело: { "phone": "79991234567" }
 * Успех 200: { "sent": true }
 *
 * После этого пользователь вводит код в приложении, а verify-phone.php проверяет его в БД.
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
if ($phone === null) {
    tp_json_response(400, ['message' => 'Некорректный телефон']);
    exit;
}

$cfg = tp_config();
$ttl = (int) ($cfg['otp_ttl_seconds'] ?? 300);
if ($ttl < 60) {
    $ttl = 300;
}

$staticOtp = trim((string) ($cfg['dev_static_otp_code'] ?? ''));
$code = $staticOtp !== '' ? $staticOtp : (string) random_int(100000, 999999);

try {
    $pdo = tp_pdo();
    $pdo->prepare('DELETE FROM sms_otp WHERE phone = ?')->execute([$phone]);
    $expires = (new DateTimeImmutable())->modify('+' . $ttl . ' seconds')->format('Y-m-d H:i:s');
    $pdo->prepare('INSERT INTO sms_otp (phone, code, expires_at) VALUES (?, ?, ?)')
        ->execute([$phone, $code, $expires]);

    $sms = $cfg['sms'] ?? [];
    $login = (string) ($sms['login'] ?? '');
    $pass = (string) ($sms['password'] ?? '');
    if ($login !== '' && $pass !== '') {
        $params = [
            'login' => $login,
            'psw' => $pass,
            'phones' => $phone,
            'mes' => 'Код подтверждения: ' . $code,
            'fmt' => '3',
        ];
        if (!empty($sms['sender'])) {
            $params['sender'] = (string) $sms['sender'];
        }
        $url = 'https://smsc.ru/sys/send.php?' . http_build_query($params);
        $ctx = stream_context_create(['http' => ['timeout' => 15]]);
        $resp = @file_get_contents($url, false, $ctx);
        if ($resp === false) {
            tp_json_response(502, ['message' => 'Не удалось отправить SMS']);
            exit;
        }
        $json = json_decode($resp, true);
        if (is_array($json) && !empty($json['error'])) {
            tp_json_response(502, ['message' => (string) $json['error']]);
            exit;
        }
    }

    tp_json_response(200, ['sent' => true]);
} catch (Throwable $e) {
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
