<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/include/mail_smtp.php';

function mail_campaign_config(): array
{
    static $cache = null;
    if ($cache !== null) {
        return $cache;
    }
    $root = dirname(__DIR__);
    $path = $root . '/config.php';
    if (!is_readable($path)) {
        throw new RuntimeException('Не найден config.php (скопируйте config.example.php → config.php)');
    }
    /** @var array $cache */
    $cache = require $path;
    $localPath = $root . '/config.local.php';
    if (is_readable($localPath)) {
        /** @var array $local */
        $local = require $localPath;
        $cache = array_replace_recursive($cache, $local);
    }
    return $cache;
}

function mail_campaign_pdo(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }
    $cfg = mail_campaign_config()['db'] ?? null;
    if (!is_array($cfg)) {
        throw new RuntimeException('В config.php нет секции db');
    }
    $host = (string) ($cfg['host'] ?? 'localhost');
    if ($host === 'localhost') {
        $host = '127.0.0.1';
    }
    $charset = $cfg['charset'] ?? 'utf8mb4';
    $socket = trim((string) ($cfg['unix_socket'] ?? ''));
    if ($socket !== '') {
        $dsn = sprintf('mysql:unix_socket=%s;dbname=%s;charset=%s', $socket, $cfg['name'], $charset);
    } else {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $host,
            (int) ($cfg['port'] ?? 3306),
            $cfg['name'],
            $charset
        );
    }
    try {
        $pdo = new PDO($dsn, $cfg['user'], $cfg['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    } catch (PDOException $e) {
        throw new RuntimeException(
            'Не удалось подключиться к MySQL (' . $e->getMessage() . '). '
            . 'На Mac для локального запуска: --storage=file --source=file:output/Поесть.txt '
            . 'или укажите хост БД хостинга в backend/public/config.local.php (не localhost).',
            0,
            $e
        );
    }
    return $pdo;
}

interface MailCampaignJournal
{
    /** @return array{subject: array<string, true>, body: array<string, true>} */
    public function loadUsedHashes(string $campaign): array;

    public function wasSent(string $campaign, string $email): bool;

    public function logSend(
        string $campaign,
        array $recipient,
        string $subject,
        string $subjectHash,
        string $bodyHash,
        string $status,
        ?string $error
    ): void;
}

final class MailCampaignDbJournal implements MailCampaignJournal
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function loadUsedHashes(string $campaign): array
    {
        $subject = [];
        $body = [];
        $st = $this->pdo->prepare(
            'SELECT subject_hash, body_hash FROM mail_campaign_log WHERE campaign = ?'
        );
        $st->execute([$campaign]);
        while ($row = $st->fetch()) {
            $subject[(string) $row['subject_hash']] = true;
            $body[(string) $row['body_hash']] = true;
        }
        return ['subject' => $subject, 'body' => $body];
    }

    public function wasSent(string $campaign, string $email): bool
    {
        $st = $this->pdo->prepare(
            "SELECT 1 FROM mail_campaign_log WHERE campaign = ? AND email = ? AND status = 'sent' LIMIT 1"
        );
        $st->execute([$campaign, strtolower($email)]);
        return (bool) $st->fetchColumn();
    }

    public function logSend(
        string $campaign,
        array $recipient,
        string $subject,
        string $subjectHash,
        string $bodyHash,
        string $status,
        ?string $error
    ): void {
        mail_campaign_log_send(
            $this->pdo,
            $campaign,
            $recipient,
            $subject,
            $subjectHash,
            $bodyHash,
            $status,
            $error
        );
    }
}

final class MailCampaignFileJournal implements MailCampaignJournal
{
    private string $dir;

    public function __construct(?string $dir = null)
    {
        $this->dir = $dir ?? dirname(__DIR__) . '/output/mail_campaign_logs';
        if (!is_dir($this->dir) && !mkdir($this->dir, 0755, true) && !is_dir($this->dir)) {
            throw new RuntimeException("Не удалось создать каталог: {$this->dir}");
        }
    }

    private function path(string $campaign): string
    {
        $safe = preg_replace('/[^a-zA-Z0-9_-]+/', '_', $campaign) ?? 'default';
        return $this->dir . '/' . $safe . '.json';
    }

    /** @return array{sent_emails: list<string>, subject_hashes: list<string>, body_hashes: list<string>} */
    private function read(string $campaign): array
    {
        $path = $this->path($campaign);
        if (!is_readable($path)) {
            return ['sent_emails' => [], 'subject_hashes' => [], 'body_hashes' => []];
        }
        $data = json_decode((string) file_get_contents($path), true);
        if (!is_array($data)) {
            return ['sent_emails' => [], 'subject_hashes' => [], 'body_hashes' => []];
        }
        return [
            'sent_emails' => array_values($data['sent_emails'] ?? []),
            'subject_hashes' => array_values($data['subject_hashes'] ?? []),
            'body_hashes' => array_values($data['body_hashes'] ?? []),
        ];
    }

