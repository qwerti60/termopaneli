<?php
declare(strict_types=1);

/**
 * POST — выход администратора (инвалидация session token в БД).
 * Заголовок: Authorization: Bearer <token из login.php>
 * Статический admin_api_token из config не трогаем (он не хранится в БД).
 */
require_once dirname(__DIR__, 4) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 4) . '/include/admin_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

$pdo = tp_pdo();
$bearer = tp_admin_bearer();
if ($bearer === null || $bearer === '') {
    tp_json_response(401, ['message' => 'Нет токена']);
    exit;
}

$cfg = tp_config();
$cfgToken = trim((string) ($cfg['admin_api_token'] ?? ''));
if ($cfgToken !== '' && hash_equals($cfgToken, $bearer)) {
    tp_json_response(200, ['ok' => true, 'note' => 'config token unchanged']);
    exit;
}

try {
    $session = tp_admin_session_from_bearer($pdo, $bearer);
    if ($session === null) {
        tp_json_response(401, ['message' => 'Недействительный токен']);
        exit;
    }
    $st = $pdo->prepare(
        'UPDATE admin_accounts SET token = NULL, token_updated_at = NULL WHERE id = ?'
    );
    $st->execute([$session['id']]);
    tp_json_response(200, ['ok' => true]);
} catch (Throwable $e) {
    error_log('Admin logout error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка выхода',
        'message' => $debug ? $e->getMessage() : 'Попробуйте повторить позже',
    ]);
}
