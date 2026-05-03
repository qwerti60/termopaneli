<?php
declare(strict_types=1);

/**
 * Подключение конфигурации и PDO для API tp_api.
 * Ожидается backend/public/config.php с ключом db (как в config.example.php).
 */
function tp_apply_cors_headers(): void
{
    $origin = (string) ($_SERVER['HTTP_ORIGIN'] ?? '');
    if ($origin !== '') {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
    }
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Accept, Authorization');
    header('Access-Control-Max-Age: 86400');
}

tp_apply_cors_headers();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function tp_config(): array
{
    static $cache = null;
    if ($cache !== null) {
        return $cache;
    }
    $path = dirname(__DIR__) . '/config.php';
    if (!is_readable($path)) {
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['error' => 'config.php не найден'], JSON_UNESCAPED_UNICODE);
        exit;
    }
    /** @var array $cache */
    $cache = require $path;
    return $cache;
}

function tp_pdo(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }
    $cfg = tp_config()['db'] ?? null;
    if (!is_array($cfg)) {
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['error' => 'Нет настроек db в config'], JSON_UNESCAPED_UNICODE);
        exit;
    }
    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=%s',
        $cfg['host'],
        (int) $cfg['port'],
        $cfg['name'],
        $cfg['charset'] ?? 'utf8mb4'
    );
    $pdo = new PDO($dsn, $cfg['user'], $cfg['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    return $pdo;
}

function tp_json_response(int $status, array $payload): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
}

/**
 * Нормализация телефона к виду 7XXXXXXXXXX.
 */
function tp_normalize_phone(string $raw): ?string
{
    $d = preg_replace('/\D/', '', $raw);
    if ($d === '') {
        return null;
    }
    if (strlen($d) === 11 && ($d[0] === '7' || $d[0] === '8')) {
        return '7' . substr($d, 1);
    }
    if (strlen($d) === 10) {
        return '7' . $d;
    }
    return null;
}

function tp_bearer_token(): ?string
{
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['Authorization'] ?? '';
    if (preg_match('/Bearer\s+(\S+)/i', $h, $m)) {
        return $m[1];
    }
    // Fallback для хостингов, где Authorization не передается в PHP.
    $queryToken = isset($_GET['token']) ? trim((string) $_GET['token']) : '';
    if ($queryToken !== '') {
        return $queryToken;
    }
    return null;
}
