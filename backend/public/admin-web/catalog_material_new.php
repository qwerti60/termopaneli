<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_materials.php');
tp_admin_web_require_include('admin_catalog_media.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$flashErr = '';
$vals = [
    'sku' => '',
    'category' => 'slope',
    'name' => '',
    'description' => '',
    'material' => '',
    'color' => '',
    'texture' => '',
    'thickness_mm' => '',
    'width_mm' => '',
    'length_mm' => '',
    'package_qty' => '',
    'unit' => 'шт',
    'price' => '0',
    'image_path' => '',
    'sort_order' => '100',
    'is_active' => '1',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_material'])) {
    $post = [];
    foreach ($_POST as $k => $v) {
        if ($k === 'create_material' || $k === 'image_clear') {
            continue;
        }
        $post[(string) $k] = is_array($v) ? '' : (string) $v;
    }
    foreach ($vals as $k => $_) {
        if (isset($post[$k])) {
            $vals[$k] = $post[$k];
        }
    }

    if (!empty($_FILES['image_upload']['tmp_name']) && is_uploaded_file((string) $_FILES['image_upload']['tmp_name'])) {
        $up = tp_admin_catalog_upload_save_image($_FILES['image_upload'], 'materials');
        if ($up['ok'] !== true) {
            $flashErr = (string) ($up['error'] ?? 'Ошибка загрузки');
        } else {
            $post['image_path'] = (string) $up['relative_path'];
        }
    } elseif (isset($_POST['image_clear']) && (string) $_POST['image_clear'] === '1') {
        $post['image_path'] = '';
    }

    if ($flashErr === '') {
        $ins = tp_admin_catalog_material_insert($pdo, $post);
        if (($ins['ok'] ?? false) === true) {
            header('Location: catalog_edit.php?id=' . (int) $ins['id'], true, 303);
            exit;
        }
        $flashErr = (string) ($ins['error'] ?? 'Не удалось создать');
    }
}

$cats = tp_admin_catalog_material_categories();
unset($cats['all']);

tp_admin_web_layout_start('Новая позиция (материал)', 'materials', $adminLogin !== '' ? $adminLogin : null);
?>
<p><a class="btn secondary small" href="catalog_materials.php">← К списку</a></p>
<?php if ($flashErr !== '') { ?><p class="err"><?= tp_admin_web_h($flashErr) ?></p><?php } ?>
<form method="post" action="" enctype="multipart/form-data">
    <input type="hidden" name="create_material" value="1">
    <label class="b" for="sku">SKU (уникальный)</label>
    <input class="in" type="text" name="sku" id="sku" required maxlength="64" value="<?= tp_admin_web_h($vals['sku']) ?>">
    <label class="b" for="category">Категория</label>
    <select class="in" name="category" id="category" style="max-width:32rem">
        <?php foreach ($cats as $slug => $label) { ?>
            <option value="<?= tp_admin_web_h($slug) ?>" <?= $vals['category'] === $slug ? 'selected' : '' ?>><?= tp_admin_web_h($label) ?></option>
        <?php } ?>
    </select>
    <label class="b" for="name">Название</label>
    <input class="in" type="text" name="name" id="name" required value="<?= tp_admin_web_h($vals['name']) ?>">
    <label class="b" for="description">Описание</label>
    <textarea class="in" name="description" id="description"><?= tp_admin_web_h($vals['description']) ?></textarea>
    <label class="b" for="material">Материал</label>
    <input class="in" type="text" name="material" id="material" value="<?= tp_admin_web_h($vals['material']) ?>">
    <label class="b" for="color">Цвет</label>
    <input class="in" type="text" name="color" id="color" value="<?= tp_admin_web_h($vals['color']) ?>">
    <label class="b" for="texture">Текстура</label>
    <input class="in" type="text" name="texture" id="texture" value="<?= tp_admin_web_h($vals['texture']) ?>">
    <label class="b" for="thickness_mm">Толщина, мм</label>
    <input class="in" type="text" name="thickness_mm" id="thickness_mm" value="<?= tp_admin_web_h($vals['thickness_mm']) ?>">
    <label class="b" for="width_mm">Ширина, мм</label>
    <input class="in" type="text" name="width_mm" id="width_mm" value="<?= tp_admin_web_h($vals['width_mm']) ?>">
    <label class="b" for="length_mm">Длина, мм</label>
    <input class="in" type="text" name="length_mm" id="length_mm" value="<?= tp_admin_web_h($vals['length_mm']) ?>">
    <label class="b" for="package_qty">Кратность упаковки</label>
    <input class="in" type="text" name="package_qty" id="package_qty" value="<?= tp_admin_web_h($vals['package_qty']) ?>">
    <label class="b" for="unit">Единица</label>
    <input class="in" type="text" name="unit" id="unit" value="<?= tp_admin_web_h($vals['unit']) ?>">
    <label class="b" for="price">Цена</label>
    <input class="in" type="text" name="price" id="price" value="<?= tp_admin_web_h($vals['price']) ?>">
    <label class="b" for="image_path">Путь к картинке (вручную)</label>
    <input class="in" type="text" name="image_path" id="image_path" value="<?= tp_admin_web_h($vals['image_path']) ?>">
    <label class="b" for="image_upload">Или загрузить файл</label>
    <input class="in" type="file" name="image_upload" id="image_upload" accept="image/jpeg,image/png,image/webp">
    <label class="b" for="sort_order">Порядок сортировки</label>
    <input class="in" type="number" name="sort_order" id="sort_order" value="<?= tp_admin_web_h($vals['sort_order']) ?>">
    <label class="b"><input type="checkbox" name="is_active" value="1" <?= $vals['is_active'] === '1' ? 'checked' : '' ?>> Активна в API</label>
    <div class="form-actions">
        <button type="submit" class="btn">Создать</button>
        <a class="btn secondary" href="catalog_materials.php">Отмена</a>
    </div>
</form>
<?php
tp_admin_web_layout_end();
