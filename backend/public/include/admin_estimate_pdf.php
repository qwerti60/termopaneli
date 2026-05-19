<?php
declare(strict_types=1);

/**
 * PDF сметы для веб-админки (Dompdf). Требуется backend/vendor (composer install в каталоге backend/).
 */

require_once __DIR__ . '/admin_estimate_calc.php';

/**
 * Подключить Composer autoload. Ищет vendor/:
 * 1) родитель каталога public/ (как в репозитории: backend/vendor);
 * 2) внутри public/ (удобно для shared hosting: tp_api/vendor рядом с include/).
 */
function tp_admin_composer_autoload(): bool
{
    static $loaded = null;
    if ($loaded !== null) {
        return $loaded;
    }
    $publicDir = dirname(__DIR__);
    $candidates = [
        dirname($publicDir) . '/vendor/autoload.php',
        $publicDir . '/vendor/autoload.php',
    ];
    foreach ($candidates as $autoload) {
        if (is_readable($autoload)) {
            require_once $autoload;
            $loaded = true;
            return true;
        }
    }
    $loaded = false;
    return false;
}

function tp_admin_pdf_h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function tp_admin_pdf_money($v): string
{
    $n = is_numeric($v) ? (float) $v : 0.0;

    return number_format($n, 2, ',', ' ') . ' ₽';
}

function tp_admin_pdf_qty($v): string
{
    if ($v === null || $v === '') {
        return '0';
    }
    if (is_numeric($v)) {
        $f = (float) $v;
        if (abs($f - round($f)) < 1e-6) {
            return (string) (int) round($f);
        }

        return rtrim(rtrim(number_format($f, 3, ',', ''), '0'), ',');
    }

    return (string) $v;
}

/**
 * @param array<string, mixed> $r результат tp_admin_fetch_request_detail → request
 * @param array<string, string> $company tp_company_pdf_settings()
 */
