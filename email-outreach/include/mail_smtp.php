<?php
declare(strict_types=1);

/**
 * Отправка через SMTP (SSL 465 / STARTTLS 587) или fallback на PHP mail().
 */

final class MailSmtpClient
{
    /** @var resource|null */
    private $socket = null;

    public function __construct(
        private readonly string $host,
        private readonly int $port,
        private readonly string $encryption,
        private readonly string $user,
        private readonly string $password,
        private readonly int $timeoutSec = 30,
        private readonly bool $verifyPeer = true,
    ) {
    }

    public function send(
        string $fromEmail,
        string $fromName,
        string $toEmail,
        string $subject,
        string $bodyText
    ): void {
        $this->connect();
        try {
            $this->initSession();
            $this->authLogin($this->user, $this->password);
            $from = $this->sanitizeEmail($fromEmail);
            $to = $this->sanitizeEmail($toEmail);
            $this->cmd("MAIL FROM:<{$from}>", [250]);
            $this->cmd("RCPT TO:<{$to}>", [250, 251]);
            $this->cmd('DATA', [354]);
            $this->writeMessage($from, $fromName, $to, $subject, $bodyText);
            $this->expect($this->read(), [250]);
            $this->cmd('QUIT', [221]);
        } finally {
            $this->disconnect();
        }
    }

    private function sslContext(): array
    {
        $ssl = [
            'peer_name' => $this->host,
            'SNI_enabled' => true,
            'verify_peer' => $this->verifyPeer,
            'verify_peer_name' => $this->verifyPeer,
            'allow_self_signed' => !$this->verifyPeer,
        ];
        $ca = (string) ini_get('openssl.cafile');
        if ($ca !== '' && is_readable($ca)) {
            $ssl['cafile'] = $ca;
        }
        $capath = (string) ini_get('openssl.capath');
        if ($capath !== '' && is_dir($capath)) {
            $ssl['capath'] = $capath;
        }
        return ['ssl' => $ssl];
    }

    private function connect(): void
    {
        $enc = strtolower($this->encryption);
        $ctx = stream_context_create($this->sslContext());

        if ($enc === 'ssl') {
            $remote = "ssl://{$this->host}:{$this->port}";
        } else {
            $remote = "tcp://{$this->host}:{$this->port}";
        }

        $fp = @stream_socket_client(
            $remote,
            $errno,
            $errstr,
            $this->timeoutSec,
            STREAM_CLIENT_CONNECT,
            $ctx
        );
        if ($fp === false) {
            $last = error_get_last();
            $detail = trim($errstr !== '' ? $errstr : (string) ($last['message'] ?? ''));
            if ($detail === '') {
                $detail = 'нет соединения (firewall, VPN или блокировка порта ' . $this->port . ')';
            }
            throw new RuntimeException("connect {$remote}: {$detail} ({$errno})");
        }
        stream_set_timeout($fp, $this->timeoutSec);
        $this->socket = $fp;
    }

    private function initSession(): void
    {
        $this->expect($this->read(), [220]);
        $this->cmd('EHLO ' . gethostname(), [250]);

        if (strtolower($this->encryption) === 'tls') {
            $this->cmd('STARTTLS', [220]);
            $methods = STREAM_CRYPTO_METHOD_TLS_CLIENT;
            if (defined('STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT')) {
                $methods |= STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT;
            }
            if (defined('STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT')) {
                $methods |= STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT;
            }
            $crypto = @stream_socket_enable_crypto($this->socket, true, $methods);
            if ($crypto !== true) {
                throw new RuntimeException('STARTTLS не удалось (crypto)');
            }
            $this->cmd('EHLO ' . gethostname(), [250]);
        }
    }

    private function disconnect(): void
    {
        if (is_resource($this->socket)) {
            @fclose($this->socket);
        }
        $this->socket = null;
    }

    private function authLogin(string $user, string $password): void
    {
        $this->cmd('AUTH LOGIN', [334]);
        $this->cmd(base64_encode($user), [334]);
        $this->cmd(base64_encode($password), [235]);
    }

    private function writeMessage(
        string $from,
        string $fromName,
        string $to,
        string $subject,
        string $bodyText
    ): void {
        $encSub = '=?UTF-8?B?' . base64_encode($subject) . '?=';
        $fromHeader = $fromName !== ''
            ? sprintf('=?UTF-8?B?%s?= <%s>', base64_encode($fromName), $from)
            : $from;

        $lines = [
            "From: {$fromHeader}",
            "To: {$to}",
            "Subject: {$encSub}",
            'MIME-Version: 1.0',
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
            'Date: ' . gmdate('D, d M Y H:i:s') . ' +0000',
            '',
            $this->dotStuff($bodyText),
        ];
        $payload = implode("\r\n", $lines);
        $this->writeRaw($payload . "\r\n.\r\n");
    }

