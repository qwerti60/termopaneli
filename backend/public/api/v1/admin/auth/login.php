<?php
declare(strict_types=1);

/**
 * POST JSON — вход администратора (логин + пароль), выдача Bearer для admin API.
 * Тело: { "login": "admin", "password": "..." }
 * Ответ 200: { "token": "<64 hex>", "login": "admin" }
 */
require_once dirname(__DIR__, 4) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 4) . '/include/admin_login_verify.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw ?: '[]', true);
    if (!is_array($data)) {
        tp_json_response(400, ['message' => 'Некорректный JSON']);
        exit;
    }
    $login = trim((string) ($data['login'] ?? ''));
    $password = (string) ($data['password'] ?? '');
    if ($login === '' || $password === '') {
        tp_json_response(400, ['message' => 'Укажите логин и пароль']);
        exit;
    }

    $pdo = tp_pdo();
    $result = tp_admin_perform_login($pdo, $login, $password);
    if ($result['ok'] !== true) {
        tp_json_response(401, ['message' => $result['message']]);
        exit;
    }

    tp_json_response(200, [
        'token' => $result['token'],
        'login' => $result['login'],
    ]);
} catch (Throwable $e) {
    error_log('Admin login error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка входа',
        'message' => $debug ? $e->getMessage() : 'Попробуйте повторить позже',
    ]);
}
