#!/usr/bin/env php
<?php
/**
 * Импорт email из файла (например output/Поесть.txt) в таблицу mail_leads.
 *
 *   php scripts/import_mail_leads.php output/Поесть.txt --source=2gis:Поесть
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/mail_campaign_lib.php';

function usage(): void
{
    fwrite(STDERR, "Использование: php import_mail_leads.php <файл> [--source=метка]\n");
    exit(1);
}

$argv = $GLOBALS['argv'] ?? [];
$file = '';
$source = 'import';
foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--source=')) {
        $source = substr($arg, 9);
        continue;
    }
    if ($file === '') {
        $file = $arg;
    }
}
if ($file === '' || !is_readable($file)) {
    usage();
}

$pdo = mail_campaign_pdo();
$lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$inserted = 0;
$skipped = 0;

$st = $pdo->prepare(
    'INSERT INTO mail_leads (email, name, address, source)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       name = COALESCE(VALUES(name), name),
       address = COALESCE(VALUES(address), address),
       source = COALESCE(VALUES(source), source)'
);

foreach ($lines as $line) {
    $line = trim($line);
    if ($line === '' || str_starts_with($line, '#')) {
        continue;
    }
    $email = $line;
    $name = null;
    $address = null;
    if (str_contains($line, "\t")) {
        [$email, $meta] = explode("\t", $line, 2);
        $email = trim($email);
        if (str_contains($meta, ' | ')) {
            [$name, $address] = explode(' | ', $meta, 2);
            $name = trim($name);
            $address = trim($address);
        } else {
            $name = trim($meta);
        }
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $skipped++;
        continue;
    }
    $st->execute([strtolower($email), $name ?: null, $address ?: null, $source]);
    if ($st->rowCount() === 1) {
        $inserted++;
    } else {
        $skipped++;
    }
}

fwrite(STDERR, "Добавлено новых: {$inserted}, пропущено/обновлено: {$skipped}\n");
exit(0);
