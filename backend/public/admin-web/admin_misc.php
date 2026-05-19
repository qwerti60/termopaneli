<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Прочее', 'more', $adminLogin !== '' ? $adminLogin : null);
?>
<p class="meta">Раздел заготовка: пользователи, журнал действий — по плану в <strong>разделе 16</strong> (<code>development_plan.md</code>).</p>
<p>Сейчас в меню: заявки, панели, материалы, работы — с <strong>добавлением/удалением</strong> позиций и <strong>загрузкой картинок</strong> в <code>catalog_uploads/</code>.</p>
<?php
tp_admin_web_layout_end();
