#!/usr/bin/env php
<?php
/**
 * Рассылка писем по выбранной базе/файлу.
 * Для каждого получателя — уникальные тема и текст (spintax + проверка по журналу).
 * Пауза между письмами: случайно от 3 до 30 секунд.
 *
 * Подготовка:
 *   mysql ... < sql/migrate_mail_leads.sql
 *   php scripts/import_mail_leads.php output/Поесть.txt --source=2gis:Поесть
 *   config.example.php → config.php, пароль в config.local.php
 *
 * Запуск (из каталога email-outreach):
 *   php scripts/mail_campaign_send.php \
 *     --source=mail_leads \
 *     --subject-template=templates/example_subject.txt \
 *     --body-template=templates/example_body.txt \
 *     --campaign=poest-2026 \
 *     --dry-run
 *
 *   php scripts/mail_campaign_send.php ... --yes
 *
 * Локально на Mac (без MySQL на компьютере):
 *   php scripts/mail_campaign_send.php \
 *     --storage=file \
 *     --source=file:output/Поесть.txt \
 *     --subject-template=templates/cafe_restaurant_subject.txt \
 *     --body-template=templates/cafe_restaurant_body.txt \
 *     --campaign=poest-2026 --limit=3
 */

declare(strict_types=1);

require_once __DIR__ . '/../lib/mail_campaign_lib.php';

function usage(): void
{
    $self = basename(__FILE__);
    fwrite(STDERR, <<<TXT
Использование:
  php {$self} [опции]

Обязательно:
  --subject-template=FILE   Шаблон темы (spintax: {вариант1|вариант2})
  --body-template=FILE      Шаблон текста письма

Источник получателей (--source):
  mail_leads              таблица mail_leads (нужен --storage=db)
  user_profiles           email из user_profiles (нужен --storage=db)
  file:output/Поесть.txt  текстовый файл (как у парсера 2ГИС)

Опции:
  --storage=db|file       Журнал отправок: MySQL или файлы в output/mail_campaign_logs/
  --campaign=NAME         Имя кампании для журнала (по умолчанию: default)
  --skip-sent             Не слать повторно на email со статусом sent в этой кампании
  --limit=N               Максимум писем за запуск
  --min-delay=3           Мин. пауза между письмами, сек (по умолчанию: 3)
  --max-delay=30          Макс. пауза, сек (по умолчанию: 30)
  --dry-run               Только показать, без отправки
  --yes                   Подтвердить реальную отправку (без --yes только dry-run)

Плейсхолдеры в шаблоне: {name}, {email}, {address}, {company}, {name_suffix}

TXT);
    exit(1);
}

/** @return array<string, string> */
function parseOpts(array $argv): array
{
    $opts = [
        'source' => 'mail_leads',
        'storage' => 'db',
        'subject-template' => '',
        'body-template' => '',
        'campaign' => 'default',
        'skip-sent' => '1',
        'limit' => '',
        'min-delay' => '3',
        'max-delay' => '30',
        'dry-run' => '0',
        'yes' => '0',
    ];

    foreach (array_slice($argv, 1) as $arg) {
        if ($arg === '--dry-run') {
            $opts['dry-run'] = '1';
            continue;
        }
        if ($arg === '--yes') {
            $opts['yes'] = '1';
            continue;
        }
        if ($arg === '--skip-sent') {
            $opts['skip-sent'] = '1';
            continue;
        }
        if ($arg === '--no-skip-sent') {
            $opts['skip-sent'] = '0';
            continue;
        }
        if (preg_match('/^--([a-z-]+)=(.*)$/', $arg, $m)) {
            if (!array_key_exists($m[1], $opts)) {
                fwrite(STDERR, "Неизвестная опция: --{$m[1]}\n");
                usage();
            }
            $opts[$m[1]] = $m[2];
        } else {
            fwrite(STDERR, "Лишний аргумент: {$arg}\n");
            usage();
        }
    }

    if ($opts['subject-template'] === '' || $opts['body-template'] === '') {
        fwrite(STDERR, "Укажите --subject-template и --body-template\n");
        usage();
    }
    if (!in_array($opts['storage'], ['db', 'file'], true)) {
        fwrite(STDERR, "--storage должен быть db или file\n");
        usage();
    }
    if ($opts['storage'] === 'file' && !str_starts_with($opts['source'], 'file:')) {
        fwrite(STDERR, "Для --storage=file укажите --source=file:путь/к/emails.txt\n");
        usage();
    }

    return $opts;
}