    private function dotStuff(string $text): string
    {
        $text = str_replace(["\r\n", "\r"], "\n", $text);
        $out = [];
        foreach (explode("\n", $text) as $line) {
            if (str_starts_with($line, '.')) {
                $line = '.' . $line;
            }
            $out[] = $line;
        }
        return implode("\r\n", $out);
    }

    private function sanitizeEmail(string $email): string
    {
        $email = trim($email);
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Некорректный email');
        }
        return $email;
    }

    private function cmd(string $command, array $okCodes): void
    {
        $this->writeRaw($command . "\r\n");
        $this->expect($this->read(), $okCodes);
    }

    private function writeRaw(string $data): void
    {
        if (!is_resource($this->socket)) {
            throw new RuntimeException('SMTP socket closed');
        }
        $len = strlen($data);
        $written = 0;
        while ($written < $len) {
            $n = fwrite($this->socket, substr($data, $written));
            if ($n === false) {
                throw new RuntimeException('SMTP write failed');
            }
            $written += $n;
        }
    }

    private function read(): string
    {
        if (!is_resource($this->socket)) {
            throw new RuntimeException('SMTP socket closed');
        }
        $read = [$this->socket];
        $w = null;
        $e = null;
        if (@stream_select($read, $w, $e, $this->timeoutSec) !== 1) {
            throw new RuntimeException('SMTP: нет ответа сервера (таймаут)');
        }
        $data = '';
        while (!feof($this->socket)) {
            $line = fgets($this->socket, 8192);
            if ($line === false) {
                break;
            }
            $data .= $line;
            if (strlen($line) >= 4 && $line[3] === ' ') {
                break;
            }
        }
        return $data;
    }

    /** @param list<int> $okCodes */
    private function expect(string $response, array $okCodes): void
    {
        if ($response === '') {
            throw new RuntimeException('SMTP: пустой ответ сервера');
        }
        $code = (int) substr($response, 0, 3);
        if (!in_array($code, $okCodes, true)) {
            throw new RuntimeException('SMTP: ' . trim(preg_replace('/\s+/', ' ', $response) ?? $response));
        }
    }
}

/**
 * Отправка через curl (smtps://) — надёжнее на macOS, если PHP stream_socket_client не коннектится.
 *
 * @return true|string
 */
function tp_mail_send_via_curl(
    string $host,
    int $port,
    string $encryption,
    string $user,
    string $password,
    string $from,
    string $to,
    string $subject,
    string $bodyText,
    bool $verifyPeer = true
): bool|string {
    $curl = trim((string) shell_exec('command -v curl 2>/dev/null'));
    if ($curl === '') {
        $curl = 'curl';
    }
    if ($curl === '') {
        return 'curl не найден в PATH';
    }

    $scheme = strtolower($encryption) === 'tls' ? 'smtp' : 'smtps';
    $url = sprintf('%s://%s:%d', $scheme, $host, $port);

    $msg = "From: {$from}\r\n"
        . "To: {$to}\r\n"
        . 'Subject: =?UTF-8?B?' . base64_encode($subject) . "?=\r\n"
        . "MIME-Version: 1.0\r\n"
        . "Content-Type: text/plain; charset=UTF-8\r\n"
        . "Content-Transfer-Encoding: 8bit\r\n"
        . "\r\n"
        . str_replace(["\r\n", "\r"], "\n", $bodyText);

    $tmp = tempnam(sys_get_temp_dir(), 'tp_mail_');
    if ($tmp === false) {
        return 'Не удалось создать временный файл';
    }
    file_put_contents($tmp, $msg);

    $args = [
        $curl,
        '-sS',
        '--url', $url,
        '--user', $user . ':' . $password,
        '--mail-from', $from,
        '--mail-rcpt', $to,
        '--upload-file', $tmp,
        '--connect-timeout', '15',
        '--max-time', '90',
    ];
    if (strtolower($encryption) === 'tls' || $port === 587) {
        $args[] = '--ssl-reqd';
    }
    if (!$verifyPeer) {
        $args[] = '-k';
    }

    $cmd = '';
    foreach ($args as $a) {
        $cmd .= ($cmd === '' ? '' : ' ') . escapeshellarg($a);
    }
    $cmd .= ' 2>&1';

    $output = [];
    $code = 0;
    exec($cmd, $output, $code);
    @unlink($tmp);

    if ($code === 0) {
        return true;
    }
    $text = trim(implode("\n", $output));
    return $text !== '' ? 'curl: ' . $text : 'curl exit code ' . $code;
}

/**
 * @param array $config корень config.php (секция mail)
 * @return true|string
 */
