#!/usr/bin/env php
<?php
/**
 * Проверка SMTP Rambler.
 *
 *   В config.local.php: 'mail' => ['smtp_password' => 'пароль_ящика']
 *   или: export MAIL_SMTP_PASSWORD='пароль'
 *
 *   php scripts/test_mail_smtp.php qwerti60641@gmail.com
 */
declare(strict_types=1);

require_once __DIR__ . '/../lib/mail_campaign_lib.php';

$to = $argv[1] ?? 'qwerti60641@gmail.com';
$cfg = mail_campaign_config();
$smtp = $cfg['mail']['smtp'] ?? [];
$hasPass = trim((string) ($cfg['mail']['smtp_password'] ?? '')) !== ''
    || trim((string) (getenv('MAIL_SMTP_PASSWORD') ?: '')) !== '';

fwrite(STDERR, 'SMTP: ' . ($smtp['host'] ?? '?') . ':' . ($smtp['port'] ?? '?') . ' ' . ($smtp['encryption'] ?? '') . "\n");
fwrite(STDERR, 'From: ' . ($cfg['mail']['from'] ?? '?') . "\n");
fwrite(STDERR, 'Transport: ' . ($cfg['mail']['transport'] ?? 'auto') . "\n");
fwrite(STDERR, 'Пароль: ' . ($hasPass ? 'задан' : 'НЕ ЗАДАН') . "\n\n");

$result = mail_campaign_send_plain(
    $to,
    'Тест SMTP Rambler — разработка сайтов и приложений',
    "Добрый день!\n\nЭто тестовое письмо через smtp.rambler.ru:465 (SSL).\n\nTelegram: http://t.me/app154\nMax: +7 913 914 29 94\n"
);

if ($result === true) {
    fwrite(STDERR, "OK — письмо отправлено на {$to}\n");
    exit(0);
}

fwrite(STDERR, "Ошибка: {$result}\n\n");
if (str_contains((string) $result, 'timeout') || str_contains((string) $result, '(28)')) {
    fwrite(STDERR, "Похоже, с этого Mac/сети заблокирован исходящий SMTP (465/587).\n");
    fwrite(STDERR, "1) Проверка портов: php scripts/check_smtp_ports.php\n");
    fwrite(STDERR, "2) Другая сеть (раздача с телефона) или отключите VPN\n");
    fwrite(STDERR, "3) Запуск на хостинге по SSH:\n");
    fwrite(STDERR, "   cd email-outreach && php scripts/test_mail_smtp.php {$to}\n");
    fwrite(STDERR, "   (на сервере в config.local.php лучше transport => auto или curl)\n");
}
exit(1);
