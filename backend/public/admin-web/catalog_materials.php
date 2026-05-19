<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_materials.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$categories = tp_admin_catalog_material_categories();
$cat = trim((string) ($_GET['cat'] ?? 'all'));
if (!array_key_exists($cat, $categories)) {
    $cat = 'all';
}

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
    $list = tp_admin_catalog_materials_list($pdo, $cat, $offset, $perPage);
    if (isset($list['error'])) {
        $listErr = (string) $list['error'];
    } else {
        $rows = $list['rows'];
        $total = $list['total'];
    }
} catch (Throwable $e) {
    $listErr = 'Таблица catalog_materials недоступна или не создана. Выполните миграцию SQL из backend/sql/.';
}

$pages = $perPage > 0 ? (int) ceil($total / $perPage) : 1;
if ($pages < 1) {
    $pages = 1;
}
if ($page > $pages && $total > 0) {
    $q = $_GET;
    $q['page'] = (string) $pages;
    header('Location: catalog_materials.php?' . http_build_query($q), true, 302);
    exit;
}

tp_admin_web_layout_start('Каталог материалов', 'materials', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($listErr !== null) { ?>
    <p class="err"><?= tp_admin_web_h($listErr) ?></p>
<?php } ?>
<p class="filters">
    <a class="btn" href="catalog_material_new.php">+ Новая позиция</a>
</p>
<div class="filters">
    <span class="meta">Категория:</span>
    <?php foreach ($categories as $slug => $label) {
        $active = $slug === $cat;
        $href = 'catalog_materials.php?' . http_build_query(array_filter([
            'cat' => $slug === 'all' ? null : $slug,
            'per' => $perPage !== 50 ? (string) $perPage : null,
        ]));
        ?>
        <a class="btn secondary small" href="<?= tp_admin_web_h($href) ?>" style="<?= $active ? 'outline:2px solid #0369a1' : '' ?>"><?= tp_admin_web_h($label) ?></a>
    <?php } ?>
    <span class="meta" style="margin-left:0.5rem">На странице:</span>
    <?php foreach ([25, 50, 100] as $n) {
        $href = 'catalog_materials.php?' . http_build_query(array_filter([
            'cat' => $cat === 'all' ? null : $cat,
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
            <th>SKU</th>
            <th>Кат.</th>
            <th>Название</th>
            <th>Фото</th>
            <th class="num">Цена</th>
            <th>Ед.</th>
            <th>Активен</th>
            <th></th>
        </tr>
    </thead>
    <tbody>
        <?php if (count($rows) === 0 && $listErr === null) { ?>
            <tr><td colspan="9">Нет записей</td></tr>
        <?php } ?>
        <?php foreach ($rows as $r) {
            $id = (int) ($r['id'] ?? 0);
            $sku = (string) ($r['sku'] ?? '');
            $rcat = (string) ($r['category'] ?? '');
            $name = (string) ($r['name'] ?? '');
            $price = $r['price'] ?? '';
            $unit = (string) ($r['unit'] ?? '');
            $active = (int) ($r['is_active'] ?? 0) === 1;
            $edit = 'catalog_edit.php?id=' . $id;
            $img = trim((string) ($r['image_path'] ?? ''));
            ?>
            <tr>
                <td class="num"><?= $id ?></td>
                <td><code><?= tp_admin_web_h($sku) ?></code></td>
                <td class="meta"><?= tp_admin_web_h($rcat) ?></td>
                <td><?= tp_admin_web_h($name) ?></td>
                <td><?php if ($img !== '') { ?><img class="thumb-preview" src="<?= tp_admin_web_h(tp_admin_web_public_href($img)) ?>" alt=""><?php } else { ?><span class="meta">—</span><?php } ?></td>
                <td class="num"><?= tp_admin_web_h((string) $price) ?></td>
                <td class="meta"><?= tp_admin_web_h($unit) ?></td>
                <td><?= $active ? 'да' : '<span class="meta">нет</span>' ?></td>
                <td class="row-actions">
                    <a class="btn small" href="<?= tp_admin_web_h($edit) ?>">Изменить</a>
                    <form method="post" action="catalog_material_delete.php" style="display:inline" onsubmit="return confirm('Удалить <?= tp_admin_web_h($sku) ?>?');">
                        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
                        <input type="hidden" name="id" value="<?= $id ?>">
                        <button type="submit" name="delete_material" value="1" class="btn secondary small">Удалить</button>
                    </form>
                </td>
            </tr>
        <?php } ?>
    </tbody>
</table>
<?php if ($pages > 1 && $listErr === null) {
    $baseQ = array_filter(['cat' => $cat === 'all' ? null : $cat, 'per' => $perPage !== 50 ? (string) $perPage : null]);
    ?>
    <p class="filters" style="margin-top:1rem">
        <?php if ($page > 1) {
            $baseQ['page'] = (string) ($page - 1);
            ?>
            <a class="btn secondary small" href="catalog_materials.php?<?= tp_admin_web_h(http_build_query($baseQ)) ?>">← Назад</a>
        <?php }
        if ($page < $pages) {
            $baseQ['page'] = (string) ($page + 1);
            ?>
            <a class="btn secondary small" href="catalog_materials.php?<?= tp_admin_web_h(http_build_query($baseQ)) ?>">Вперёд →</a>
        <?php } ?>
    </p>
<?php } ?>
<?php
tp_admin_web_layout_end();
