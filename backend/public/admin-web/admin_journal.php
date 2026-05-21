<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_audit_log.php');

$pdo = tp_admin_web_require_login();

$limit = 200;
if (isset($_GET['limit'])) {
    $limit = (int) $_GET['limit'];
}

$rows = [];
$migrateHint = false;
try {
    $rows = tp_admin_audit_log_list($pdo, $limit);
} catch (Throwable $e) {
    error_log('admin_journal: ' . $e->getMessage());
    $migrateHint = true;
}

$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Журнал действий', 'journal', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($migrateHint) { ?>
    <p class="err">Таблица журнала не найдена. Выполните на БД миграцию <code>backend/sql/migrate_admin_audit_log.sql</code> (или подключите <code>schema_admin_audit_log.sql</code> при новой установке).</p>
<?php } ?>
<p class="meta">События входа/выхода, смена статуса заявки, удаление сметы и позиций каталога. Показано до <?= (int) min(500, max(1, $limit)) ?> последних записей.</p>
<table class="data">
    <thead>
        <tr>
            <th class="num">ID</th>
            <th>Время</th>
            <th>Админ</th>
            <th>Действие</th>
            <th>Объект</th>
            <th>IP</th>
            <th>Детали</th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0 && !$migrateHint) { ?>
            <tr><td colspan="7">Записей пока нет — выполните действия в админке или миграцию таблицы.</td></tr>
        <?php } ?>
        <?php foreach ($rows as $r) {
            $rawId = $r['target_id'] ?? null;
            $tt = (string) ($r['target_type'] ?? '');
            $obj = $tt !== ''
                ? $tt . (($rawId !== null && $rawId !== '') ? ' #' . (int) $rawId : '')
                : '—';
            ?>
            <tr>
                <td class="num"><?= (int) $r['id'] ?></td>
                <td class="meta"><?= tp_admin_web_h((string) ($r['created_at'] ?? '')) ?></td>
                <td><?= tp_admin_web_h((string) ($r['admin_login'] ?? '')) ?></td>
                <td><code><?= tp_admin_web_h((string) ($r['action'] ?? '')) ?></code></td>
                <td><?= tp_admin_web_h($obj) ?></td>
                <td class="meta"><?= tp_admin_web_h((string) ($r['ip'] ?? '')) ?></td>
                <td class="comment meta"><?= tp_admin_web_h((string) ($r['detail'] ?? '')) ?></td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php
tp_admin_web_layout_end();