    private function write(string $campaign, array $data): void
    {
        file_put_contents(
            $this->path($campaign),
            json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT)
        );
    }

    public function loadUsedHashes(string $campaign): array
    {
        $data = $this->read($campaign);
        $subject = [];
        $body = [];
        foreach ($data['subject_hashes'] as $h) {
            $subject[$h] = true;
        }
        foreach ($data['body_hashes'] as $h) {
            $body[$h] = true;
        }
        return ['subject' => $subject, 'body' => $body];
    }

    public function wasSent(string $campaign, string $email): bool
    {
        $data = $this->read($campaign);
        return in_array(strtolower($email), $data['sent_emails'], true);
    }

    public function logSend(
        string $campaign,
        array $recipient,
        string $subject,
        string $subjectHash,
        string $bodyHash,
        string $status,
        ?string $error
    ): void {
        $data = $this->read($campaign);
        $email = strtolower(trim((string) $recipient['email']));
        if ($status === 'sent' && !in_array($email, $data['sent_emails'], true)) {
            $data['sent_emails'][] = $email;
        }
        if (!in_array($subjectHash, $data['subject_hashes'], true)) {
            $data['subject_hashes'][] = $subjectHash;
        }
        if (!in_array($bodyHash, $data['body_hashes'], true)) {
            $data['body_hashes'][] = $bodyHash;
        }
        $this->write($campaign, $data);
    }
}

function mail_campaign_create_journal(string $storage, ?PDO $pdo = null): MailCampaignJournal
{
    if ($storage === 'file') {
        return new MailCampaignFileJournal();
    }
    if ($pdo === null) {
        $pdo = mail_campaign_pdo();
    }
    return new MailCampaignDbJournal($pdo);
}

/** @return true|string */
function mail_campaign_send_plain(string $to, string $subject, string $bodyText): bool|string
{
    return tp_mail_send_plain_with_config(mail_campaign_config(), $to, $subject, $bodyText);
}

/**
 * Разбор spintax: {вариант1|вариант2|...}
 */
function mail_campaign_expand_spintax(string $text, ?int $seed = null): string
{
    if ($seed !== null) {
        mt_srand($seed);
    }
    $limit = 200;
    while ($limit-- > 0 && preg_match('/\{([^{}]+)\}/', $text, $m)) {
        $parts = explode('|', $m[1]);
        $pick = $parts[array_rand($parts)];
        $text = substr_replace($text, $pick, (int) strpos($text, $m[0]), strlen($m[0]));
    }
    return preg_replace('/\s+/u', ' ', trim($text)) ?? trim($text);
}

final class MailUniqueTextGenerator
{
    /** @var list<string> */
    private array $usedSubjectHashes = [];
    /** @var list<string> */
    private array $usedBodyHashes = [];

    public function __construct(
        private readonly string $subjectTemplate,
        private readonly string $bodyTemplate,
        private readonly MailCampaignJournal $journal,
        private readonly string $campaign,
    ) {
        $hashes = $this->journal->loadUsedHashes($this->campaign);
        $this->usedSubjectHashes = $hashes['subject'];
        $this->usedBodyHashes = $hashes['body'];
    }

    /**
     * @param array{email: string, name?: ?string, address?: ?string, id?: int|string} $recipient
     * @return array{subject: string, body: string, subject_hash: string, body_hash: string}
     */
    public function generate(array $recipient): array
    {
        $email = strtolower(trim($recipient['email']));
        $name = trim((string) ($recipient['name'] ?? ''));
        $attempts = 0;

        do {
            $seed = crc32($email . '|' . $this->campaign . '|' . $attempts . '|' . microtime(true));
            $subject = $this->buildSubject($recipient, $seed);
            $body = $this->buildBody($recipient, $seed);
            $subjectHash = hash('sha256', mb_strtolower($subject, 'UTF-8'));
            $bodyHash = hash('sha256', $body);
            $attempts++;
        } while (
            $attempts < 80
            && (isset($this->usedSubjectHashes[$subjectHash]) || isset($this->usedBodyHashes[$bodyHash]))
        );

        if (isset($this->usedSubjectHashes[$subjectHash]) || isset($this->usedBodyHashes[$bodyHash])) {
            $token = substr(hash('sha256', $email . microtime(true)), 0, 8);
            $body .= "\n\n—\n(обращение №{$token})";
            $bodyHash = hash('sha256', $body);
        }

        $this->usedSubjectHashes[$subjectHash] = true;
        $this->usedBodyHashes[$bodyHash] = true;

        return [
            'subject' => $subject,
            'body' => $body,
            'subject_hash' => $subjectHash,
            'body_hash' => $bodyHash,
        ];
    }

