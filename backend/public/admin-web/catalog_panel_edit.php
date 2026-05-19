<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_panels.php');
tp_admin_web_require_include('admin_catalog_media.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$id = (int) ($_GET['id'] ?? 0);
if ($id <= 0) {
    http_response_code(400);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Укажите id: catalog_panel_edit.php?id=…';
    exit;
}

$describe = tp_admin_panel_catalog_describe($pdo);
$row = null;
if ($describe !== null) {
    try {
        $row = tp_admin_panel_catalog_get($pdo, $id);
    } catch (Throwable $e) {
        $row = null;
    }
}

if ($describe === null) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Таблица thermo_panel_catalog недоступна.';
    exit;
}
if ($row === null) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Позиция не найдена';
    exit;
}

$imgCol = tp_admin_panel_catalog_resolve_image_column($describe);

$flashOk = '';
$flashErr = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['save_panel'])) {
    $post = [];
    foreach ($_POST as $k => $v) {
        if ($k === 'save_panel' || $k === 'image_clear') {
            continue;
        }
        $post[(string) $k] = is_array($v) ? '' : (string) $v;
    }

    if ($imgCol !== null) {
        $oldImg = trim((string) ($row[$imgCol] ?? ''));
        if (!empty($_FILES['image_upload']['tmp_name']) && is_uploaded_file((string) $_FILES['image_upload']['tmp_name'])) {
            $up = tp_admin_catalog_upload_save_image($_FILES['image_upload'], 'panels');
            if ($up['ok'] !== true) {
                $flashErr = (string) ($up['error'] ?? 'Ошибка загрузки');
            } else {
                if ($oldImg !== '' && tp_admin_catalog_upload_is_managed($oldImg)) {
                    tp_admin_catalog_upload_try_unlink($oldImg);
                }
                $post[$imgCol] = (string) $up['relative_path'];
            }
        } elseif (isset($_POST['image_clear']) && (string) $_POST['image_clear'] === '1') {
            if ($oldImg !== '' && tp_admin_catalog_upload_is_managed($oldImg)) {
                tp_admin_catalog_upload_try_unlink($oldImg);
            }
            $post[$imgCol] = '';
        }
    }

    if ($flashErr === '') {
        $res = tp_admin_panel_catalog_update($pdo, $id, $post);
        if ($res === true) {
            $flashOk = 'Сохранено';
            $row = tp_admin_panel_catalog_get($pdo, $id) ?? $row;
        } else {
            $flashErr = is_string($res) ? $res : 'Ошибка сохранения';
        }
    }
}

$title = tp_admin_panel_catalog_row_title($row);
$curImg = $imgCol !== null ? trim((string) ($row[$imgCol] ?? '')) : '';

tp_admin_web_layout_start('Панель: ' . $title, 'panels', $adminLogin !== '' ? $adminLogin : null);
?>
<p class="row-actions">
    <a class="btn secondary small" href="catalog_panels.php">← К списку панелей</a>
    <form method="post" action="catalog_panel_delete.php" style="display:inline" onsubmit="return confirm('Удалить эту позицию?');">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h(tp_admin_web_csrf_token()) ?>">
        <input type="hidden" name="id" value="<?= (int) $id ?>">
        <button type="submit" name="delete_panel" value="1" class="btn secondary small">Удалить позицию</button>
    </form>
</p>
<p class="meta">Поля по <code>DESCRIBE thermo_panel_catalog</code>. BLOB/GEOMETRY не в форме.<?php if ($imgCol !== null) { ?> Колонка картинки: <code><?= tp_admin_web_h($imgCol) ?></code>.<?php } ?></p>
<?php if ($flashOk !== '') { ?><p class="ok"><?= tp_admin_web_h($flashOk) ?></p><?php } ?>
<?php if ($flashErr !== '') { ?><p class="err"><?= tp_admin_web_h($flashErr) ?></p><?php } ?>
<form method="post" action="" enctype="multipart/form-data">
    <input type="hidden" name="save_panel" value="1">
    <?php foreach ($describe as $col) {
        $field = (string) ($col['Field'] ?? '');
        if ($field === '') {
            continue;
        }
        $type = (string) ($col['Type'] ?? '');
        if ($field === 'id') {
            $val = (string) ($row[$field] ?? '');
            ?>
            <label class="b" for="f_<?= tp_admin_web_h($field) ?>">id</label>
            <input class="in" type="text" id="f_<?= tp_admin_web_h($field) ?>" value="<?= tp_admin_web_h($val) ?>" readonly disabled>
            <?php
            continue;
        }
        if ($imgCol !== null && $field === $imgCol) {
            ?>
            <label class="b">Картинка (<code><?= tp_admin_web_h($imgCol) ?></code>)</label>
            <?php if ($curImg !== '') { ?>
                <p><img class="thumb-preview" src="<?= tp_admin_web_h(tp_admin_web_public_href($curImg)) ?>" alt=""></p>
                <p class="meta">Текущее значение: <code><?= tp_admin_web_h($curImg) ?></code></p>
            <?php } ?>
            <label class="b" for="f_<?= tp_admin_web_h($field) ?>">Путь (вручную)</label>
            <input class="in" type="text" name="<?= tp_admin_web_h($field) ?>" id="f_<?= tp_admin_web_h($field) ?>" value="<?= tp_admin_web_h($curImg) ?>">
            <label class="b" for="image_upload">Загрузить JPEG/PNG/WebP (до 5 МБ) в <code>catalog_uploads/panels/</code></label>
            <input class="in" type="file" name="image_upload" id="image_upload" accept="image/jpeg,image/png,image/webp">
            <label class="b"><input type="checkbox" name="image_clear" value="1"> Сбросить картинку</label>
            <?php
            continue;
        }
        if ($field === 'created_at' || $field === 'updated_at') {
            $val = (string) ($row[$field] ?? '');
            ?>
            <label class="b"><?= tp_admin_web_h($field) ?></label>
            <p class="meta"><?= tp_admin_web_h($val !== '' ? $val : '—') ?> <span class="meta">(системное)</span></p>
            <?php
            continue;
        }
        if (tp_admin_panel_type_skip_edit($type)) {
            continue;
        }
        $val = $row[$field] ?? '';
        if ($val !== null && !is_scalar($val)) {
            continue;
        }
        $sval = $val === null ? '' : (string) $val;
        $fid = 'f_' . preg_replace('/[^a-zA-Z0-9_]/', '_', $field);
        ?>
        <label class="b" for="<?= tp_admin_web_h($fid) ?>"><?= tp_admin_web_h($field) ?> <span class="meta">(<?= tp_admin_web_h($type) ?>)</span></label>
        <?php if (tp_admin_panel_type_is_boolish($type)) { ?>
            <label><input type="checkbox" name="<?= tp_admin_web_h($field) ?>" value="1" <?= ($sval === '1' || $sval === 'true') ? 'checked' : '' ?>> да</label>
        <?php } elseif (str_contains(strtolower($type), 'text')) { ?>
            <textarea class="in" name="<?= tp_admin_web_h($field) ?>" id="<?= tp_admin_web_h($fid) ?>"><?= tp_admin_web_h($sval) ?></textarea>
        <?php } else { ?>
            <input class="in" type="text" name="<?= tp_admin_web_h($field) ?>" id="<?= tp_admin_web_h($fid) ?>" value="<?= tp_admin_web_h($sval) ?>">
        <?php } ?>
    <?php } ?>
    <div class="form-actions">
        <button type="submit" class="btn">Сохранить</button>
        <a class="btn secondary" href="catalog_panels.php">Отмена</a>
    </div>
</form>
<?php
tp_admin_web_layout_end();
