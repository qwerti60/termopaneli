<?php
declare(strict_types=1);

/**
 * Реквизиты и ссылки для PDF из config.php → company_pdf с дефолтами.
 * Используется в company-for-pdf.php и app-manifest.php.
 *
 * @return array<string, string>
 */
function tp_company_pdf_settings(): array
{
    $cfg = tp_config();
    $defaults = [
        'legal_name' => 'ООО «ЭКОСТРОЙЛИДЕР»',
        'inn' => '7727316867',
        'phone' => '+7 925 480-36-16',
        'inn_line' => '',
        'phone_line' => '',
        'address' => '119034, Москва, ул. Пречистенка, 31/16',
        'area_note' => 'Работаем по Москве, Московской области и близлежащих областях.',
        'tagline' => 'Фасадные термопанели от производителя',
        'website' => 'https://термованель.москва',
        'user_agreement_url' => 'https://ivnovav.ru/tp_api/agreement.html',
    ];

    $over = $cfg['company_pdf'] ?? null;
    if (is_array($over)) {
        foreach (array_keys($defaults) as $key) {
            if (!array_key_exists($key, $over)) {
                continue;
            }
            $v = $over[$key];
            if (!is_string($v)) {
                continue;
            }
            $t = trim($v);
            if ($t !== '') {
                $defaults[$key] = $t;
            }
        }
    }

    return $defaults;
}
