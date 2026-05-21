<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';

$pdo = tp_admin_web_require_login();
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

tp_admin_web_layout_start('Прочее', 'more', $adminLogin !== '' ? $adminLogin : null);
?>
<p class="meta">Раздел-заготовка: расширенные отчёты и служебные ссылки. Основное уже в меню: <strong>Пользователи</strong>, <strong>Журнал</strong>, каталоги с ценами и картинками, заявки и сметы.</p>
<?php
tp_admin_web_layout_end();
