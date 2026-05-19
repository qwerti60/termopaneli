<?php
declare(strict_types=1);

/**
 * Сессия, экранирование HTML, проверка входа и **общий каркас страниц (левое меню)** — в одном файле,
 * чтобы при выкладке на сервер хватило обновить `bootstrap_web.php` вместе со страницами.
 *
 * Ожидается структура как в репозитории: рядом с admin-web лежит include/
 * (т.е. .../tp_api/admin-web/ и .../tp_api/include/).
 */
if (!defined('TP_PUBLIC_ROOT')) {
    define('TP_PUBLIC_ROOT', dirname(__DIR__));
}

/**
 * Подключить файл из каталога include/ корня public (рядом с admin-web).
 */
function tp_admin_web_require_include(string $file): void
{
    $path = TP_PUBLIC_ROOT . '/include/' . $file;
    if (!is_readable($path)) {
        http_response_code(500);
        header('Content-Type: text/plain; charset=utf-8');
        echo "Не найден файл на сервере:\n{$path}\n\n";
        echo 'Залейте каталог include/ из репозитория (backend/public/include/) в ' . TP_PUBLIC_ROOT
            . "/include/ — на одном уровне с папками admin-web и api.\n"
            . "Нужны как минимум: api_bootstrap.php, admin_auth.php, admin_requests_service.php, admin_login_verify.php, admin_catalog_media.php, admin_catalog_materials.php, admin_catalog_panels.php, admin_work_prices.php, admin_estimates.php.\n";
        exit;
    }
    require_once $path;
}

tp_admin_web_require_include('api_bootstrap.php');

if (session_status() === PHP_SESSION_NONE) {
    $secure = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
    session_start([
        'cookie_httponly' => true,
        'cookie_samesite' => 'Lax',
        'cookie_secure' => $secure,
        'use_strict_mode' => true,
    ]);
}