function readTemplate(string $path): string
{
    if (!is_readable($path)) {
        throw new RuntimeException("Шаблон не найден: {$path}");
    }
    return trim((string) file_get_contents($path));
}

function main(array $argv): int
{
    $opts = parseOpts($argv);
    $dryRun = $opts['dry-run'] === '1' || $opts['yes'] !== '1';
    if ($opts['yes'] !== '1' && $opts['dry-run'] !== '1') {
        fwrite(STDERR, "Без --yes включён режим dry-run. Добавьте --yes для отправки.\n");
        $dryRun = true;
    }

    $minDelay = max(1, (int) $opts['min-delay']);
    $maxDelay = max($minDelay, (int) $opts['max-delay']);
    $limit = $opts['limit'] !== '' ? max(1, (int) $opts['limit']) : null;
    $skipSent = $opts['skip-sent'] === '1';

    $subjectTpl = readTemplate($opts['subject-template']);
    $bodyTpl = readTemplate($opts['body-template']);

    $pdo = null;
    if ($opts['storage'] === 'db') {
        $pdo = mail_campaign_pdo();
    }
    $journal = mail_campaign_create_journal($opts['storage'], $pdo);
    $generator = new MailUniqueTextGenerator(
        $subjectTpl,
        $bodyTpl,
        $journal,
        $opts['campaign']
    );

    $recipients = mail_campaign_fetch_recipients(
        $opts['source'],
        $skipSent,
        $opts['campaign'],
        $limit,
        $journal,
        $pdo
    );

    $total = count($recipients);
    fwrite(STDERR, "Кампания: {$opts['campaign']}\n");
    fwrite(STDERR, "Хранилище: {$opts['storage']}\n");
    fwrite(STDERR, "Источник: {$opts['source']}\n");
    fwrite(STDERR, "Получателей: {$total}\n");
    fwrite(STDERR, $dryRun ? "Режим: dry-run (письма не отправляются)\n" : "Режим: отправка\n");
    fwrite(STDERR, "Пауза между письмами: {$minDelay}–{$maxDelay} сек.\n\n");

    if ($total === 0) {
        fwrite(STDERR, "Нет получателей для рассылки.\n");
        return 0;
    }

    $sent = 0;
    $failed = 0;

    foreach ($recipients as $i => $recipient) {
        $n = $i + 1;
        $email = strtolower(trim((string) $recipient['email']));
        $generated = $generator->generate($recipient);

        fwrite(STDERR, "[{$n}/{$total}] {$email}\n");
        fwrite(STDERR, "  Тема: {$generated['subject']}\n");

        if ($dryRun) {
            fwrite(STDERR, "  Текст (начало): " . mb_substr(str_replace("\n", ' ', $generated['body']), 0, 120) . "…\n");
            continue;
        }

        $result = mail_campaign_send_plain($email, $generated['subject'], $generated['body']);
        if ($result === true) {
            $journal->logSend(
                $opts['campaign'],
                $recipient,
                $generated['subject'],
                $generated['subject_hash'],
                $generated['body_hash'],
                'sent',
                null
            );
            $sent++;
            fwrite(STDERR, "  OK\n");
        } else {
            $journal->logSend(
                $opts['campaign'],
                $recipient,
                $generated['subject'],
                $generated['subject_hash'],
                $generated['body_hash'],
                'failed',
                (string) $result
            );
            $failed++;
            fwrite(STDERR, "  Ошибка: {$result}\n");
        }

        if ($n < $total) {
            $pause = random_int($minDelay, $maxDelay);
            fwrite(STDERR, "  Пауза {$pause} сек…\n");
            sleep($pause);
        }
    }

    fwrite(STDERR, "\nИтого: отправлено {$sent}, ошибок {$failed}\n");
    return $failed > 0 ? 1 : 0;
}

try {
    exit(main($argv));
} catch (Throwable $e) {
    fwrite(STDERR, 'Ошибка: ' . $e->getMessage() . "\n");
    exit(2);
}