function tp_admin_estimate_pdf_build_html(array $r, array $company): string
{
    $legal = (string) ($company['legal_name'] ?? '');
    $innLine = trim((string) ($company['inn_line'] ?? ''));
    if ($innLine === '') {
        $inn = (string) ($company['inn'] ?? '');
        $innLine = $inn !== '' ? ('ИНН ' . $inn) : '';
    }
    $phoneLine = trim((string) ($company['phone_line'] ?? ''));
    if ($phoneLine === '') {
        $p = (string) ($company['phone'] ?? '');
        $phoneLine = $p !== '' ? ('Тел. ' . $p) : '';
    }
    $addr = (string) ($company['address'] ?? '');
    $tag = (string) ($company['tagline'] ?? '');
    $site = (string) ($company['website'] ?? '');
    $agree = (string) ($company['user_agreement_url'] ?? '');
    $area = (string) ($company['area_note'] ?? '');

    $rid = (int) ($r['id'] ?? 0);
    $eid = (int) ($r['estimate_id'] ?? 0);
    $title = (string) ($r['estimate_title'] ?? 'Смета');
    $st = (string) ($r['status'] ?? '');
    $created = (string) ($r['created_at'] ?? '');
    $totalAmount = is_numeric($r['total_amount'] ?? null) ? (float) $r['total_amount'] : 0.0;

    $fio = trim((string) ($r['contact_name'] ?? ''));
    if ($fio === '') {
        $fio = trim(implode(' ', array_filter([
            (string) ($r['last_name'] ?? ''),
            (string) ($r['first_name'] ?? ''),
            (string) ($r['middle_name'] ?? ''),
        ])));
    }
    $phone = (string) ($r['contact_phone'] ?? $r['user_phone'] ?? '');
    $email = (string) ($r['contact_email'] ?? $r['email'] ?? '');
    $comment = trim((string) ($r['comment'] ?? ''));

    $calc = tp_admin_estimate_calculation_map($r);
    $discPct = isset($calc['estimate_discount_percent']) ? (float) $calc['estimate_discount_percent'] : 0.0;
    $discRub = isset($calc['estimate_discount_rub']) ? (float) $calc['estimate_discount_rub'] : 0.0;

    $lineSum = 0.0;
    $items = $r['items'] ?? [];
    if (!is_array($items)) {
        $items = [];
    }
    foreach ($items as $it) {
        if (!is_array($it)) {
            continue;
        }
        $lineSum += is_numeric($it['total_price'] ?? null) ? (float) $it['total_price'] : 0.0;
    }
    $showDiscount = $discPct > 0.0001 || $discRub > 0.0001
        || (abs($lineSum - $totalAmount) > 0.02 && $lineSum > 0);

    $rows = '';
    foreach ($items as $it) {
        if (!is_array($it)) {
            continue;
        }
        $name = (string) ($it['name'] ?? 'Позиция');
        $sku = trim((string) ($it['sku'] ?? ''));
        $cat = trim((string) ($it['category'] ?? ''));
        $sub = array_filter([$sku !== '' ? ('арт. ' . $sku) : '', $cat]);
        $subStr = implode(' · ', $sub);
        $qty = tp_admin_pdf_qty($it['quantity'] ?? 0);
        $unit = (string) ($it['unit'] ?? 'шт');
        $tot = tp_admin_pdf_money($it['total_price'] ?? 0);
        $rows .= '<tr>'
            . '<td>' . tp_admin_pdf_h($name) . '</td>'
            . '<td>' . tp_admin_pdf_h($subStr !== '' ? $subStr : '—') . '</td>'
            . '<td style="text-align:right;white-space:nowrap;">' . tp_admin_pdf_h($qty . ' ' . $unit) . '</td>'
            . '<td style="text-align:right;white-space:nowrap;">' . tp_admin_pdf_h($tot) . '</td>'
            . '</tr>';
    }
    if ($rows === '') {
        $rows = '<tr><td colspan="4">Нет позиций</td></tr>';
    }

    $discountHtml = '';
    if ($showDiscount) {
        $discountHtml = '<div class="block"><h2>Итоги и скидка на смету</h2>'
            . '<p>Сумма по строкам: ' . tp_admin_pdf_h(tp_admin_pdf_money($lineSum)) . '</p>';
        if ($discPct > 0.0001) {
            $discountHtml .= '<p>Скидка % на смету: ' . tp_admin_pdf_h(number_format($discPct, 2, ',', ' ')) . ' %</p>';
        }
        if ($discRub > 0.0001) {
            $discountHtml .= '<p>Скидка фикс на смету: ' . tp_admin_pdf_h(tp_admin_pdf_money($discRub)) . '</p>';
        }
        $discountHtml .= '<p><strong>Итого (total_amount): ' . tp_admin_pdf_h(tp_admin_pdf_money($totalAmount)) . '</strong></p>';
        if (abs($lineSum - $totalAmount) > 0.02 && $discPct < 0.0001 && $discRub < 0.0001) {
            $discountHtml .= '<p style="color:#a60;">Сумма строк ≠ итог, в calculation нет скидки на смету.</p>';
        }
        $discountHtml .= '</div>';
    }

    $commentHtml = '';
    if ($comment !== '') {
        $commentHtml = '<div class="block"><h2>Комментарий к заявке</h2><p style="white-space:pre-wrap;">'
            . tp_admin_pdf_h($comment) . '</p></div>';
    }

    $headMid = trim($innLine . ($innLine !== '' && $phoneLine !== '' ? '  •  ' : '') . $phoneLine);

    return '<!DOCTYPE html><html><head><meta charset="UTF-8">'
        . '<style>
body { font-family: "DejaVu Sans", sans-serif; font-size: 9pt; color: #111; }
h1 { font-size: 12pt; margin: 0 0 6px; }
h2 { font-size: 10pt; margin: 0 0 4px; }
.header { border-bottom: 1px solid #888; padding-bottom: 8px; margin-bottom: 10px; }
.small { font-size: 7.5pt; color: #444; }
.block { margin-bottom: 10px; }
table.lines { width: 100%; border-collapse: collapse; font-size: 8.5pt; }
table.lines th, table.lines td { border: 1px solid #ccc; padding: 3px 4px; vertical-align: top; }
table.lines th { background: #eee; }
</style></head><body>'
        . '<div class="header">'
        . '<div style="font-size:11pt;font-weight:bold;">' . tp_admin_pdf_h($legal) . '</div>'
        . ($tag !== '' ? '<div class="small" style="margin-top:2px;">' . tp_admin_pdf_h($tag) . '</div>' : '')
        . ($headMid !== '' ? '<div style="margin-top:6px;">' . tp_admin_pdf_h($headMid) . '</div>' : '')
        . ($addr !== '' ? '<div class="small" style="margin-top:3px;">' . tp_admin_pdf_h($addr) . '</div>' : '')
        . ($area !== '' ? '<div class="small" style="margin-top:2px;">' . tp_admin_pdf_h($area) . '</div>' : '')
        . ($site !== '' ? '<div class="small" style="margin-top:2px;">Сайт: ' . tp_admin_pdf_h($site) . '</div>' : '')
        . ($agree !== '' ? '<div class="small" style="margin-top:2px;">Пользовательское соглашение: ' . tp_admin_pdf_h($agree) . '</div>' : '')
        . '</div>'
        . '<h1>' . tp_admin_pdf_h($title) . '</h1>'
        . '<p class="small">Заявка #' . $rid . ' · смета #' . $eid . ' · статус заявки: ' . tp_admin_pdf_h($st)
        . ' · ' . tp_admin_pdf_h($created) . '</p>'
        . '<p><strong>Итого по смете:</strong> ' . tp_admin_pdf_h(tp_admin_pdf_money($totalAmount)) . '</p>'
        . '<div class="block"><h2>Контакты</h2>'
        . '<p class="small">' . tp_admin_pdf_h($fio !== '' ? $fio : '—') . '<br>'
        . 'Тел.: ' . tp_admin_pdf_h($phone !== '' ? $phone : '—') . '<br>'
        . 'Email: ' . tp_admin_pdf_h($email !== '' ? $email : '—') . '</p></div>'
        . $commentHtml
        . $discountHtml
        . '<div class="block"><h2>Позиции сметы</h2>'
        . '<table class="lines"><thead><tr>'
        . '<th>Наименование</th><th>Артикул / категория</th><th style="text-align:right;">Кол-во</th><th style="text-align:right;">Сумма</th>'
        . '</tr></thead><tbody>' . $rows . '</tbody></table></div>'
        . '<p class="small" style="margin-top:12px;">Документ сформирован в админ-интерфейсе.</p>'
        . '</body></html>';
}

/**
 * @param array<string, mixed> $r
 * @param array<string, string> $company
 */
function tp_admin_estimate_pdf_render(array $r, array $company): ?string
{
    if (!tp_admin_composer_autoload()) {
        return null;
    }
    $html = tp_admin_estimate_pdf_build_html($r, $company);
    $backendRoot = dirname(__DIR__, 2);

    $options = new \Dompdf\Options();
    $options->set('isRemoteEnabled', false);
    $options->set('defaultFont', 'DejaVu Sans');
    $options->setChroot([$backendRoot, dirname(__DIR__)]);

    $dompdf = new \Dompdf\Dompdf($options);
    $dompdf->loadHtml($html, 'UTF-8');
    $dompdf->setPaper('A4', 'portrait');
    $dompdf->render();

    return $dompdf->output();
}
