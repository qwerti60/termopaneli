<?php
declare(strict_types=1);

/**
 * GET — единый публичный манифест для приложения: реквизиты PDF + юр. ссылки.
 * Без Authorization. Кэш 5 минут.
 *
 * Ответ JSON:
 * {
 *   "version": 1,
 *   "company_pdf": { ... те же поля, что в company-for-pdf.php ... },
 *   "user_agreement_url": "...",
 *   "privacy_policy_url": "",
 *   "smartcalc_url": ""
 * }
 *
 * Опционально в config.php:
 *   'app_manifest' => [
 *     'privacy_policy_url' => 'https://...',
 *     'smartcalc_url' => 'https://...', // SmartCalc для WebView в приложении (PRO)
 *   ],
 */
require_once dirname(__DIR__, 3) . '/include/api_bootstrap.php';
require_once dirname(__DIR__, 3) . '/include/company_pdf_defaults.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    tp_json_response(405, ['error' => 'Method Not Allowed']);
    exit;
}

try {
    $cfg = tp_config();
    $companyPdf = tp_company_pdf_settings();

    $privacy = '';
    $appManifest = $cfg['app_manifest'] ?? null;
    if (is_array($appManifest) && isset($appManifest['privacy_policy_url'])) {
        $p = $appManifest['privacy_policy_url'];
        if (is_string($p)) {
            $privacy = trim($p);
        }
    }

    $smartcalc = '';
    if (is_array($appManifest) && isset($appManifest['smartcalc_url'])) {
        $s = $appManifest['smartcalc_url'];
        if (is_string($s)) {
            $smartcalc = trim($s);
        }
    }

    header('Cache-Control: public, max-age=300');
    tp_json_response(200, [
        'version' => 1,
        'company_pdf' => $companyPdf,
        'user_agreement_url' => $companyPdf['user_agreement_url'] ?? '',
        'privacy_policy_url' => $privacy,
        'smartcalc_url' => $smartcalc,
    ]);
} catch (Throwable) {
    tp_json_response(500, ['error' => 'Ошибка чтения настроек']);
}
