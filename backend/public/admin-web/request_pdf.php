<?php
declare(strict_types=1);

/**
 * Скачивание PDF сметы по id заявки (веб-админка, сессия).
 * Требуется: backend/vendor (composer install в каталоге backend/).
 */
require_once __DIR__ . '/bootstrap_web.php';
tp_admin_web_require_include('admin_auth.php');
tp_admin_web_require_include('admin_requests_service.php');
tp_admin_web_require_include('company_pdf_defaults.php');
tp_admin_web_require_include('admin_estimate_pdf.php');

$pdo = tp_pdo();
if (!tp_admin_authorized($pdo)) {
    header('Location: login.php', true, 302);
    exit;
}

$requestId = (int) ($_GET['id'] ?? 0);
$detail = tp_admin_fetch_request_detail($pdo, $requestId);
if ($detail['ok'] !== true) {
    http_response_code($requestId > 0 ? 404 : 400);
    header('Content-Type: text/plain; charset=utf-8');
    echo $detail['message'];
    exit;
}

$r = $detail['request'];

if (!tp_admin_composer_autoload()) {
    http_response_code(503);
    header('Content-Type: text/plain; charset=utf-8');
    echo "PDF недоступен: не установлены PHP-зависимости (Dompdf).\n\n"
        . "Нужен каталог vendor/ с autoload.php в одном из мест:\n"
        . "  • рядом с корнем сайта (public): ../vendor/ относительно папки с api/ и include/;\n"
        . "  • или внутри корня сайта: tp_api/vendor/ (удобно на shared hosting).\n\n"
        . "Установка без глобального «composer» (из каталога, где лежат composer.json и composer.lock):\n"
        . "  php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\"\n"
        . "  php composer-setup.php --install-dir=. --filename=composer.phar\n"
        . "  php -r \"unlink('composer-setup.php');\"\n"
        . "  php composer.phar install --no-dev --no-interaction\n\n"
        . "Либо скрипт из репозитория: bash scripts/install_composer_deps.sh (из каталога backend/ или скопируйте скрипт рядом с composer.json).\n";
    exit;
}

try {
    $company = tp_company_pdf_settings();
    $pdf = tp_admin_estimate_pdf_render($r, $company);
    if ($pdf === null || $pdf === '') {
        throw new RuntimeException('Пустой PDF');
    }
} catch (Throwable $e) {
    error_log('admin request_pdf: ' . $e->getMessage());
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo 'Не удалось сформировать PDF. Проверьте логи сервера.';
    exit;
}

$eid = (int) ($r['estimate_id'] ?? 0);
$fn = 'smeta-' . $eid . '-zayavka-' . $requestId . '.pdf';
$fnSafe = preg_replace('/[^a-zA-Z0-9._-]+/', '_', $fn) ?: 'estimate.pdf';

header('Content-Type: application/pdf');
header('Content-Disposition: attachment; filename="' . $fnSafe . '"');
header('Cache-Control: no-store, private');
header('Pragma: no-cache');
echo $pdf;
