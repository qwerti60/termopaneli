<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_work_prices.php');
tp_admin_web_require_include('admin_catalog_media.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$id = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Укажите id: catalog_work_edit.php?id=…';
    exit;
}

$row = tp_admin_work_price_get($pdo, $id);
if ($row === null) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Позиция не найдена';
    exit;
}

$flashOk = '';
$flashErr = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['save_work'])) {
    $post = [];
    foreach ($_POST as $k => $v) {
        if ($k === 'save_work' || $k === 'image_clear') {
            continue;
        }
        $post[(string) $k] = is_array($v) ? '' : (string) $v;
    }

    $oldImg = trim((string) ($row['image_path'] ?? ''));

    if (!empty($_FILES['image_upload']['tmp_name']) && is_uploaded_file((string) $_FILES['image_upload']['tmp_name'])) {
        $up = tp_admin_catalog_upload_save_image($_FILES['image_upload'], 'works');
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
        $res = tp_admin_work_price_update($pdo, $id, $post);
        if ($res === true) {
            $flashOk = 'Сохранено';
            $row = tp_admin_work_price_get($pdo, $id) ?? $row;
        } else {
            $flashErr = is_string($res) ? $res : 'Ошибка сохранения';
        }
    }
}

$sku = (string) ($row['sku'] ?? '');
$calcRules = tp_admin_work_price_calc_rules();
$imgPath = trim((string) ($row['image_path'] ?? ''));

tp_admin_web_layout_start('Работа: ' . (string) ($row['name'] ?? ''), 'works', $adminLogin !== '' ? $adminLogin : null);
?>
<p class="meta">SKU <code><?= tp_admin_web_h($sku) ?></code> не меняется.</p>
<p class="row-actions">
    <a class="btn secondary small" href="catalog_work_prices.php">← К списку работ</a>
    <form method="post" action="catalog_work_delete.php" style="display:inline" onsubmit="return confirm('Удалить эту работу?');">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
        <input type="hidden" name="id" value="<?= (int) $id ?>">
        <button type="submit" name="delete_work" value="1" class="btn secondary small">Удалить позицию</button>
    </form>
</p>
<?php if ($flashOk !== '') { ?><p class="ok"><?= tp_admin_web_h($flashOk) ?></p><?php } ?>
<?php if ($flashErr !== '') { ?><p class="err"><?= tp_admin_web_h($flashErr) ?></p><?php } ?>
<form method="post" action="" enctype="multipart/form-data">
    <input type="hidden" name="save_work" value="1">
    <label class="b" for="name">Название</label>
    <input class="in" type="text" name="name" id="name" value="<?= tp_admin_web_h((string) ($row['name'] ?? '')) ?>">
    <label class="b" for="description">Описание</label>
    <textarea class="in" name="description" id="description"><?= tp_admin_web_h((string) ($row['description'] ?? '')) ?></textarea>
    <label class="b">Картинка</label>
    <?php if ($imgPath !== '') { ?>
        <p><img class="thumb-preview" src="<?= tp_admin_web_h(tp_admin_web_public_href($imgPath)) ?>" alt=""></p>
        <p class="meta">Путь: <code><?= tp_admin_web_h($imgPath) ?></code></p>
    <?php } else { ?>
        <p class="meta">Не задана.</p>
    <?php } ?>
    <label class="b" for="image_path">Путь вручную (относительно public)</label>
    <input class="in" type="text" name="image_path" id="image_path" value="<?= tp_admin_web_h($imgPath) ?>">
    <label class="b" for="image_upload">Загрузить JPEG/PNG/WebP в <code>catalog_uploads/works/</code></label>
    <input class="in" type="file" name="image_upload" id="image_upload" accept="image/jpeg,image/png,image/webp">
    <label class="b"><input type="checkbox" name="image_clear" value="1"> Сбросить картинку</label>
    <label class="b" for="unit">Единица</label>
    <input class="in" type="text" name="unit" id="unit" value="<?= tp_admin_web_h((string) ($row['unit'] ?? 'шт')) ?>">
    <label class="b" for="price">Цена за единицу</label>
    <input class="in" type="text" name="price" id="price" value="<?= tp_admin_web_h((string) ($row['price'] ?? '0')) ?>">
    <label class="b" for="calc_rule">Правило количества в смете</label>
    <select class="in" name="calc_rule" id="calc_rule" style="max-width:32rem">
        <?php foreach ($calcRules as $cr) { ?>
            <option value="<?= tp_admin_web_h($cr) ?>" <?= ((string) ($row['calc_rule'] ?? '') === $cr) ? 'selected' : '' ?>><?= tp_admin_web_h($cr) ?></option>
        <?php } ?>
    </select>
    <p class="meta"><strong>manual</strong> — количество 1 по умолчанию; остальные — <code>quantityForWork</code> в приложении.</p>
    <label class="b" for="sort_order">Порядок сортировки</label>
    <input class="in" type="number" name="sort_order" id="sort_order" value="<?= (int) ($row['sort_order'] ?? 100) ?>">
    <label class="b"><input type="checkbox" name="is_default" value="1" <?= ((int) ($row['is_default'] ?? 0) === 1) ? 'checked' : '' ?>> По умолчанию в каталоге</label>
    <label class="b"><input type="checkbox" name="is_active" value="1" <?= ((int) ($row['is_active'] ?? 0) === 1) ? 'checked' : '' ?>> Активна в API</label>
    <div class="form-actions">
        <button type="submit" class="btn">Сохранить</button>
        <a class="btn secondary" href="catalog_work_prices.php">Отмена</a>
    </div>
</form>
<?php
tp_admin_web_layout_end();
