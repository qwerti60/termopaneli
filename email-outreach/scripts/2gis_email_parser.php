#!/usr/bin/env php
<?php
/**
 * Сбор email организаций из рубрики 2ГИС по ссылке вида:
 * https://2gis.ru/tyumen/search/%D0%9F%D0%BE%D0%B5%D1%81%D1%82%D1%8C?m=65.544151%2C57.159738%2F11
 *
 * Использует Catalog API 2ГИС (тот же ключ, что и веб-клиент 2gis.ru).
 *
 * Запуск:
 *   php scripts/2gis_email_parser.php 'https://2gis.ru/tyumen/search/...'
 *   php scripts/2gis_email_parser.php '...' --output-dir=./output
 *   php scripts/2gis_email_parser.php '...' --key=YOUR_KEY
 *
 * Результат: файл <рубрика>.txt в каталоге output (по одному email на строку).
 */

declare(strict_types=1);

const DEFAULT_API_KEY = 'ruregt3044';
const CATALOG_API_BASE = 'https://catalog.api.2gis.ru/3.0/items';
const USER_AGENT = 'Mozilla/5.0 (compatible; 2gis-email-parser/1.0)';
const DEFAULT_PAGE_SIZE = 50;
const MAX_PAGE_SIZE = 50;

/** slug из URL → название для поискового запроса */
const CITY_SLUG_NAMES = [
    'tyumen' => 'Тюмень',
    'moscow' => 'Москва',
    'spb' => 'Санкт-Петербург',
    'saint-petersburg' => 'Санкт-Петербург',
    'novosibirsk' => 'Новосибирск',
    'ekaterinburg' => 'Екатеринбург',
    'kazan' => 'Казань',
];

function usage(): void
{
    $self = basename(__FILE__);
    fwrite(STDERR, <<<TXT
Использование:
  php {$self} <url_рубрики_2gis> [опции]

Опции:
  --output-dir=DIR     Каталог для файла (по умолчанию: ./output)
  --key=KEY            API-ключ 2ГИС (или переменная DGIS_API_KEY)
  --page-size=N        Размер страницы, макс. 50 (по умолчанию: 50)
  --max-pages=N        Ограничить число страниц (для теста)
  --delay-ms=N         Пауза между запросами в мс (по умолчанию: 300)
  --with-meta          Добавить в строку название и адрес через таб

TXT);
    exit(1);
}

/** @return array<string, string> */
function parseArgs(array $argv): array
{
    $opts = [
        'url' => '',
        'output-dir' => __DIR__ . '/../output',
        'key' => getenv('DGIS_API_KEY') ?: DEFAULT_API_KEY,
        'page-size' => (string) DEFAULT_PAGE_SIZE,
        'max-pages' => '',
        'delay-ms' => '300',
        'with-meta' => '0',
    ];

    foreach (array_slice($argv, 1) as $arg) {
        if ($arg === '--with-meta') {
            $opts['with-meta'] = '1';
            continue;
        }
        if (str_starts_with($arg, '--')) {
            if (!preg_match('/^--([a-z-]+)=(.*)$/', $arg, $m)) {
                fwrite(STDERR, "Неизвестный аргумент: {$arg}\n");
                usage();
            }
            $key = $m[1];
            if (!array_key_exists($key, $opts) && $key !== 'url') {
                fwrite(STDERR, "Неизвестная опция: --{$key}\n");
                usage();
            }
            $opts[$key] = $m[2];
            continue;
        }
        if ($opts['url'] === '') {
            $opts['url'] = $arg;
        } else {
            fwrite(STDERR, "Лишний аргумент: {$arg}\n");
            usage();
        }
    }

    if ($opts['url'] === '') {
        usage();
    }

    return $opts;
}

function httpGet(string $url, int $timeoutSec = 45): string
{
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT => $timeoutSec,
            CURLOPT_HTTPHEADER => [
                'User-Agent: ' . USER_AGENT,
                'Accept: application/json, text/html;q=0.9',
                'Accept-Language: ru-RU,ru;q=0.9',
            ],
        ]);
        $body = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err = curl_error($ch);
        if ($body === false) {
            throw new RuntimeException("HTTP ошибка: {$err}");
        }
        if ($code >= 400) {
            throw new RuntimeException("HTTP {$code} для {$url}");
        }
        return (string) $body;
    }

    $ctx = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => "User-Agent: " . USER_AGENT . "\r\nAccept: application/json\r\n",
            'timeout' => $timeoutSec,
        ],
    ]);
    $body = @file_get_contents($url, false, $ctx);
    if ($body === false) {
        throw new RuntimeException("Не удалось загрузить: {$url}");
    }
    return $body;
}

