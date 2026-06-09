<?php
/**
 * Скопируйте в config.php. Не коммитьте config.php и config.local.php.
 */
declare(strict_types=1);

return [
    /** Нужна только для --source=mail_leads; для file:... можно не заполнять */
    'db' => [
        'host' => '127.0.0.1',
        'port' => 3306,
        'name' => 'mail_outreach',
        'user' => 'root',
        'pass' => '',
        'charset' => 'utf8mb4',
    ],
    'mail' => [
        'from' => 'bityugovkarl@rambler.ru',
        'from_name' => 'Разработка сайтов и приложений',
        /** auto | curl | smtp (только PHP SMTP) */
        'transport' => 'auto',
        'smtp_password' => '',
        'smtp' => [
            'host' => 'smtp.rambler.ru',
            'port' => 465,
            'encryption' => 'ssl',
            'user' => 'bityugovkarl@rambler.ru',
            'timeout' => 30,
            'verify_peer' => true,
        ],
    ],
];
