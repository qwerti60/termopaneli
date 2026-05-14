<?php
declare(strict_types=1);

/**
 * GET — реквизиты и ссылки для шапки PDF (без авторизации).
 *
 * Значения по умолчанию совпадают с приложением; на сервере переопределите
 * ключ `company_pdf` в config.php (частично или полностью).
 *
 * Ответ JSON:
 * {
 *   "legal_name": "...",
 *   "inn": "7727316867",
 *   "phone": "+7 925 480-36-16",
 *   "address": "...",
 *   "area_note": "...",
 *   "tagline": "...",
 *   "website": "https://...",
 *   "user_agreement_url": "https://.../agreement.html"
 * }
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/company_pdf_defaults.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    header('Cache-Control: public, max-age=300');
    tp_json_response(200, tp_company_pdf_settings());
} catch (Throwable) {
    tp_json_response(500, ['error' => 'Ошибка чтения настроек']);
}
