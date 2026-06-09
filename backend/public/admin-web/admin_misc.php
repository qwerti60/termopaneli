<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap_web.php';

$pdo = tp_admin_web_require_login();
tp_admin_web_require_include('admin_app_settings.php');
$adminLogin = (string) ($_SESSION['admin_web_login'] ?? '');

$apiList = tp_admin_web_public_href('api/v1/catalog/list.php');
$apiManifest = tp_admin_web_public_href('api/v1/settings/app-manifest.php');
$flashOk = '';
$flashErr = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = (string) ($_POST['csrf'] ?? '');
    if (!tp_admin_web_csrf_check($csrf)) {
        $flashErr = 'Сессия устарела. Обновите страницу.';
    } else {
        $action = (string) ($_POST['action'] ?? '');
        if ($action === 'save_ads') {
            try {
                tp_admin_app_settings_save_yandex_banner_id((string) ($_POST['yandex_banner_ad_unit_id'] ?? ''));
                $flashOk = 'Настройки рекламы сохранены. Приложение увидит их после обновления app-manifest (кэш до 5 минут).';
            } catch (Throwable $e) {
                $flashErr = $e->getMessage();
            }
        }
    }
}

$csrfNew = tp_admin_web_csrf_token();
$yandexBannerAdUnitId = tp_admin_app_settings_yandex_banner_id();

tp_admin_web_layout_start('Прочее', 'more', $adminLogin !== '' ? $adminLogin : null);
?>
<?php if ($flashErr !== '') { ?>
    <p class="err"><?= tp_admin_web_h($flashErr) ?></p>
<?php } ?>
<?php if ($flashOk !== '') { ?>
    <p class="ok"><?= tp_admin_web_h($flashOk) ?></p>
<?php } ?>
<p class="meta">Справочник по веб-админке и окружению: быстрые ссылки, проверки API и типовые проблемы. Основные операции — в пунктах левого меню.</p>

<div class="card">
    <h2>Разделы админки</h2>
    <ul>
        <li><a href="requests.php">Заявки и сметы</a> — статусы, просмотр сметы, PDF по заявке.</li>
        <li><a href="admin_estimates.php">Сметы (все)</a> — все сохранённые сметы пользователей.</li>
        <li><a href="catalog_panels.php">Панели</a>, <a href="catalog_materials.php">Материалы</a>, <a href="catalog_work_prices.php">Работы</a> — каталог и цены для приложения.</li>
        <li><a href="admin_users.php">Пользователи</a> — блокировка учётных записей клиентов.</li>
        <li><a href="subscriptions.php">Подписки PRO</a> — сводка, подписчики, журнал событий.</li>
        <li><a href="admin_journal.php">Журнал</a> — действия администраторов в веб-интерфейсе.</li>
    </ul>
</div>

<div class="card">
    <h2>Документация для офиса</h2>
    <p><a href="app_user_guide.html" target="_blank" rel="noopener">Руководство по мобильному приложению</a> (откроется в новой вкладке) — сценарии для клиента и менеджера.</p>
    <p class="meta">Для разработки и наката на сервер: в репозитории проекта — <code>docs/testing_admin.md</code>, <code>docs/testing_catalog.md</code>, <code>docs/estimate_mvp.md</code>, <code>backend/README_API.txt</code>.</p>
</div>

<div class="card">
    <h2>Быстрая проверка API (без входа в админку)</h2>
    <p class="meta">Каталог и настройки читаются приложением по GET; убедитесь, что базовый URL совпадает с тем, что в <code>API_BASE_URL</code> у клиента.</p>
    <ul>
        <li><a href="<?= tp_admin_web_h($apiList) ?>?category=panel&amp;limit=3" target="_blank" rel="noopener">Каталог: панели (limit=3)</a></li>
        <li><a href="<?= tp_admin_web_h($apiList) ?>?category=slope&amp;limit=3" target="_blank" rel="noopener">Каталог: откосы (limit=3)</a></li>
        <li><a href="<?= tp_admin_web_h($apiManifest) ?>" target="_blank" rel="noopener">App-manifest</a> (ссылки, реквизиты PDF, SmartCalc и т.д.)</li>
    </ul>
