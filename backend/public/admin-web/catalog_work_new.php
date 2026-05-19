<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_work_prices.php');
tp_admin_web_require_include('admin_catalog_media.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$vals = [
    'sku' => '',
    'name' => '',
    'description' => '',
    'image_path' => '',
    'unit' => 'шт',
    'price' => '0',
    'calc_rule' => 'manual',
    'sort_order' => '100',
    'is_default' => '0',
    'is_active' => '1',
];

$flashErr = '';
$calcRules = tp_admin_work_price_calc_rules();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_work'])) {
    $post = [];
    foreach ($_POST as $k => $v) {
        if ($k === 'create_work' || $k === 'image_clear') {
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
        $up = tp_admin_catalog_upload_save_image($_FILES['image_upload'], 'works');
        if ($up['ok'] !== true) {
            $flashErr = (string) ($up['error'] ?? 'Ошибка загрузки');
        } else {
            $post['image_path'] = (string) $up['relative_path'];
        }
    } elseif (isset($_POST['image_clear']) && (string) $_POST['image_clear'] === '1') {
        $post['image_path'] = '';
    }

    if ($flashErr === '') {
        $ins = tp_admin_work_price_insert($pdo, $post);
        if (($ins['ok'] ?? false) === true) {
            header('Location: catalog_work_edit.php?id=' . (int) $ins['id'], true, 303);
            exit;
        }
        $flashErr = (string) ($ins['error'] ?? 'Не удалось создать');
    }
}

tp_admin_web_layout_start('Новая работа (прайс)', 'works', $adminLogin !== '' ? $adminLogin : null);
?>
<p><a class="btn secondary small" href="catalog_work_prices.php">← К списку</a></p>
<?php if ($flashErr !== '') { ?><p class="err"><?= tp_admin_web_h($flashErr) ?></p><?php } ?>
<form method="post" action="" enctype="multipart/form-data">
    <input type="hidden" name="create_work" value="1">
    <label class="b" for="sku">SKU (уникальный, латиница)</label>
    <input class="in" type="text" name="sku" id="sku" required maxlength="64" value="<?= tp_admin_web_h($vals['sku']) ?>" placeholder="WORK-MY-01">
    <label class="b" for="name">Название</label>
    <input class="in" type="text" name="name" id="name" required value="<?= tp_admin_web_h($vals['name']) ?>">
    <label class="b" for="description">Описание</label>
    <textarea class="in" name="description" id="description"><?= tp_admin_web_h($vals['description']) ?></textarea>
    <label class="b" for="image_path">Путь к картинке (вручную)</label>
    <input class="in" type="text" name="image_path" id="image_path" value="<?= tp_admin_web_h($vals['image_path']) ?>">
    <label class="b" for="image_upload">Или загрузить файл</label>
    <input class="in" type="file" name="image_upload" id="image_upload" accept="image/jpeg,image/png,image/webp">
    <label class="b" for="unit">Единица</label>
    <input class="in" type="text" name="unit" id="unit" value="<?= tp_admin_web_h($vals['unit']) ?>">
    <label class="b" for="price">Цена</label>
    <input class="in" type="text" name="price" id="price" value="<?= tp_admin_web_h($vals['price']) ?>">
    <label class="b" for="calc_rule">Правило количества</label>
    <select class="in" name="calc_rule" id="calc_rule" style="max-width:32rem">
        <?php foreach ($calcRules as $cr) { ?>
            <option value="<?= tp_admin_web_h($cr) ?>" <?= $vals['calc_rule'] === $cr ? 'selected' : '' ?>><?= tp_admin_web_h($cr) ?></option>
        <?php } ?>
    </select>
    <label class="b" for="sort_order">Порядок</label>
    <input class="in" type="number" name="sort_order" id="sort_order" value="<?= tp_admin_web_h($vals['sort_order']) ?>">
    <label class="b"><input type="checkbox" name="is_default" value="1" <?= $vals['is_default'] === '1' ? 'checked' : '' ?>> По умолчанию</label>
    <label class="b"><input type="checkbox" name="is_active" value="1" <?= $vals['is_active'] === '1' ? 'checked' : '' ?>> Активна</label>
    <div class="form-actions">
        <button type="submit" class="btn">Создать</button>
        <a class="btn secondary" href="catalog_work_prices.php">Отмена</a>
    </div>
</form>
<?php
tp_admin_web_layout_end();
