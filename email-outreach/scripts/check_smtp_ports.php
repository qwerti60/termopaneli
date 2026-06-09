#!/usr/bin/env php
<?php
/**
 * Проверка доступности портов SMTP Rambler с этой машины.
 *   php scripts/check_smtp_ports.php
 */
declare(strict_types=1);

$host = $argv[1] ?? 'smtp.rambler.ru';
$ports = [465, 587, 2525, 25];
$timeout = 5;

fwrite(STDERR, "Проверка TCP до {$host} (таймаут {$timeout} сек)…\n\n");

$anyOk = false;
foreach ($ports as $port) {
    $errno = 0;
    $errstr = '';
    $start = microtime(true);
    $fp = @fsockopen($host, $port, $errno, $errstr, $timeout);
    $ms = (int) round((microtime(true) - $start) * 1000);
    if (is_resource($fp)) {
        fclose($fp);
        echo sprintf("  %d  OK  (%d ms)\n", $port, $ms);
        $anyOk = true;
    } else {
        echo sprintf("  %d  FAIL  %s (%d)\n", $port, $errstr !== '' ? $errstr : 'timeout', $errno);
    }
}

fwrite(STDERR, "\n");
if (!$anyOk) {
    fwrite(STDERR, "Ни один порт не доступен — провайдер или firewall блокирует исходящий SMTP.\n");
    fwrite(STDERR, "Решение: запускайте рассылку на хостинге по SSH (там порты обычно открыты).\n");
    exit(1);
}

fwrite(STDERR, "TCP доступен. Если curl/php всё равно таймаут — проблема на этапе SSL (VPN, антивирус).\n");
fwrite(STDERR, "Попробуйте: php scripts/test_mail_smtp.php test@example.com\n");
exit(0);