function tp_admin_web_h(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** CSRF-токен для форм удаления и др. */
function tp_admin_web_csrf_token(): string
{
    if (empty($_SESSION['admin_web_csrf'])) {
        $_SESSION['admin_web_csrf'] = bin2hex(random_bytes(16));
    }

    return (string) $_SESSION['admin_web_csrf'];
}

function tp_admin_web_csrf_check(?string $token): bool
{
    return is_string($token)
        && isset($_SESSION['admin_web_csrf'])
        && hash_equals((string) $_SESSION['admin_web_csrf'], $token);
}

/** URL относительно каталога admin-web/ к файлу в корне public. */
function tp_admin_web_public_href(string $pathFromPublic): string
{
    $pathFromPublic = ltrim(str_replace('\\', '/', $pathFromPublic), '/');

    return '../' . $pathFromPublic;
}

/**
 * Проверка входа админа; редирект на login.php при отсутствии сессии.
 */
function tp_admin_web_require_login(): PDO
{
    tp_admin_web_require_include('admin_auth.php');
    $pdo = tp_pdo();
    if (!tp_admin_authorized($pdo)) {
        header('Location: login.php', true, 302);
        exit;
    }
    return $pdo;
}

/**
 * Общая вёрстка веб-админки: левое меню + область контента (см. также комментарий к файлу вверху).
 *
 * @param 'requests'|'estimates'|'panels'|'materials'|'works'|'more' $activeNav
 */
function tp_admin_web_layout_start(string $pageTitle, string $activeNav, ?string $adminLogin = null): void
{
    $nav = [
        'requests' => ['Заявки и сметы', 'requests.php'],
        'estimates' => ['Сметы (все)', 'admin_estimates.php'],
        'panels' => ['Панели', 'catalog_panels.php'],
        'materials' => ['Материалы', 'catalog_materials.php'],
        'works' => ['Работы', 'catalog_work_prices.php'],
        'more' => ['Прочее', 'admin_misc.php'],
    ];
    header('Content-Type: text/html; charset=utf-8');
    ?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= tp_admin_web_h($pageTitle) ?> — админ</title>
    <style>
        :root { --nav-bg: #0f172a; --nav-hover: #1e293b; --accent: #38bdf8; --main-bg: #f1f5f9; }
        * { box-sizing: border-box; }
        body { margin: 0; font-family: system-ui, -apple-system, sans-serif; background: var(--main-bg); color: #0f172a; min-height: 100vh; }
        .admin-shell { display: flex; flex-direction: row; width: 100%; min-height: 100vh; align-items: stretch; }
        .admin-nav { min-width: 14rem; width: 16rem; flex-shrink: 0; background: var(--nav-bg); color: #e2e8f0; padding: 1rem 0; display: flex; flex-direction: column; }
        .admin-nav h2 { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em; color: #94a3b8; margin: 0 1rem 0.5rem; font-weight: 600; }
        .admin-nav a { display: block; padding: 0.55rem 1rem; color: #e2e8f0; text-decoration: none; font-size: 0.9rem; border-left: 3px solid transparent; }
        .admin-nav a:hover { background: var(--nav-hover); }
        .admin-nav a.nav-active { background: var(--nav-hover); border-left-color: var(--accent); color: #fff; }
        .admin-nav .nav-foot { margin-top: auto; padding: 1rem; font-size: 0.8rem; color: #94a3b8; border-top: 1px solid #334155; }
        .admin-nav .nav-foot a { display: inline; padding: 0; color: var(--accent); border: none; }
        .admin-nav .nav-foot .nav-foot-guide { margin: 0.5rem 0 0.35rem; line-height: 1.35; }
        .admin-main { flex: 1; min-width: 0; padding: 1rem 1.25rem; overflow-x: auto; }
        .admin-main h1 { font-size: 1.25rem; margin: 0 0 1rem; font-weight: 600; }
        a.btn, button.btn { display: inline-block; padding: 0.4rem 0.75rem; background: #0369a1; color: #fff; text-decoration: none; border: none; border-radius: 6px; font-size: 0.875rem; cursor: pointer; }
        a.btn.secondary, button.btn.secondary { background: #475569; }
        a.btn.small, button.btn.small { font-size: 0.8rem; padding: 0.3rem 0.55rem; }
        table.data { width: 100%; border-collapse: collapse; background: #fff; font-size: 0.85rem; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 3px rgba(15,23,42,.08); }
        table.data th, table.data td { border: 1px solid #e2e8f0; padding: 0.4rem 0.5rem; text-align: left; vertical-align: top; }
        table.data th { background: #e2e8f0; font-weight: 600; }
        table.data tr:nth-child(even) { background: #f8fafc; }
        .meta { color: #64748b; font-size: 0.8rem; }
        .err { color: #b91c1c; margin: 0 0 1rem; }
        .ok { color: #15803d; margin: 0 0 1rem; }
        .filters { margin-bottom: 1rem; display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }
        .num { text-align: right; white-space: nowrap; }
        label.b { display: block; font-weight: 600; margin-top: 0.75rem; font-size: 0.85rem; }
        input.in, textarea.in, select.in { width: 100%; max-width: 32rem; padding: 0.45rem 0.5rem; margin-top: 0.2rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 0.9rem; }
        textarea.in { min-height: 4rem; max-width: 40rem; }
        .form-actions { margin-top: 1.25rem; display: flex; gap: 0.5rem; flex-wrap: wrap; }
        .toolbar { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; margin-bottom: 1rem; }
        .card { background: #fff; padding: 1rem; margin-bottom: 1rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(15,23,42,.08); }
        .card h2 { font-size: 1rem; margin: 0 0 0.5rem; font-weight: 600; }
        table.lines { width: 100%; border-collapse: collapse; font-size: 0.85rem; background: #fff; }
        table.lines th, table.lines td { border: 1px solid #e2e8f0; padding: 0.35rem 0.45rem; text-align: left; vertical-align: top; }
        table.lines th { background: #e2e8f0; font-weight: 600; }
        .comment { white-space: pre-wrap; }
        .thumb-preview { max-width: 10rem; max-height: 5rem; object-fit: contain; border-radius: 6px; border: 1px solid #cbd5e1; vertical-align: middle; }
        .row-actions { display: flex; flex-wrap: wrap; gap: 0.35rem; align-items: center; }
    </style>
</head>
<body>
<!-- admin-web: sidebar layout -->
<div class="admin-shell">
    <nav class="admin-nav" aria-label="Разделы админки">
        <h2>Меню</h2>
        <?php foreach ($nav as $key => $pair) {
            [$label, $href] = $pair;
            $cls = $activeNav === $key ? 'nav-active' : '';
            ?>
            <a class="<?= tp_admin_web_h($cls) ?>" href="<?= tp_admin_web_h($href) ?>"><?= tp_admin_web_h($label) ?></a>
        <?php } ?>
        <div class="nav-foot">
            <?php if ($adminLogin !== null && $adminLogin !== '') { ?>
                <div><?= tp_admin_web_h($adminLogin) ?></div>
            <?php } ?>
            <div class="nav-foot-guide"><a href="app_user_guide.html" target="_blank" rel="noopener">Руководство по приложению</a></div>
            <a href="logout.php">Выйти</a>
        </div>
    </nav>
    <div class="admin-main">
        <h1><?= tp_admin_web_h($pageTitle) ?></h1>
    <?php
}

function tp_admin_web_layout_end(): void
{
    ?>
    </div>
</div>
</body>
</html>
    <?php
}
