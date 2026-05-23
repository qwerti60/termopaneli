<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_subscriptions.php');

$pdo = tp_admin_web_require_login();

$limit = 300;
if (isset($_GET['limit'])) {
    $limit = (int) $_GET['limit'];
}

$rows = [];
$tableErr = '';
try {
    $rows = tp_admin_subscribers_list($pdo, $limit);
} catch (Throwable $e) {
    error_log('admin_subscribers: ' . $e->getMessage());
    $tableErr = 'Не удалось загрузить список. Выполните на БД миграцию backend/sql/migrate_user_subscriptions.sql';
}

$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Подписчики', 'subscriptions', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($tableErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($tableErr) ?></p>
<?php } ?>
<p class="meta">Пользователи с флагом <strong>PRO</strong> (<code>is_pro</code>) или с активной строкой в <code>user_subscriptions</code> (не просрочена). Оплата в приложении пока заглушка — события смотрите в <a href="admin_subscription_events.php">журнале оплат и подписок</a>.</p>
<div class="toolbar">
    <a class="btn secondary" href="subscriptions.php">← Подписки PRO</a>
    <a class="btn secondary" href="admin_subscription_events.php">Журнал оплат и подписок</a>
</div>
<table class="data">
    <thead>
        <tr>
            <th class="num">User ID</th>
            <th>Телефон</th>
            <th>ФИО</th>
            <th>Email</th>
            <th>is_pro</th>
            <th>Подписка ID</th>
            <th>Тариф</th>
            <th>До</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0 && $tableErr === '') { ?>
            <tr><td colspan="9">Нет подписчиков (активных подписок)</td></tr>
        <?php } ?>
        <?php foreach ($rows as $r) {
            $uid = (int) $r['id'];
            $phone = (string) ($r['phone'] ?? '');
            $fio = trim(implode(' ', array_filter([
                (string) ($r['last_name'] ?? ''),
                (string) ($r['first_name'] ?? ''),
                (string) ($r['middle_name'] ?? ''),
            ])));
            $email = (string) ($r['email'] ?? '');
            $isPro = !empty($r['is_pro']);
            $sid = isset($r['subscription_id']) ? (int) $r['subscription_id'] : 0;
            $plan = (string) ($r['plan_code'] ?? '');
            $exp = (string) ($r['expires_at'] ?? '');
            ?>
            <tr>
                <td class="num"><?= $uid ?></td>
                <td><?= tp_admin_web_h($phone) ?></td>
                <td><?= tp_admin_web_h($fio !== '' ? $fio : '—') ?></td>
                <td><?= tp_admin_web_h($email) ?></td>
                <td><?= $isPro ? '1' : '0' ?></td>
                <td class="num"><?= $sid > 0 ? $sid : '—' ?></td>
                <td><?= tp_admin_web_h($plan !== '' ? $plan : '—') ?></td>
                <td class="meta"><?= tp_admin_web_h($exp !== '' ? $exp : '—') ?></td>
                <td><a class="btn small secondary" href="admin_subscription_events.php?user_id=<?= $uid ?>">События</a></td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php
tp_admin_web_layout_end();
