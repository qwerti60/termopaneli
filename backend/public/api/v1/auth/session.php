<?php
declare(strict_types=1);

/**
 * GET — проверка токена (как в Flutter AuthApiService::validateSession).
 * Заголовок: Authorization: Bearer <token>
 * Ответ 200 — сессия действительна; 401 — нет.
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

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
    $sql = 'SELECT p.id FROM user_profiles p
            WHERE p.token = :token';
    $st = $pdo->prepare($sql);
    $st->execute(['token' => $token]);
    if ($st->fetch() === false) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    tp_json_response(200, ['valid' => true]);
} catch (Throwable $e) {
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
