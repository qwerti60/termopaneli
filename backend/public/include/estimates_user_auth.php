<?php
declare(strict_types=1);

/**
 * Авторизация пользователя для API смет (Bearer → user_profiles.id, не заблокирован).
 * Подключать после api_bootstrap.php.
 */
require_once __DIR__ . '/user_bearer_guard.php';

function tp_estimates_require_user(?PDO $pdo = null): int
{
    return tp_user_require_active_json($pdo ?? tp_pdo());
}
