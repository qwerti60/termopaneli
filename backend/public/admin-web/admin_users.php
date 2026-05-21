<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_users.php');

$pdo = tp_admin_web_require_login();

$limit = 300;
if (isset($_GET['limit'])) {
    $limit = (int) $_GET['limit'];
}

$rows = [];
$tableErr = '';
$flashOk = isset($_GET['ok']);
$flashErr = trim((string) ($_GET['err'] ?? ''));
try {
    $rows = tp_admin_users_list($pdo, $limit);
} catch (Throwable $e) {
    error_log('admin_users: ' . $e->getMessage());
    $tableErr = 'Не удалось загрузить список (проверьте схему user_profiles).';
}

$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Пользователи', 'users', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($flashOk) { ?>
    <p class="ok">Статус пользователя обновлён.</p>
<?php } ?>
<?php if ($flashErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($flashErr) ?></p>
<?php } ?>
<?php if ($tableErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($tableErr) ?></p>
<?php } ?>
<p class="meta">Пользователи мобильного приложения (<code>user_profiles</code>). Показано до <?= (int) min(500, max(1, $limit)) ?> записей; сортировка по убыванию <code>id</code> — новые сверху.</p>
<table class="data">
    <thead>
        <tr>
            <th class="num">ID</th>
            <th>Телефон</th>
            <th>ФИО</th>
            <th>Email</th>
            <th>PRO</th>
            <th>Блок</th>
            <th class="num">Смет</th>
            <th>Создан</th>
            <th>Токен обновлён</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0 && $tableErr === '') { ?>
            <tr><td colspan="10">Нет пользователей</td></tr>
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
            $isBlocked = !empty($r['is_blocked']);
            $ec = (int) ($r['estimates_count'] ?? 0);
            $created = (string) ($r['created_at'] ?? '');
            $tokUp = (string) ($r['token_updated_at'] ?? '');
            ?>
            <tr>
                <td class="num"><?= $uid ?></td>
                <td><?= tp_admin_web_h($phone) ?></td>
                <td><?= tp_admin_web_h($fio !== '' ? $fio : '—') ?></td>
                <td><?= tp_admin_web_h($email) ?></td>
                <td><?= $isPro ? 'да' : 'нет' ?></td>
                <td><?= $isBlocked ? '<span class="err">да</span>' : 'нет' ?></td>
                <td class="num"><?= $ec ?></td>
                <td class="meta"><?= tp_admin_web_h($created) ?></td>
                <td class="meta"><?= tp_admin_web_h($tokUp !== '' ? $tokUp : '—') ?></td>
                <td>
                    <form method="post" action="admin_user_toggle.php" style="display:inline" onsubmit="return confirm('<?= $isBlocked ? 'Разблокировать' : 'Заблокировать' ?> пользователя #<?= $uid ?>?');">
                        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
                        <input type="hidden" name="id" value="<?= $uid ?>">
                        <input type="hidden" name="blocked" value="<?= $isBlocked ? '0' : '1' ?>">
                        <button type="submit" name="toggle_user_blocked" value="1" class="btn secondary small"><?= $isBlocked ? 'Разблокировать' : 'Заблокировать' ?></button>
                    </form>
                </td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php
tp_admin_web_layout_end();