    /** @param array{email: string, name?: ?string} $recipient */
    private function buildSubject(array $recipient, int $seed): string
    {
        $text = $this->applyPlaceholders($this->subjectTemplate, $recipient);
        return mail_campaign_expand_spintax($text, $seed);
    }

    /** @param array{email: string, name?: ?string, address?: ?string} $recipient */
    private function buildBody(array $recipient, int $seed): string
    {
        $text = $this->applyPlaceholders($this->bodyTemplate, $recipient);
        $text = str_replace('{ref_line}', '', $text);
        return mail_campaign_expand_spintax($text, $seed);
    }

    /** @param array{email: string, name?: ?string, address?: ?string} $recipient */
    private function applyPlaceholders(string $text, array $recipient): string
    {
        $name = trim((string) ($recipient['name'] ?? ''));
        $address = trim((string) ($recipient['address'] ?? ''));
        $nameSuffix = $name !== '' ? " «{$name}»" : '';
        $repl = [
            '{name}' => $name,
            '{email}' => $recipient['email'],
            '{address}' => $address,
            '{name_suffix}' => $nameSuffix,
            '{company}' => $name,
        ];
        $out = str_replace(array_keys($repl), array_values($repl), $text);
        return preg_replace("/\n{3,}/", "\n\n", $out) ?? $out;
    }
}

/**
 * @return list<array{id?: int|string, email: string, name?: ?string, address?: ?string}>
 */
function mail_campaign_fetch_recipients(
    string $source,
    bool $skipSent,
    string $campaign,
    ?int $limit,
    MailCampaignJournal $journal,
    ?PDO $pdo = null
): array {
    $rows = [];
    if (str_starts_with($source, 'file:')) {
        $path = substr($source, 5);
        if (!is_readable($path)) {
            throw new RuntimeException("Файл не найден: {$path}");
        }
        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
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
                } else {
                    $name = trim($meta);
                }
            }
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                continue;
            }
            $rows[] = [
                'email' => strtolower($email),
                'name' => $name ? trim($name) : null,
                'address' => $address ? trim($address) : null,
            ];
        }
    } elseif ($source === 'mail_leads') {
        if ($pdo === null) {
            throw new RuntimeException('Для source=mail_leads нужна БД (--storage=db)');
        }
        $sql = 'SELECT id, email, name, address FROM mail_leads ORDER BY id ASC';
        if ($limit !== null) {
            $sql .= ' LIMIT ' . (int) $limit;
        }
        $rows = $pdo->query($sql)->fetchAll();
    } elseif ($source === 'user_profiles') {
        if ($pdo === null) {
            throw new RuntimeException('Для source=user_profiles нужна БД (--storage=db)');
        }
        $sql = "SELECT id, email, TRIM(CONCAT_WS(' ', last_name, first_name, middle_name)) AS name
                FROM user_profiles
                WHERE email IS NOT NULL AND email <> ''";
        if ($limit !== null) {
            $sql .= ' LIMIT ' . (int) $limit;
        }
        $rows = $pdo->query($sql)->fetchAll();
    } else {
        throw new InvalidArgumentException(
            'source: file:путь, mail_leads или user_profiles'
        );
    }

    if (!$skipSent) {
        return $rows;
    }

    $filtered = [];
    foreach ($rows as $row) {
        $em = strtolower(trim((string) $row['email']));
        if ($em === '' || $journal->wasSent($campaign, $em)) {
            continue;
        }
        $filtered[] = $row;
    }
    if ($limit !== null && count($filtered) > $limit) {
        $filtered = array_slice($filtered, 0, $limit);
    }
    return $filtered;
}

function mail_campaign_log_send(
    PDO $pdo,
    string $campaign,
    array $recipient,
    string $subject,
    string $subjectHash,
    string $bodyHash,
    string $status,
    ?string $error
): void {
    $st = $pdo->prepare(
        'INSERT INTO mail_campaign_log
            (campaign, email, lead_id, subject, subject_hash, body_hash, status, error_message)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    );
    $leadId = isset($recipient['id']) ? (int) $recipient['id'] : null;
    $st->execute([
        $campaign,
        strtolower(trim((string) $recipient['email'])),
        $leadId > 0 ? $leadId : null,
        mb_substr($subject, 0, 500),
        $subjectHash,
        $bodyHash,
        $status,
        $error !== null ? mb_substr($error, 0, 512) : null,
    ]);
}
