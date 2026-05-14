Регистрация / вход (PHP + MySQL)
================================

Файлы в репозитории: public/api/v1/auth/*.php (на сервере — внутри каталога tp_api, если корень сайта указывает на public).

1) Выполните SQL: sql/schema_auth.sql
   (новая запись при регистрации — в таблице user_profiles; токен хранится в user_profiles.token)

   Если таблица user_profiles уже была создана ранее: убедитесь, что есть столбцы:
   - phone (уникальный),
   - token (уникальный, допускает NULL),
   - token_updated_at (DATETIME, допускает NULL).

2) Скопируйте public/config.example.php в config.php, заполните db и при необходимости sms (логин/пароль smsc.ru для request-sms.php).
   Для MVP-админских API задайте в config.php длинный случайный admin_api_token.

3) Эндпоинты (как вызывает Flutter):
   GET  .../api/v1/auth/session.php          — заголовок Authorization: Bearer <token>
   POST .../api/v1/auth/request-sms.php      — тело JSON {"phone":"79991234567"}
   POST .../api/v1/auth/verify-phone.php     — тело JSON {"phone":"...","code":"123456"}
                                              для существующего вернет token, для нового — is_new_user=true
   POST .../api/v1/auth/register.php         — тело JSON с phone+code+ФИО+email и accepted_user_agreement: true, создает user_profiles и выдает token
   GET  .../api/v1/catalog/list.php          — каталог панелей и материалов
                                               параметры: category=all|panel|slope|corner|grout|ebb|soffit|plinth|fastener
   GET  .../api/v1/settings/company-for-pdf.php — JSON реквизитов и ссылок для шапки PDF (без Authorization); значения из config.php (ключ company_pdf) с дефолтами в PHP
   GET  .../api/v1/settings/app-manifest.php — единый JSON: company_pdf (как выше) + user_agreement_url + privacy_policy_url (опционально из config.php → app_manifest)
   GET  .../api/v1/work-prices/list.php      — тестовый прайс работ для сметы
   POST .../api/v1/estimates/save.php        — сохранение сметы, Authorization: Bearer <token>
   GET  .../api/v1/estimates/list.php        — список смет пользователя, Authorization: Bearer <token>
   POST .../api/v1/estimates/submit.php      — отправка сохраненной сметы как заявки, Authorization: Bearer <token>
                                             тело JSON {"estimate_id":123,"comment":"..."}
                                             контакты берутся из user_profiles текущего пользователя
   GET  .../api/v1/admin/requests/list.php   — список заявок для администратора, Authorization: Bearer <admin_api_token>
                                             параметры: status=new|in_work|need_info|done|closed|cancelled, limit=1..200
   POST .../api/v1/admin/requests/status.php — смена статуса заявки, Authorization: Bearer <admin_api_token>
                                             тело JSON {"request_id":123,"status":"in_work"}
   В приложении: Профиль -> Заявки (админ) — ввод admin token, список и смена статуса.

   Для откосов и дополнительных элементов выполните:
   sql/schema_catalog_materials.sql
   Скрипт создаёт catalog_materials и загружает стартовые позиции с ценой 0.
   Перед production замените цены и изображения на реальные.

   Для сохранения смет выполните:
   sql/schema_estimates.sql

   Для тестового прайса работ выполните:
   sql/schema_work_prices.sql

4) Цепочка:
   - request-sms.php сохраняет код в таблице sms_otp и шлёт SMS через smsc.ru;
   - verify-phone.php:
       * существующий пользователь -> новый token;
       * новый пользователь -> только признак is_new_user=true;
   - register.php принимает ФИО+email (обязательно), accepted_user_agreement: true, создает user_profiles и возвращает token.

   Пользовательское соглашение: файл public/api/agreement.html — разместите на сервере по URL https://<хост>/api/agreement.html
   (рядом с каталогом tp_api, если API в /tp_api/). Текст соглашения в репозитории обновляйте при смене реквизитов.

   Реквизиты для PDF: залейте public/api/v1/settings/company-for-pdf.php; при необходимости задайте в config.php ключ company_pdf (см. config.example.php)., код всё равно сохраняется в БД, но SMS не уйдёт (для отладки можно временно смотреть код в таблице sms_otp).

DEV-режим фиксированного кода:
- В config.php можно задать 'dev_static_otp_code' => '123456'.
- Тогда request-sms.php будет сохранять именно этот код,
  а verify-phone.php примет его даже без записи sms_otp (удобно для локального теста).
- На проде обязательно оставьте пустую строку.
