<?php
declare(strict_types=1);

/**
 * Простая отправка письма (PHP mail). Настройте в config.php секцию mail (см. config.example.php).
 *
 * @return true|string ошибка
 */
function tp_admin_mail_send_plain(string $to, string $subject, string $bodyText): bool|string
{
    $to = trim($to);
    if ($to === '' || !filter_var($to, FILTER_VALIDATE_EMAIL)) {
        return 'Некорректный адрес получателя';
    }
    $cfg = tp_config()['mail'] ?? [];
    if (!is_array($cfg)) {
        return 'В config.php не задана секция mail';
    }
    $from = trim((string) ($cfg['from'] ?? ''));
    if ($from === '' || !filter_var($from, FILTER_VALIDATE_EMAIL)) {
        return 'В config.php задайте mail.from (валидный email отправителя)';
    }
    $fromName = trim((string) ($cfg['from_name'] ?? 'Admin'));
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

    return $ok ? true : 'Функция mail() вернула false (проверьте sendmail/exim на сервере)';
}