/** @return array{city_slug: string, query: string, location: ?string} */
function parseRubricUrl(string $url): array
{
    $parts = parse_url($url);
    if ($parts === false || empty($parts['host']) || !str_contains($parts['host'], '2gis')) {
        throw new InvalidArgumentException('Ожидается ссылка на 2gis.ru / 2gis.com');
    }

    $path = trim($parts['path'] ?? '', '/');
    $segments = $path !== '' ? explode('/', $path) : [];
    if (count($segments) < 3 || $segments[1] !== 'search') {
        throw new InvalidArgumentException('Поддерживаются ссылки вида /{город}/search/{запрос}');
    }

    $citySlug = $segments[0];
    $query = rawurldecode($segments[2]);

    $location = null;
    if (!empty($parts['query'])) {
        parse_str($parts['query'], $qs);
        if (!empty($qs['m'])) {
            $m = is_array($qs['m']) ? $qs['m'][0] : $qs['m'];
            if (preg_match('/^([\d.+-]+),([\d.+-]+)/', (string) $m, $mm)) {
                $location = $mm[1] . ',' . $mm[2];
            }
        }
    }

    return [
        'city_slug' => $citySlug,
        'query' => $query,
        'location' => $location,
    ];
}

/** @return array{query: string, city: string, rubric: string} */
function parseSearchPageMeta(string $html, string $fallbackQuery, string $citySlug): array
{
    $rubric = $fallbackQuery;
    $city = CITY_SLUG_NAMES[$citySlug] ?? $citySlug;

    if (preg_match('/<title>([^<]+)<\/title>/u', $html, $m)) {
        $title = html_entity_decode($m[1], ENT_QUOTES | ENT_HTML5, 'UTF-8');
        if (preg_match('/^(.+?)\s+в\s+(.+?)\s+на карте/u', $title, $tm)) {
            $rubric = trim($tm[1]);
            if (!isset(CITY_SLUG_NAMES[$citySlug])) {
                $city = trim($tm[2]);
            }
        }
    }

    $searchQuery = trim($city . ' ' . $rubric);

    return [
        'query' => $searchQuery,
        'city' => $city,
        'rubric' => $rubric,
    ];
}

function sanitizeFilename(string $name): string
{
    $name = trim($name);
    $name = preg_replace('/[\\\\\\/:*?"<>|]+/u', '_', $name) ?? $name;
    $name = preg_replace('/\s+/u', ' ', $name) ?? $name;
    if ($name === '') {
        $name = 'rubrika';
    }
    return $name . '.txt';
}

/** @return list<string> */
function extractEmailsFromItem(array $item): array
{
    $found = [];
    foreach ($item['contact_groups'] ?? [] as $group) {
        foreach ($group['contacts'] ?? [] as $contact) {
            if (($contact['type'] ?? '') !== 'email') {
                continue;
            }
            $value = trim((string) ($contact['value'] ?? $contact['text'] ?? ''));
            if ($value !== '' && filter_var($value, FILTER_VALIDATE_EMAIL)) {
                $found[] = strtolower($value);
            }
        }
    }
    return $found;
}

/**
 * @return array{items: list<array>, total: int, code: int}
 */
function fetchCatalogPage(
    string $searchQuery,
    ?string $location,
    int $page,
    int $pageSize,
    string $apiKey
): array {
    $params = [
        'q' => $searchQuery,
        'page' => (string) $page,
        'page_size' => (string) $pageSize,
        'type' => 'branch',
        'key' => $apiKey,
        'fields' => 'items.contact_groups,items.name,items.address_name',
    ];
    if ($location !== null) {
        $params['location'] = $location;
    }

    $url = CATALOG_API_BASE . '?' . http_build_query($params);
    $raw = httpGet($url);
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        throw new RuntimeException('Некорректный JSON от Catalog API');
    }

    $code = (int) ($data['meta']['code'] ?? 0);
    if ($code !== 200) {
        $msg = $data['meta']['error']['message'] ?? 'неизвестная ошибка';
        throw new RuntimeException("Catalog API: {$msg} (code {$code})");
    }

    $result = $data['result'] ?? [];

    return [
        'items' => $result['items'] ?? [],
        'total' => (int) ($result['total'] ?? 0),
        'code' => $code,
    ];
}

