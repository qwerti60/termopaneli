<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_materials.php');
tp_admin_web_require_include('admin_catalog_media.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$id = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Укажите id в query: catalog_edit.php?id=…';
    exit;
}

$row = null;
try {
    $row = tp_admin_catalog_material_get($pdo, $id);
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Ошибка БД (таблица catalog_materials).';
    exit;
}
if ($row === null) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Позиция не найдена';
    exit;
}

$flashOk = '';
$flashErr = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['save_catalog'])) {
    $post = [];
    foreach ($_POST as $k => $v) {
        if ($k === 'save_catalog' || $k === 'image_clear') {
            continue;
        }
        $post[(string) $k] = is_array($v) ? '' : (string) $v;
    }

    $oldImg = trim((string) ($row['image_path'] ?? ''));

    if (!empty($_FILES['image_upload']['tmp_name']) && is_uploaded_file((string) $_FILES['image_upload']['tmp_name'])) {
        $up = tp_admin_catalog_upload_save_image($_FILES['image_upload'], 'materials');
        if ($up['ok'] !== true) {
            $flashErr = (string) ($up['error'] ?? 'Ошибка загрузки');
        } else {
            if ($oldImg !== '' && tp_admin_catalog_upload_is_managed($oldImg)) {
                tp_admin_catalog_upload_try_unlink($oldImg);
            }
            $post['image_path'] = (string) $up['relative_path'];
        }
    } elseif (isset($_POST['image_clear']) && (string) $_POST['image_clear'] === '1') {
        if ($oldImg !== '' && tp_admin_catalog_upload_is_managed($oldImg)) {
            tp_admin_catalog_upload_try_unlink($oldImg);
        }
        $post['image_path'] = '';
    }

    if ($flashErr === '') {
        $res = tp_admin_catalog_material_update($pdo, $id, $post);
        if ($res === true) {
            $flashOk = 'Сохранено';
            $row = tp_admin_catalog_material_get($pdo, $id) ?? $row;
        } else {
            $flashErr = is_string($res) ? $res : 'Ошибка сохранения';
        }
    }
}

$catLabels = tp_admin_catalog_material_categories();
$sku = (string) ($row['sku'] ?? '');
$rcat = (string) ($row['category'] ?? '');
$catHuman = $catLabels[$rcat] ?? $rcat;
$imgPath = trim((string) ($row['image_path'] ?? ''));

function tp_admin_web_field(string $name, string $label, string $value, string $type = 'text'): void
{
    ?>
    <label class="b" for="<?= tp_admin_web_h($name) ?>"><?= tp_admin_web_h($label) ?></label>
    <?php if ($type === 'textarea') { ?>
        <textarea class="in" name="<?= tp_admin_web_h($name) ?>" id="<?= tp_admin_web_h($name) ?>"><?= tp_admin_web_h($value) ?></textarea>
    <?php } else { ?>
        <input class="in" type="<?= tp_admin_web_h($type) ?>" name="<?= tp_admin_web_h($name) ?>" id="<?= tp_admin_web_h($name) ?>" value="<?= tp_admin_web_h($value) ?>">
    <?php }
}

tp_admin_web_layout_start('Редактирование: ' . (string) ($row['name'] ?? ''), 'materials', $adminLogin !== '' ? $adminLogin : null);
?>
<p class="meta">Артикул <code><?= tp_admin_web_h($sku) ?></code> · категория <strong><?= tp_admin_web_h($catHuman) ?></strong> (<code><?= tp_admin_web_h($rcat) ?></code>) — в этом интерфейсе не меняются.</p>
<p class="row-actions">
    <a class="btn secondary small" href="catalog_materials.php">← К списку каталога</a>
    <form method="post" action="catalog_material_delete.php" style="display:inline" onsubmit="return confirm('Удалить эту позицию из базы?');">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
        <input type="hidden" name="id" value="<?= (int) $id ?>">
        <button type="submit" name="delete_material" value="1" class="btn secondary small">Удалить позицию</button>
    </form>
</p>
<?php if ($flashOk !== '') { ?><p class="ok"><?= tp_admin_web_h($flashOk) ?></p><?php } ?>
<?php if ($flashErr !== '') { ?><p class="err"><?= tp_admin_web_h($flashErr) ?></p><?php } ?>
<form method="post" action="" enctype="multipart/form-data">
    <input type="hidden" name="save_catalog" value="1">
    <?php
    tp_admin_web_field('name', 'Название', (string) ($row['name'] ?? ''));
    tp_admin_web_field('description', 'Описание', (string) ($row['description'] ?? ''), 'textarea');
    tp_admin_web_field('material', 'Материал', (string) ($row['material'] ?? ''));
    tp_admin_web_field('color', 'Цвет', (string) ($row['color'] ?? ''));
    tp_admin_web_field('texture', 'Текстура', (string) ($row['texture'] ?? ''));
    tp_admin_web_field('thickness_mm', 'Толщина, мм', $row['thickness_mm'] !== null && $row['thickness_mm'] !== '' ? (string) $row['thickness_mm'] : '');
    tp_admin_web_field('width_mm', 'Ширина, мм', $row['width_mm'] !== null && $row['width_mm'] !== '' ? (string) $row['width_mm'] : '');
    tp_admin_web_field('length_mm', 'Длина, мм', $row['length_mm'] !== null && $row['length_mm'] !== '' ? (string) $row['length_mm'] : '');
    tp_admin_web_field('package_qty', 'Кратность упаковки (пусто или меньше 2 — не применять)', $row['package_qty'] !== null && (int) $row['package_qty'] >= 2 ? (string) (int) $row['package_qty'] : '');
    tp_admin_web_field('unit', 'Единица', (string) ($row['unit'] ?? 'шт'));
    tp_admin_web_field('price', 'Цена', (string) ($row['price'] ?? '0'));
    ?>
    <label class="b">Картинка</label>
    <?php if ($imgPath !== '') { ?>
        <p><img class="thumb-preview" src="<?= tp_admin_web_h(tp_admin_web_public_href($imgPath)) ?>" alt=""></p>
        <p class="meta">Текущий путь: <code><?= tp_admin_web_h($imgPath) ?></code></p>
    <?php } else { ?>
        <p class="meta">Картинка не задана.</p>
    <?php } ?>
    <label class="b" for="image_path">Путь к файлу (вручную, относительно public)</label>
    <input class="in" type="text" name="image_path" id="image_path" value="<?= tp_admin_web_h($imgPath) ?>">
    <label class="b" for="image_upload">Загрузить файл (JPEG/PNG/WebP, до 5 МБ) — сохранится в <code>catalog_uploads/materials/</code></label>
    <input class="in" type="file" name="image_upload" id="image_upload" accept="image/jpeg,image/png,image/webp">
    <label class="b"><input type="checkbox" name="image_clear" value="1"> Сбросить картинку (очистить путь; файл из uploads при необходимости удалится)</label>
    <label class="b" for="sort_order">Порядок сортировки</label>
    <input class="in" type="number" name="sort_order" id="sort_order" value="<?= (int) ($row['sort_order'] ?? 100) ?>">
    <label class="b"><input type="checkbox" name="is_active" value="1" <?= ((int) ($row['is_active'] ?? 0) === 1) ? 'checked' : '' ?>> Активна в API</label>
    <div class="form-actions">
        <button type="submit" class="btn">Сохранить</button>
        <a class="btn secondary" href="catalog_materials.php">Отмена</a>
    </div>
</form>
<?php
tp_admin_web_layout_end();
