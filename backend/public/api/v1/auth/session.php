<?php
declare(strict_types=1);

/**
 * GET — проверка токена (как в Flutter AuthApiService::validateSession).
 * Заголовок: Authorization: Bearer <token>
 * Ответ 200 — сессия действительна; 401 — нет.
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
    $u = tp_user_resolve_bearer($pdo);
    if ($u === null) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    if ($u['blocked']) {
        tp_json_user_blocked();
        exit;
    }
    tp_json_response(200, ['valid' => true]);
} catch (Throwable $e) {
    tp_json_response(500, ['error' => 'Ошибка сервера']);
}
