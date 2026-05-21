<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_requests_service.php');
tp_admin_web_require_include('admin_audit_log.php');

$pdo = tp_admin_web_require_login();

$flashError = '';

$statusLabels = [
    'new' => 'Новая',
    'in_work' => 'В работе',
    'need_info' => 'Нужна информация',
    'done' => 'Выполнена',
    'closed' => 'Закрыта',
    'cancelled' => 'Отменена',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['set_status'])) {
    $rid = (int) ($_POST['request_id'] ?? 0);
    $newSt = trim((string) ($_POST['status'] ?? ''));
    $upd = tp_admin_update_request_status($pdo, $rid, $newSt);
    if ($upd === true) {
        tp_admin_audit_log_write(
            $pdo,
            'request_status',
            'estimate_request',
            $rid > 0 ? $rid : null,
            'status=' . $newSt
        );
        $preserve = trim((string) ($_POST['filter_status'] ?? ''));
        $q = [];
        if ($preserve !== '') {
            $q['status'] = $preserve;
        }
        header('Location: requests.php' . ($q ? ('?' . http_build_query($q)) : ''), true, 303);
        exit;
    }
    $flashError = is_string($upd) ? $upd : 'Не удалось сохранить статус';
}

$filter = trim((string) ($_GET['status'] ?? ''));
$limit = tp_admin_normalize_request_limit($_GET['limit'] ?? 100);
$result = tp_admin_fetch_requests_list($pdo, $filter, $limit);
if ($result['ok'] !== true) {
    http_response_code(400);
    header('Content-Type: text/plain; charset=utf-8');
    echo $result['message'];
    exit;
}
$items = $result['items'];
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Заявки и сметы', 'requests', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if (!empty($flashError)) { ?>
    <p class="err"><?= tp_admin_web_h($flashError) ?></p>
<?php } ?>
<div class="filters">
    <span class="meta">Фильтр:</span>
    <a class="btn secondary small" href="requests.php" style="<?= $filter === '' ? 'outline:2px solid #0369a1' : '' ?>">Все</a>
    <?php foreach (tp_admin_allowed_request_statuses() as $st) { ?>
        <a class="btn secondary small" href="?status=<?= tp_admin_web_h($st) ?>" style="<?= $filter === $st ? 'outline:2px solid #0369a1' : '' ?>"><?= tp_admin_web_h($statusLabels[$st] ?? $st) ?></a>
    <?php } ?>
</div>
<table class="data">
    <thead>
        <tr>
            <th>ID</th>
            <th>Статус</th>
            <th>Смета / сумма</th>
            <th>Контакт</th>
            <th>Дата</th>
            <th>Сменить на</th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($items) === 0) { ?>
            <tr><td colspan="6">Нет заявок</td></tr>
        <?php } ?>
        <?php foreach ($items as $row) {
            $rid = (int) $row['id'];
            $cur = (string) $row['status'];
            $title = (string) ($row['estimate_title'] ?? '');
            $sum = $row['total_amount'] ?? '';
            $phone = (string) ($row['contact_phone'] ?? $row['user_phone'] ?? '');
            $name = trim((string) ($row['contact_name'] ?? '') ?: trim(implode(' ', array_filter([
                (string) ($row['last_name'] ?? ''),
                (string) ($row['first_name'] ?? ''),
                (string) ($row['middle_name'] ?? ''),
            ]))));
            $created = (string) ($row['created_at'] ?? '');
            $viewHref = 'request_view.php?id=' . $rid;
            if ($filter !== '') {
                $viewHref .= '&return_status=' . rawurlencode($filter);
            }
            ?>
            <tr>
                <td class="num"><?= $rid ?></td>
                <td><?= tp_admin_web_h($statusLabels[$cur] ?? $cur) ?></td>
                <td><?= tp_admin_web_h($title) ?><br><span class="meta"><?= tp_admin_web_h((string) $sum) ?> ₽</span><br><a class="btn small" style="margin-top:0.4rem" href="<?= tp_admin_web_h($viewHref) ?>">Просмотр сметы</a></td>
                <td><?= tp_admin_web_h($name) ?><br><span class="meta"><?= tp_admin_web_h($phone) ?></span></td>
                <td class="meta"><?= tp_admin_web_h($created) ?></td>
                <td>
                    <form method="post" action="">
                        <input type="hidden" name="set_status" value="1">
                        <input type="hidden" name="request_id" value="<?= $rid ?>">
                        <?php if ($filter !== '') { ?><input type="hidden" name="filter_status" value="<?= tp_admin_web_h($filter) ?>"><?php } ?>
                        <select name="status" class="in" style="max-width:10rem;display:inline-block;width:auto" aria-label="Новый статус">
                            <?php foreach (tp_admin_allowed_request_statuses() as $st) { ?>
                                <option value="<?= tp_admin_web_h($st) ?>" <?= $st === $cur ? 'selected' : '' ?>><?= tp_admin_web_h($statusLabels[$st] ?? $st) ?></option>
                            <?php } ?>
                        </select>
                        <button type="submit" class="btn small">OK</button>
                    </form>
                </td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<p class="meta" style="margin-top:1rem;">Показано до <?= (int) $limit ?> записей. API: <code>admin/requests/list.php</code></p>
<?php
tp_admin_web_layout_end();
