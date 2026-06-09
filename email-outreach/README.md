# Email outreach (2ГИС + рассылка)

Отдельный инструмент: сбор email из рубрик [2ГИС](https://2gis.ru) и рассылка писем. **Не связан с приложением «Термопанели».**

## Структура

```
email-outreach/
  config.example.php    → скопировать в config.php
  config.local.php      → пароль SMTP (не в git)
  sql/                  → таблицы mail_leads, mail_campaign_log
  scripts/              → парсер, импорт, рассылка, тест SMTP
  templates/            → шаблоны писем (spintax)
  output/               → списки email и журнал отправок
  include/mail_smtp.php
  lib/
```

## Быстрый старт

```bash
cd email-outreach
cp config.example.php config.php
# пароль: config.local.php (см. config.local.php.example)

# 1. Сбор email из рубрики 2ГИС
php scripts/2gis_email_parser.php 'https://2gis.ru/tyumen/search/...'

# 2. (опционально) импорт в MySQL
mysql ... < sql/migrate_mail_leads.sql
php scripts/import_mail_leads.php output/Поесть.txt --source=2gis:Поесть

# 3. Тест почты
php scripts/test_mail_smtp.php your@gmail.com

# 4. Рассылка (dry-run без --yes)
php scripts/mail_campaign_send.php \
  --storage=file \
  --source=file:output/Поесть.txt \
  --subject-template=templates/cafe_restaurant_subject.txt \
  --body-template=templates/cafe_restaurant_body.txt \
  --campaign=poest-2026 \
  --limit=3

# 5. Отправка
php scripts/mail_campaign_send.php ... --yes
```

## SMTP Rambler

- Сервер: `smtp.rambler.ru`, порт **465**, SSL  
- Пароль в `config.local.php` → `mail.smtp_password`  
- С домашнего Mac порты часто **заблокированы** — запускайте на хостинге по SSH  
- Диагностика: `php scripts/check_smtp_ports.php`

Подробнее: см. комментарии в `scripts/mail_campaign_send.php` и `scripts/test_mail_smtp.php`.
