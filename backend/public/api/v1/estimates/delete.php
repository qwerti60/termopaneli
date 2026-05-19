<?php
declare(strict_types=1);

/**
 * POST JSON — удаление сохранённой сметы текущего пользователя.
 * Заголовок: Authorization: Bearer <token>
 * Тело: { "estimate_id": 123 }
 *
 * Удаляется строка estimates (строки estimate_items и estimate_requests снимаются каскадом).
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/estimates_user_auth.php';

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

    $estimateId = (int) ($data['estimate_id'] ?? 0);
    if ($estimateId <= 0) {
        tp_json_response(400, ['message' => 'Некорректная смета']);
        exit;
    }

    $userId = tp_estimates_auth_user_id();
    if ($userId === null) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }

    $pdo = tp_pdo();
    $st = $pdo->prepare('DELETE FROM estimates WHERE id = ? AND user_id = ? LIMIT 1');
    $st->execute([$estimateId, $userId]);
    if ($st->rowCount() !== 1) {
        tp_json_response(404, ['message' => 'Смета не найдена']);
        exit;
    }

    tp_json_response(200, ['ok' => true]);
} catch (Throwable $e) {
    error_log('Estimate delete error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка удаления сметы',
        'message' => $debug ? $e->getMessage() : 'Проверьте, что выполнен sql/schema_estimates.sql',
    ]);
}
