<?php
/**
 * Фрагмент для config.php — минимум для веб-админки.
 * Скопируйте нужные ключи в свой config.php (backend/public/config.example.php — полный пример).
 */
declare(strict_types=1);

return [
    'db' => [
        'host' => 'localhost',
        'port' => 3306,
        'name' => 'your_database',
        'user' => 'your_user',
        'pass' => 'your_password',
        'charset' => 'utf8mb4',
    ],

    /** Длинная случайная строка для curl/скриптов; опционально для веб-UI */
    'admin_api_token' => '',

    /** Сброс пароля админки по email */
    'mail' => [
        'from' => 'admin@example.com',
        'from_name' => 'Project Admin',
        'password_reset_fallback' => '', // если у admin_accounts нет email
    ],
    'admin_password_otp_ttl_seconds' => 900,

    /** Только модуль PDF заявок */
    'company_pdf' => [
        'legal_name' => 'ООО «Пример»',
        'inn' => '',
        'phone' => '',
        'website' => 'https://example.com',
    ],

    'debug' => false,
];
