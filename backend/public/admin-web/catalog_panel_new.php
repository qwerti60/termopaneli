<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_catalog_panels.php');
tp_admin_web_require_include('admin_catalog_media.php');

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$describe = tp_admin_panel_catalog_describe($pdo);
if ($describe === null) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Таблица thermo_panel_catalog недоступна.';
    exit;
}

$imgCol = tp_admin_panel_catalog_resolve_image_column($describe);
$row = [];
foreach ($describe as $col) {
    $f = (string) ($col['Field'] ?? '');
    if ($f !== '') {
        $row[$f] = '';
    }
}

$flashErr = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['create_panel'])) {
    $post = [];
    foreach ($_POST as $k => $v) {
        if ($k === 'create_panel' || $k === 'image_clear') {
            continue;
        }
        $post[(string) $k] = is_array($v) ? '' : (string) $v;
    }

    if ($imgCol !== null) {
        if (!empty($_FILES['image_upload']['tmp_name']) && is_uploaded_file((string) $_FILES['image_upload']['tmp_name'])) {
            $up = tp_admin_catalog_upload_save_image($_FILES['image_upload'], 'panels');
            if ($up['ok'] !== true) {
                $flashErr = (string) ($up['error'] ?? 'Ошибка загрузки');
            } else {
                $post[$imgCol] = (string) $up['relative_path'];
            }
        } elseif (isset($_POST['image_clear']) && (string) $_POST['image_clear'] === '1') {
            $post[$imgCol] = '';
        }
    }

    if ($flashErr === '') {
        $ins = tp_admin_panel_catalog_insert($pdo, $post);
        if (($ins['ok'] ?? false) === true) {
            header('Location: catalog_panel_edit.php?id=' . (int) $ins['id'], true, 303);
            exit;
        }
        $flashErr = (string) ($ins['error'] ?? 'Не удалось создать');
    }
}

tp_admin_web_layout_start('Новая панель', 'panels', $adminLogin !== '' ? $adminLogin : null);
?>
<p><a class="btn secondary small" href="catalog_panels.php">← К списку</a></p>
<p class="meta">Заполните обязательные поля вашей таблицы. Пустые необязательные поля уйдут как NULL.</p>
<?php if ($flashErr !== '') { ?><p class="err"><?= tp_admin_web_h($flashErr) ?></p><?php } ?>
<form method="post" action="" enctype="multipart/form-data">
    <input type="hidden" name="create_panel" value="1">
    <?php foreach ($describe as $col) {
        $field = (string) ($col['Field'] ?? '');
        if ($field === '') {
            continue;
        }
        $type = (string) ($col['Type'] ?? '');
        if ($field === 'id' || $field === 'created_at' || $field === 'updated_at') {
            continue;
        }
        if (tp_admin_panel_type_skip_edit($type)) {
            continue;
        }
        if ($imgCol !== null && $field === $imgCol) {
            ?>
            <label class="b">Картинка (<code><?= tp_admin_web_h($imgCol) ?></code>)</label>
            <label class="b" for="f_<?= tp_admin_web_h($field) ?>">Путь (вручную)</label>
            <input class="in" type="text" name="<?= tp_admin_web_h($field) ?>" id="f_<?= tp_admin_web_h($field) ?>" value="">
            <label class="b" for="image_upload">Или загрузить файл</label>
            <input class="in" type="file" name="image_upload" id="image_upload" accept="image/jpeg,image/png,image/webp">
            <?php
            continue;
        }
        $fid = 'f_' . preg_replace('/[^a-zA-Z0-9_]/', '_', $field);
        ?>
        <label class="b" for="<?= tp_admin_web_h($fid) ?>"><?= tp_admin_web_h($field) ?> <span class="meta">(<?= tp_admin_web_h($type) ?>)</span></label>
        <?php if (tp_admin_panel_type_is_boolish($type)) { ?>
            <label><input type="checkbox" name="<?= tp_admin_web_h($field) ?>" value="1"> да</label>
        <?php } elseif (str_contains(strtolower($type), 'text')) { ?>
            <textarea class="in" name="<?= tp_admin_web_h($field) ?>" id="<?= tp_admin_web_h($fid) ?>"></textarea>
        <?php } else { ?>
            <input class="in" type="text" name="<?= tp_admin_web_h($field) ?>" id="<?= tp_admin_web_h($fid) ?>" value="">
        <?php } ?>
    <?php } ?>
    <div class="form-actions">
        <button type="submit" class="btn">Создать</button>
        <a class="btn secondary" href="catalog_panels.php">Отмена</a>
    </div>
</form>
<?php
tp_admin_web_layout_end();