function tp_mail_send_plain_with_config(array $config, string $to, string $subject, string $bodyText): bool|string
{
    $to = trim($to);
    if ($to === '' || !filter_var($to, FILTER_VALIDATE_EMAIL)) {
        return 'Некорректный адрес получателя';
    }

    $cfg = $config['mail'] ?? null;
    if (!is_array($cfg)) {
        return 'В config.php не задана секция mail';
    }

    $from = trim((string) ($cfg['from'] ?? ''));
    if ($from === '' || !filter_var($from, FILTER_VALIDATE_EMAIL)) {
        return 'Задайте mail.from в config.php';
    }
    $fromName = trim((string) ($cfg['from_name'] ?? ''));

    $smtp = $cfg['smtp'] ?? null;
    $password = trim((string) ($cfg['smtp_password'] ?? ''));
    if ($password === '') {
        $password = trim((string) (getenv('MAIL_SMTP_PASSWORD') ?: ''));
    }

    if (is_array($smtp) && trim((string) ($smtp['host'] ?? '')) !== '' && $password !== '') {
        $host = trim((string) $smtp['host']);
        $user = trim((string) ($smtp['user'] ?? $from));
        $timeout = (int) ($smtp['timeout'] ?? 30);
        $verifyPeer = !isset($smtp['verify_peer']) || (bool) $smtp['verify_peer'];

        $attempts = [
            [
                'port' => (int) ($smtp['port'] ?? 465),
                'encryption' => strtolower(trim((string) ($smtp['encryption'] ?? 'ssl'))) ?: 'ssl',
            ],
            ['port' => 587, 'encryption' => 'tls'],
            ['port' => 2525, 'encryption' => 'tls'],
        ];
        $transport = strtolower(trim((string) ($cfg['transport'] ?? 'auto')));
        $tryCurlFirst = $transport === 'curl'
            || ($transport === 'auto' && PHP_OS_FAMILY === 'Darwin');

        $seen = [];
        $errors = [];

        $tryCurl = static function (array $attemptList) use (
            &$errors,
            $host,
            $user,
            $password,
            $from,
            $to,
            $subject,
            $bodyText,
            $verifyPeer
        ): bool {
            foreach ($attemptList as $attempt) {
                $port = (int) $attempt['port'];
                $enc = (string) $attempt['encryption'];
                $curlResult = tp_mail_send_via_curl(
                    $host,
                    $port,
                    $enc,
                    $user,
                    $password,
                    $from,
                    $to,
                    $subject,
                    $bodyText,
                    $verifyPeer
                );
                if ($curlResult === true) {
                    return true;
                }
                $errors[] = "curl {$port}/{$enc}: {$curlResult}";
            }
            return false;
        };

        $tryPhpSmtp = static function (array $attemptList) use (
            &$errors,
            &$seen,
            $host,
            $user,
            $password,
            $from,
            $fromName,
            $to,
            $subject,
            $bodyText,
            $timeout,
            $verifyPeer
        ): bool {
            foreach ($attemptList as $attempt) {
                $port = (int) $attempt['port'];
                $enc = (string) $attempt['encryption'];
                $key = "{$port}/{$enc}";
                if (isset($seen[$key])) {
                    continue;
                }
                $seen[$key] = true;
                try {
                    $client = new MailSmtpClient(
                        $host,
                        $port,
                        $enc,
                        $user,
                        $password,
                        $timeout,
                        $verifyPeer
                    );
                    $client->send($from, $fromName, $to, $subject, $bodyText);
                    return true;
                } catch (Throwable $e) {
                    $errors[] = "php {$port}/{$enc}: " . $e->getMessage();
                }
            }
            return false;
        };

        if ($transport === 'curl') {
            if ($tryCurl($attempts)) {
                return true;
            }
            return 'SMTP: ' . implode('; ', $errors);
        }

        if ($tryCurlFirst && $tryCurl($attempts)) {
            return true;
        }
        if ($transport !== 'curl' && $tryPhpSmtp($attempts)) {
            return true;
        }
        if (!$tryCurlFirst && $tryCurl($attempts)) {
            return true;
        }

        return 'SMTP: ' . implode('; ', $errors);
    }

    $fromHeader = $fromName !== ''
        ? sprintf('"%s" <%s>', str_replace('"', '', $fromName), $from)
        : $from;
    $encSub = '=?UTF-8?B?' . base64_encode($subject) . '?=';
    $headers = [
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
        'From: ' . $fromHeader,
    ];
    $headersStr = implode("\r\n", $headers);
    if (PHP_OS_FAMILY === 'Windows') {
        $ok = @mail($to, $encSub, $bodyText, $headersStr);
    } else {
        $ok = @mail($to, $encSub, $bodyText, $headersStr, '-f' . $from);
    }

    return $ok ? true : 'mail() вернула false (настройте mail.smtp в config.local.php)';
}
