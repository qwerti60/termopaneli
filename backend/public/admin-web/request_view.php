<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_requests_service.php');
tp_admin_web_require_include('admin_estimate_calc.php');

$pdo = tp_admin_web_require_login();

$requestId = (int) ($_GET['id'] ?? 0);
$returnStatus = trim((string) ($_GET['return_status'] ?? ''));
if ($returnStatus !== '' && !in_array($returnStatus, tp_admin_allowed_request_statuses(), true)) {
    $returnStatus = '';
}

$detail = tp_admin_fetch_request_detail($pdo, $requestId);
if ($detail['ok'] !== true) {
    http_response_code($requestId > 0 ? 404 : 400);
    header('Content-Type: text/plain; charset=utf-8');
    echo $detail['message'];
    exit;
}

$r = $detail['request'];

$backQs = [];
if ($returnStatus !== '') {
    $backQs['status'] = $returnStatus;
}
$backHref = 'requests.php' . ($backQs !== [] ? ('?' . http_build_query($backQs)) : '');

function tp_admin_web_money_web($v): string
{
    $n = is_numeric($v) ? (float) $v : 0.0;
    return number_format($n, 2, ',', ' ') . ' ₽';
}

function tp_admin_web_qty_web($v): string
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

$statusLabels = [
    'new' => 'Новая',
    'in_work' => 'В работе',
    'need_info' => 'Нужна информация',
    'done' => 'Выполнена',
    'closed' => 'Закрыта',
    'cancelled' => 'Отменена',
];

$calc = tp_admin_estimate_calculation_map($r);
$discPct = isset($calc['estimate_discount_percent']) ? (float) $calc['estimate_discount_percent'] : 0.0;
$discRub = isset($calc['estimate_discount_rub']) ? (float) $calc['estimate_discount_rub'] : 0.0;

$lineSum = 0.0;
foreach ($r['items'] as $it) {
    $lineSum += is_numeric($it['total_price'] ?? null) ? (float) $it['total_price'] : 0.0;
}
$totalAmount = is_numeric($r['total_amount'] ?? null) ? (float) $r['total_amount'] : 0.0;
$showDiscountBlock = $discPct > 0.0001 || $discRub > 0.0001
    || (abs($lineSum - $totalAmount) > 0.02 && $lineSum > 0);

$fio = trim((string) ($r['contact_name'] ?? ''));
if ($fio === '') {
    $fio = trim(implode(' ', array_filter([
        (string) ($r['last_name'] ?? ''),
        (string) ($r['first_name'] ?? ''),
        (string) ($r['middle_name'] ?? ''),
    ])));
}

$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');
$pageTitle = 'Заявка #' . (int) $r['id'] . ' · смета #' . (int) $r['estimate_id'];
tp_admin_web_layout_start($pageTitle, 'requests', $adminLogin !== '' ? $adminLogin : null);
?>
    <div class="toolbar">
        <a class="btn" href="request_pdf.php?id=<?= (int) $r['id'] ?>">Скачать PDF</a>
        <a class="btn secondary" href="<?= tp_admin_web_h($backHref) ?>">← К списку заявок</a>
    </div>

    <div class="card">
        <h2><?= tp_admin_web_h((string) ($r['estimate_title'] ?? 'Смета')) ?></h2>
        <p class="meta">
            Статус заявки: <strong><?= tp_admin_web_h($statusLabels[(string) $r['status']] ?? (string) $r['status']) ?></strong>
            · создана <?= tp_admin_web_h((string) ($r['created_at'] ?? '')) ?>
        </p>
        <p class="meta">Итого по смете (total_amount): <strong><?= tp_admin_web_h(tp_admin_web_money_web($totalAmount)) ?></strong></p>
    </div>

    <div class="card">
        <h2>Контакты</h2>
        <p class="meta"><?= tp_admin_web_h($fio !== '' ? $fio : '—') ?></p>
        <p class="meta">Тел.: <?= tp_admin_web_h((string) ($r['contact_phone'] ?? $r['user_phone'] ?? '—')) ?></p>
        <p class="meta">Email: <?= tp_admin_web_h((string) ($r['contact_email'] ?? $r['email'] ?? '—')) ?></p>
        <?php
        $comment = trim((string) ($r['comment'] ?? ''));
        if ($comment !== '') {
            ?>
            <h2 style="margin-top:1rem;">Комментарий к заявке</h2>
            <p class="comment"><?= nl2br(tp_admin_web_h($comment), false) ?></p>
            <?php
        }
        ?>
    </div>

    <?php if ($showDiscountBlock) { ?>
    <div class="card">
        <h2>Итоги и скидка на смету</h2>
        <p class="meta">Сумма по строкам: <?= tp_admin_web_h(tp_admin_web_money_web($lineSum)) ?></p>
        <?php if ($discPct > 0.0001) { ?>
            <p class="meta">Скидка % на смету: <?= tp_admin_web_h(number_format($discPct, 2, ',', ' ')) ?> %</p>
        <?php } ?>
        <?php if ($discRub > 0.0001) { ?>
            <p class="meta">Скидка фикс на смету: <?= tp_admin_web_h(tp_admin_web_money_web($discRub)) ?></p>
        <?php } ?>
        <p class="meta"><strong>Итого (total_amount): <?= tp_admin_web_h(tp_admin_web_money_web($totalAmount)) ?></strong></p>
        <?php
        if (abs($lineSum - $totalAmount) > 0.02 && $discPct < 0.0001 && $discRub < 0.0001) {
            echo '<p class="meta" style="color:#b45309;">Сумма строк ≠ итог, в calculation нет скидки на смету — проверьте данные.</p>';
        }
        ?>
    </div>
    <?php } ?>

    <div class="card">
        <h2>Позиции сметы</h2>
        <table class="lines">
            <thead>
                <tr>
                    <th>Наименование</th>
                    <th>Артикул / категория</th>
                    <th class="num">Кол-во</th>
                    <th class="num">Сумма</th>
                </tr>
            </thead>
            <tbody>
                <?php if (count($r['items']) === 0) { ?>
                    <tr><td colspan="4">Нет позиций</td></tr>
                <?php } ?>
                <?php foreach ($r['items'] as $it) {
                    $name = (string) ($it['name'] ?? 'Позиция');
                    $sku = trim((string) ($it['sku'] ?? ''));
                    $cat = trim((string) ($it['category'] ?? ''));
                    $sub = array_filter([$sku !== '' ? 'арт. ' . $sku : '', $cat]);
                    $subStr = implode(' · ', $sub);
                    ?>
                    <tr>
                        <td><?= tp_admin_web_h($name) ?></td>
                        <td class="meta"><?= $subStr !== '' ? tp_admin_web_h($subStr) : '—' ?></td>
                        <td class="num"><?= tp_admin_web_h(tp_admin_web_qty_web($it['quantity'] ?? 0)) ?> <?= tp_admin_web_h((string) ($it['unit'] ?? 'шт')) ?></td>
                        <td class="num"><?= tp_admin_web_h(tp_admin_web_money_web($it['total_price'] ?? 0)) ?></td>
                    </tr>
                <?php } ?>
            </tbody>
        </table>
    </div>
<?php
tp_admin_web_layout_end();
