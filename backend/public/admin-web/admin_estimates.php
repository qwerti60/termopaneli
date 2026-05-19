<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_estimates.php');

$pdo = tp_admin_web_require_login();

$limit = 300;
if (isset($_GET['limit'])) {
    $limit = (int) $_GET['limit'];
}

$rows = tp_admin_estimates_list($pdo, $limit);
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$flashOk = isset($_GET['ok']);
$flashErr = trim((string) ($_GET['err'] ?? ''));

tp_admin_web_layout_start('Сметы пользователей', 'estimates', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($flashOk) { ?>
    <p class="ok">Смета удалена.</p>
<?php } ?>
<?php if ($flashErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($flashErr) ?></p>
<?php } ?>
<p class="meta">Показано до <?= (int) min(500, max(1, $limit)) ?> записей (новые сверху). Удаление сметы убирает строки позиций и связанные заявки (каскад в БД).</p>
<table class="data">
    <thead>
        <tr>
            <th>ID</th>
            <th>Пользователь</th>
            <th>Название</th>
            <th>Статус</th>
            <th class="num">Сумма</th>
            <th>Обновлено</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0) { ?>
            <tr><td colspan="7">Нет сохранённых смет</td></tr>
        <?php } ?>
        <?php foreach ($rows as $row) {
            $eid = (int) $row['id'];
            $uid = (int) $row['user_id'];
            $title = (string) ($row['title'] ?? '');
            $status = (string) ($row['status'] ?? '');
            $sum = $row['total_amount'] ?? '';
            $updated = (string) ($row['updated_at'] ?? '');
            $phone = (string) ($row['user_phone'] ?? '');
            $fio = trim((string) ($row['user_fio'] ?? ''));
            $who = $fio !== '' ? $fio : ('id ' . $uid);
            if ($phone !== '') {
                $who .= ' • ' . $phone;
            }
            ?>
            <tr>
                <td><?= $eid ?></td>
                <td><?= tp_admin_web_h($who) ?></td>
                <td><?= tp_admin_web_h($title) ?></td>
                <td><?= tp_admin_web_h($status) ?></td>
                <td class="num"><?= tp_admin_web_h((string) $sum) ?></td>
                <td><?= tp_admin_web_h($updated) ?></td>
                <td>
                    <form method="post" action="admin_estimate_delete.php" style="display:inline" onsubmit="return confirm('Удалить смету #<?= $eid ?>? Связанная заявка (если была) тоже исчезнет.');">
                        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
                        <input type="hidden" name="id" value="<?= $eid ?>">
                        <button type="submit" name="delete_estimate" value="1" class="btn secondary small">Удалить</button>
                    </form>
                </td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php
tp_admin_web_layout_end();
