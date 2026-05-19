<?php
declare(strict_types=1);

/**
 * POST — завершить сессию: обнулить token у текущего пользователя.
 * Заголовок: Authorization: Bearer <token>
 *
 * Успех 200: { "ok": true }
 * 401: нет или неверный токен
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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
        'UPDATE user_profiles SET token = NULL, token_updated_at = NOW() WHERE token = ? LIMIT 1'
    );
    $st->execute([$token]);
    tp_json_response(200, ['ok' => true]);
} catch (Throwable $e) {
    error_log('Logout error: ' . $e->getMessage());
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
