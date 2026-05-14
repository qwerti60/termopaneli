<?php
/**
 * Пример конфигурации. Скопируйте в config.php на сервере.
 * Не публикуйте config.php с паролями в открытый репозиторий.
 */
declare(strict_types=1);

return [
    'db' => [
        'host' => 'localhost',
        'port' => 3306,
        'name' => 'имя_базы',
        'user' => 'пользователь',
        'pass' => 'пароль',
        'charset' => 'utf8mb4',
    ],
    /** Для request-sms.php (отправка кода через smsc.ru) */
    'sms' => [
        'login' => '',
        'password' => '',
        'sender' => '',
    ],
    /** Время жизни OTP в секундах */
    'otp_ttl_seconds' => 300,
    /**
     * DEV-режим: фиксированный код для теста (например, '123456').
     * Пустая строка = отключено.
     */
    'dev_static_otp_code' => '',
    /**
     * Токен для MVP-админских API.
     * На сервере задайте длинную случайную строку и передавайте ее как Bearer token.
     */
    'admin_api_token' => '',
    /**
     * Реквизиты и ссылки для шапки PDF (переопределите поля при необходимости).
     * Отдаются через GET .../settings/company-for-pdf.php и внутри GET .../settings/app-manifest.php.
     */
    'company_pdf' => [
        // 'legal_name' => 'ООО «ЭКОСТРОЙЛИДЕР»',
        // 'inn' => '7727316867',
        // 'phone' => '+7 925 480-36-16',
        // 'address' => '...',
        // 'area_note' => '...',
        // 'tagline' => '...',
        // 'website' => 'https://термованель.москва',
        // 'user_agreement_url' => 'https://.../tp_api/agreement.html',
        // Необязательно: готовые строки для PDF (иначе приложение добавит «ИНН» / «Тел.»)
        // 'inn_line' => 'ИНН 7727316867',
        // 'phone_line' => 'Тел. +7 925 480-36-16',
    ],
    /**
     * Доп. поля для GET .../settings/app-manifest.php (необязательно).
     */
    'app_manifest' => [
        // 'privacy_policy_url' => 'https://.../privacy.html',
    ],
    /**
     * true — в JSON при 500 в поле message возвращается текст исключения (только для отладки).
     * В продакшене оставьте false.
     */
    'debug' => false,
];
