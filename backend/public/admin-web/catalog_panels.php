<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_panels.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$perPage = (int) ($_GET['per'] ?? 50);
if ($perPage < 10) {
    $perPage = 10;
}
if ($perPage > 200) {
    $perPage = 200;
}
$page = max(1, (int) ($_GET['page'] ?? 1));
$offset = ($page - 1) * $perPage;

$listErr = null;
$rows = [];
$total = 0;
try {
    $list = tp_admin_panel_catalog_list($pdo, $offset, $perPage);
    if (isset($list['error'])) {
        $listErr = (string) $list['error'];
    } else {
        $rows = $list['rows'];
        $total = $list['total'];
    }
} catch (Throwable $e) {
    $listErr = 'Ошибка чтения thermo_panel_catalog.';
}

$pages = $perPage > 0 ? (int) ceil($total / $perPage) : 1;
if ($pages < 1) {
    $pages = 1;
}
if ($page > $pages && $total > 0) {
    $q = $_GET;
    $q['page'] = (string) $pages;
    header('Location: catalog_panels.php?' . http_build_query($q), true, 302);
    exit;
}

tp_admin_web_layout_start('Каталог панелей', 'panels', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($listErr !== null) { ?>
    <p class="err"><?= tp_admin_web_h($listErr) ?></p>
<?php } ?>
<p class="filters">
    <a class="btn" href="catalog_panel_new.php">+ Новая панель</a>
</p>
<div class="filters">
    <span class="meta">На странице:</span>
    <?php foreach ([25, 50, 100] as $n) {
        $href = 'catalog_panels.php?' . http_build_query(array_filter([
            'per' => (string) $n,
            'page' => '1',
        ]));
        ?>
        <a class="btn secondary small" href="<?= tp_admin_web_h($href) ?>" style="<?= $perPage === $n ? 'outline:2px solid #0369a1' : '' ?>"><?= $n ?></a>
    <?php } ?>
</div>
<p class="meta">Всего позиций: <strong><?= (int) $total ?></strong><?php if ($pages > 1) { ?> · страница <?= (int) $page ?> из <?= (int) $pages ?><?php } ?></p>
<table class="data">
    <thead>
        <tr>
            <th>ID</th>
            <th>Артикул / код</th>
            <th>Наименование</th>
            <th>Картинка</th>
            <th class="num">Цена (как в БД)</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0 && $listErr === null) { ?>
            <tr><td colspan="6">Нет записей</td></tr>
        <?php } ?>
        <?php foreach ($rows as $r) {
            $id = (int) ($r['id'] ?? 0);
            $title = tp_admin_panel_catalog_row_title($r);
            $sku = tp_admin_panel_catalog_row_sku($r);
            $price = tp_admin_panel_catalog_row_price($r);
            $img = tp_admin_panel_catalog_row_image($r);
            ?>
            <tr>
                <td class="num"><?= $id ?></td>
                <td><code><?= tp_admin_web_h($sku) ?></code></td>
                <td><?= tp_admin_web_h($title) ?></td>
                <td><?php if ($img !== '') { ?><img class="thumb-preview" src="<?= tp_admin_web_h(tp_admin_web_public_href($img)) ?>" alt=""><?php } else { ?><span class="meta">—</span><?php } ?></td>
                <td class="num"><?= tp_admin_web_h($price) ?></td>
                <td class="row-actions">
                    <a class="btn small" href="catalog_panel_edit.php?id=<?= $id ?>">Изменить</a>
                    <form method="post" action="catalog_panel_delete.php" style="display:inline" onsubmit="return confirm('Удалить позицию #<?= $id ?>?');">
                        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
                        <input type="hidden" name="id" value="<?= $id ?>">
                        <button type="submit" name="delete_panel" value="1" class="btn secondary small">Удалить</button>
                    </form>
                </td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php if ($pages > 1 && $listErr === null) {
    $baseQ = array_filter(['per' => $perPage !== 50 ? (string) $perPage : null]);
    ?>
    <p class="filters" style="margin-top:1rem">
        <?php if ($page > 1) {
            $baseQ['page'] = (string) ($page - 1);
            ?>
            <a class="btn secondary small" href="catalog_panels.php?<?= tp_admin_web_h(http_build_query($baseQ)) ?>">← Назад</a>
        <?php }
        if ($page < $pages) {
            $baseQ['page'] = (string) ($page + 1);
            ?>
            <a class="btn secondary small" href="catalog_panels.php?<?= tp_admin_web_h(http_build_query($baseQ)) ?>">Вперёд →</a>
        <?php } ?>
    </p>
<?php } ?>
<p class="meta" style="margin-top:1rem;">Источник API: таблица <code>thermo_panel_catalog</code> (<code>GET …/catalog/list.php?category=panel</code>).</p>
<?php
tp_admin_web_layout_end();