</div>

<div class="card">
    <h2>Реклама РСЯ в приложении</h2>
    <p class="meta">ID баннерного блока отдаётся в <code>GET .../settings/app-manifest.php</code> как <code>yandex_banner_ad_unit_id</code>. Приложение показывает sticky-баннеры на экранах «Каталог» и «Поиск».</p>
    <form method="post" action="admin_misc.php" autocomplete="off">
        <input type="hidden" name="csrf" value="<?= tp_admin_web_h($csrfNew) ?>">
        <input type="hidden" name="action" value="save_ads">
        <label class="b" for="yandex_banner_ad_unit_id">ID баннерного блока РСЯ</label>
        <input class="in" id="yandex_banner_ad_unit_id" name="yandex_banner_ad_unit_id" type="text" maxlength="64" value="<?= tp_admin_web_h($yandexBannerAdUnitId !== '' ? $yandexBannerAdUnitId : 'R-M-19410021-1') ?>" placeholder="R-M-19410021-1">
        <p class="meta">Оставьте пустым, чтобы скрыть баннеры. Сохранение создаёт или обновляет <code>config.local.php</code> рядом с <code>config.php</code>.</p>
        <div class="form-actions">
            <button class="btn" type="submit">Сохранить рекламу</button>
            <a class="btn secondary" href="<?= tp_admin_web_h($apiManifest) ?>" target="_blank" rel="noopener">Проверить app-manifest</a>
        </div>
    </form>
</div>

<div class="card">
    <h2>Структура на сервере (рядом с <code>admin-web</code>)</h2>
    <p>Обычно один каталог публикации (например <code>tp_api</code>) содержит:</p>
    <ul>
        <li><code>admin-web/</code> — эта веб-админка;</li>
        <li><code>api/v1/…</code> — REST для приложения;</li>
        <li><code>include/</code> — общие PHP (<code>api_bootstrap.php</code>, репозитории, Dompdf для PDF);</li>
        <li><code>catalog_uploads/</code> — загруженные из админки изображения для каталога;</li>
        <li><code>config.php</code> — настройки БД, почты, <code>company_pdf</code>, <code>app_manifest</code> (не отдавать в публичный git).</li>
    </ul>
</div>

<div class="card">
    <h2>PDF заявки в браузере (ошибка 503 и т.п.)</h2>
    <p>Кнопка «Скачать PDF» на странице просмотра сметы использует Dompdf. Если PDF не строится, на сервере в каталоге <code>backend/</code> (или эквивалент рядом с <code>public</code>) выполните <code>composer install</code>, чтобы появился каталог <code>vendor/</code>. Подробный чеклист — в репозитории <code>docs/testing_admin.md</code>.</p>
</div>

<div class="card">
    <h2>Подписки PRO</h2>
    <p>Раздел меню «Подписки PRO» требует таблиц <code>user_subscriptions</code> и <code>subscription_payment_events</code>. На существующей БД выполните SQL-миграцию <code>backend/sql/migrate_user_subscriptions.sql</code> (см. <code>docs/testing_admin.md</code>).</p>
</div>

<div class="card">
    <h2>Сессия и пароль администратора</h2>
    <ul>
        <li>Смена пароля: клик по <strong>логину</strong> внизу меню → <a href="admin_password.php">страница пароля</a>.</li>
        <li>Сброс по e-mail: со <a href="login.php">страницы входа</a> — ссылка «Забыли пароль» (нужны почта в БД и настройки <code>mail.*</code> в <code>config.php</code>).</li>
    </ul>
</div>

<div class="card">
    <h2>Среда PHP</h2>
    <p class="meta">Версия PHP на этом хосте: <strong><?= tp_admin_web_h(PHP_VERSION) ?></strong>. При смене версии проверьте расширения (pdo_mysql, json, mbstring, gd для Dompdf при необходимости).</p>
</div>
<?php
tp_admin_web_layout_end();