function main(array $argv): int
{
    $opts = parseArgs($argv);
    $url = $opts['url'];
    $outputDir = rtrim($opts['output-dir'], '/');
    $apiKey = $opts['key'];
    $pageSize = min(MAX_PAGE_SIZE, max(1, (int) $opts['page-size']));
    $maxPages = $opts['max-pages'] !== '' ? max(1, (int) $opts['max-pages']) : null;
    $delayMs = max(0, (int) $opts['delay-ms']);
    $withMeta = $opts['with-meta'] === '1';

    if (!is_dir($outputDir) && !mkdir($outputDir, 0755, true) && !is_dir($outputDir)) {
        throw new RuntimeException("Не удалось создать каталог: {$outputDir}");
    }

    $parsed = parseRubricUrl($url);
    fwrite(STDERR, "Загрузка страницы рубрики для уточнения запроса...\n");
    $html = httpGet($url);
    $meta = parseSearchPageMeta($html, $parsed['query'], $parsed['city_slug']);

    fwrite(STDERR, "Рубрика: {$meta['rubric']}\n");
    fwrite(STDERR, "Город: {$meta['city']}\n");
    fwrite(STDERR, "Поисковый запрос API: {$meta['query']}\n");
    if ($parsed['location'] !== null) {
        fwrite(STDERR, "Точка на карте: {$parsed['location']}\n");
    }

    $filename = sanitizeFilename($meta['rubric']);
    $outPath = $outputDir . '/' . $filename;

    /** @var array<string, string> $lines email => line */
    $lines = [];
    $orgsWithEmail = 0;
    $orgsTotal = 0;
    $page = 1;
    $total = null;

    while (true) {
        if ($maxPages !== null && $page > $maxPages) {
            break;
        }

        fwrite(STDERR, "Страница {$page}...\n");
        $batch = fetchCatalogPage($meta['query'], $parsed['location'], $page, $pageSize, $apiKey);
        $items = $batch['items'];
        if ($total === null) {
            $total = $batch['total'];
            $pagesNeeded = (int) ceil($total / $pageSize);
            fwrite(STDERR, "Всего организаций в рубрике: {$total}, страниц: {$pagesNeeded}\n");
        }

        if ($items === []) {
            break;
        }

        foreach ($items as $item) {
            $orgsTotal++;
            $emails = extractEmailsFromItem($item);
            if ($emails === []) {
                continue;
            }
            $orgsWithEmail++;
            $name = trim((string) ($item['name'] ?? ''));
            $address = trim((string) ($item['address_name'] ?? ''));
            foreach ($emails as $email) {
                if (isset($lines[$email])) {
                    continue;
                }
                if ($withMeta) {
                    $lines[$email] = $email . "\t" . $name . ($address !== '' ? ' | ' . $address : '');
                } else {
                    $lines[$email] = $email;
                }
            }
        }

        $loaded = $page * $pageSize;
        if ($loaded >= $total) {
            break;
        }

        $page++;
        if ($delayMs > 0) {
            usleep($delayMs * 1000);
        }
    }

    ksort($lines);
    file_put_contents($outPath, implode("\n", $lines) . ($lines !== [] ? "\n" : ''));

    fwrite(STDERR, "Готово.\n");
    fwrite(STDERR, "Организаций обработано: {$orgsTotal}\n");
    fwrite(STDERR, "С email: {$orgsWithEmail}\n");
    fwrite(STDERR, "Уникальных email: " . count($lines) . "\n");
    fwrite(STDERR, "Файл: {$outPath}\n");

    return 0;
}

try {
    exit(main($argv));
} catch (Throwable $e) {
    fwrite(STDERR, 'Ошибка: ' . $e->getMessage() . "\n");
    exit(2);
}
