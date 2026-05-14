<?php
declare(strict_types=1);

/**
 * POST JSON — отправка сохраненной сметы как заявки в ЛКА.
 * Заголовок: Authorization: Bearer <token>
 * Тело:
 * {
 *   "estimate_id": 123,
 *   "comment": "Комментарий"
 * }
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';

function tp_estimates_auth_user_id(): ?int
{
    if (function_exists('tp_auth_user_id')) {
        return tp_auth_user_id();
    }

    $token = tp_bearer_token();
    if ($token === null || $token === '') {
        return null;
    }
    $pdo = tp_pdo();
    $st = $pdo->prepare('SELECT id FROM user_profiles WHERE token = ? LIMIT 1');
    $st->execute([$token]);
    $row = $st->fetch();
    if ($row === false) {
        return null;
    }
    return (int) $row['id'];
}

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
    $comment = trim((string) ($data['comment'] ?? ''));

    $userId = tp_estimates_auth_user_id();
    if ($userId === null) {
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }

    $pdo = tp_pdo();
    $pdo->beginTransaction();

    $profileSt = $pdo->prepare(
        'SELECT last_name, first_name, middle_name, phone, email
         FROM user_profiles
         WHERE id = ?
         LIMIT 1'
    );
    $profileSt->execute([$userId]);
    $profile = $profileSt->fetch();
    if ($profile === false) {
        $pdo->rollBack();
        tp_json_response(401, ['error' => 'Недействительный токен']);
        exit;
    }
    $contactName = trim(implode(' ', array_filter([
        (string) ($profile['last_name'] ?? ''),
        (string) ($profile['first_name'] ?? ''),
        (string) ($profile['middle_name'] ?? ''),
    ])));
    $contactPhone = trim((string) ($profile['phone'] ?? ''));
    $contactEmail = trim((string) ($profile['email'] ?? ''));

    $checkSt = $pdo->prepare(
        'SELECT id
         FROM estimates
         WHERE id = ? AND user_id = ?
         LIMIT 1'
    );
    $checkSt->execute([$estimateId, $userId]);
    if ($checkSt->fetch() === false) {
        $pdo->rollBack();
        tp_json_response(404, ['message' => 'Смета не найдена']);
        exit;
    }

    $requestRawJson = json_encode([
        'contact_name' => $contactName,
        'contact_phone' => $contactPhone,
        'contact_email' => $contactEmail,
        'comment' => $comment,
    ], JSON_UNESCAPED_UNICODE);

    $existingRequestSt = $pdo->prepare(
        'SELECT id
         FROM estimate_requests
         WHERE estimate_id = ? AND user_id = ?
         ORDER BY id DESC
         LIMIT 1'
    );
    $existingRequestSt->execute([$estimateId, $userId]);
    $existingRequest = $existingRequestSt->fetch();

    if ($existingRequest !== false) {
        $requestId = (int) $existingRequest['id'];
        $updateRequestSt = $pdo->prepare(
            'UPDATE estimate_requests
             SET contact_name = ?, contact_phone = ?, contact_email = ?,
                 comment = ?, raw_json = ?, updated_at = NOW()
             WHERE id = ?'
        );
        $updateRequestSt->execute([
            $contactName !== '' ? $contactName : null,
            $contactPhone !== '' ? $contactPhone : null,
            $contactEmail !== '' ? $contactEmail : null,
            $comment !== '' ? $comment : null,
            $requestRawJson,
            $requestId,
        ]);
    } else {
        $requestSt = $pdo->prepare(
            'INSERT INTO estimate_requests
             (estimate_id, user_id, status, contact_name, contact_phone, contact_email, comment, raw_json)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $requestSt->execute([
            $estimateId,
            $userId,
            'new',
            $contactName !== '' ? $contactName : null,
            $contactPhone !== '' ? $contactPhone : null,
            $contactEmail !== '' ? $contactEmail : null,
            $comment !== '' ? $comment : null,
            $requestRawJson,
        ]);
        $requestId = (int) $pdo->lastInsertId();
    }

    $st = $pdo->prepare(
        'UPDATE estimates
         SET status = ?, updated_at = NOW()
         WHERE id = ? AND user_id = ?'
    );
    $st->execute(['submitted', $estimateId, $userId]);

    $verifySt = $pdo->prepare(
        'SELECT id
         FROM estimate_requests
         WHERE estimate_id = ? AND user_id = ?
         ORDER BY id DESC
         LIMIT 1'
    );
    $verifySt->execute([$estimateId, $userId]);
    $verifyRow = $verifySt->fetch();
    if ($verifyRow === false) {
        $pdo->rollBack();
        error_log(
            'Estimate submit: нет строки estimate_requests после upsert, estimate_id='
            . $estimateId . ', user_id=' . $userId
        );
        tp_json_response(500, [
            'error' => 'Заявка не сохранилась',
            'message' => 'Повторите отправку. Если ошибка повторится — проверьте таблицу estimate_requests на сервере.',
        ]);
        exit;
    }
    $requestId = (int) $verifyRow['id'];

    $pdo->commit();

    tp_json_response(200, [
        'ok' => true,
        'estimate_id' => $estimateId,
        'request_id' => $requestId,
        'status' => 'submitted',
    ]);
} catch (Throwable $e) {
    try {
        if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
            $pdo->rollBack();
        }
    } catch (Throwable) {
    }
    error_log('Estimate submit error: ' . $e->getMessage());
    $cfg = tp_config();
    $debug = !empty($cfg['debug']);
    tp_json_response(500, [
        'error' => 'Ошибка отправки заявки',
        'message' => $debug ? $e->getMessage() : 'Попробуйте повторить позже',
    ]);
}
