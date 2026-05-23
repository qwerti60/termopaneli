<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_subscriptions.php');

$pdo = tp_admin_web_require_login();

$limit = 400;
if (isset($_GET['limit'])) {
    $limit = (int) $_GET['limit'];
}
$userFilter = isset($_GET['user_id']) ? (int) $_GET['user_id'] : 0;

$rows = [];
$tableErr = '';
try {
    $rows = tp_admin_subscription_events_list($pdo, $limit, $userFilter);
} catch (Throwable $e) {
    error_log('admin_subscription_events: ' . $e->getMessage());
    $tableErr = 'Не удалось загрузить журнал. Выполните миграцию backend/sql/migrate_user_subscriptions.sql';
}

$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Журнал оплат и подписок', 'subscriptions', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($tableErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($tableErr) ?></p>
<?php } ?>
<p class="meta">События: оформление PRO без эквайринга (<code>activated_no_acquiring</code>), отмена подписки (<code>subscription_cancelled</code>) и др. Фильтр по пользователю: <code>?user_id=</code></p>
<div class="toolbar">
    <a class="btn secondary" href="subscriptions.php">← Подписки PRO</a>
    <a class="btn secondary" href="admin_subscribers.php">Подписчики</a>
    <?php if ($userFilter > 0) { ?>
        <a class="btn secondary" href="admin_subscription_events.php">Все события</a>
        <span class="meta">фильтр user_id=<?= (int) $userFilter ?></span>
    <?php } ?>
</div>
<table class="data">
    <thead>
        <tr>
            <th class="num">ID</th>
            <th class="num">User</th>
            <th>Телефон / имя</th>
            <th>Тариф</th>
            <th class="num">Сумма ₽</th>
            <th>Тип</th>
            <th>Деталь</th>
            <th>Когда (UTC)</th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0 && $tableErr === '') { ?>
            <tr><td colspan="8">Нет записей</td></tr>
        <?php } ?>
        <?php foreach ($rows as $r) {
            $eid = (int) ($r['id'] ?? 0);
            $uid = (int) ($r['user_id'] ?? 0);
            $phone = (string) ($r['phone'] ?? '');
            $nm = trim((string) ($r['last_name'] ?? '') . ' ' . (string) ($r['first_name'] ?? ''));
            $plan = (string) ($r['plan_code'] ?? '');
            $amt = (string) ($r['amount_rub'] ?? '');
            $ev = (string) ($r['event_type'] ?? '');
            $det = (string) ($r['detail'] ?? '');
            $cr = (string) ($r['created_at'] ?? '');
            ?>
            <tr>
                <td class="num"><?= $eid ?></td>
                <td class="num"><?= $uid ?></td>
                <td><?= tp_admin_web_h($phone) ?><br><span class="meta"><?= tp_admin_web_h($nm !== '' ? $nm : '—') ?></span></td>
                <td><?= tp_admin_web_h($plan !== '' ? $plan : '—') ?></td>
                <td class="num"><?= tp_admin_web_h($amt) ?></td>
                <td><code><?= tp_admin_web_h($ev) ?></code></td>
                <td class="comment"><?= tp_admin_web_h($det !== '' ? $det : '—') ?></td>
                <td class="meta"><?= tp_admin_web_h($cr) ?></td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php
tp_admin_web_layout_end();
