Регистрация / вход (PHP + MySQL)
================================

Файлы в репозитории: public/api/v1/auth/*.php (на сервере — внутри каталога tp_api, если корень сайта указывает на public).

1) Выполните SQL: sql/schema_auth.sql
   (новая запись при регистрации — в таблице user_profiles; токен хранится в user_profiles.token)

   Блокировка клиента (веб-админка «Пользователи»): на существующей БД выполните
   sql/migrate_user_profiles_is_blocked.sql — добавляет user_profiles.is_blocked (0/1).
   При is_blocked=1 защищённые пользовательские эндпоинты (сессия, профиль, сметы, verify-phone
   перед выдачей токена) отвечают HTTP 403 и JSON с "code":"user_blocked" и полем "message";
   приложение сбрасывает локальный токен.

   Подписка PRO (таблицы user_subscriptions и subscription_payment_events, API и веб-админка «Подписчики»):
   sql/migrate_user_subscriptions.sql — для существующей БД; в свежем schema_auth.sql таблицы уже в CREATE.
   PHP на сервере: public/api/v1/subscription/status.php, checkout.php, cancel.php (+ include/subscription_plans.php, subscriptions_repo.php при выкладке из репозитория).

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
   GET  .../api/v1/catalog/list.php          — каталог панелей и материалов; query: category, limit, offset, опционально material и color (точное совпадение полей в catalog_materials; к выборке панелей не применяются)
                                               параметры: category=all|panel|slope|corner|grout|ebb|soffit|plinth|fastener
   GET  .../api/v1/settings/company-for-pdf.php — JSON реквизитов и ссылок для шапки PDF (без Authorization); значения из config.php (ключ company_pdf) с дефолтами в PHP
   GET  .../api/v1/settings/app-manifest.php — единый JSON: company_pdf (как выше) + user_agreement_url + privacy_policy_url (опционально из config.php → app_manifest) + smartcalc_url (HTTPS-страница SmartCalc для PRO) + yandex_banner_ad_unit_id (ID блока РСЯ для баннеров Каталог/Поиск; можно сохранить в admin-web → Прочее)
   GET  .../api/v1/profile/me.php            — профиль текущего пользователя (ФИО, телефон, email), Authorization: Bearer <token>
                                               перед ответом синхронизируется is_pro с активной подпиской (user_subscriptions)
   POST .../api/v1/profile/update.php       — обновление ФИО и email (JSON: last_name, first_name, middle_name, email); телефон не меняется; Authorization: Bearer <token>; ответ как у me.php
   GET  .../api/v1/subscription/status.php  — статус PRO и активная подписка (JSON: is_pro, subscription|null), Authorization: Bearer <token>
   POST .../api/v1/subscription/checkout.php — тело JSON {"plan_code":"1m"|"3m"|"6m"|"1y"}; пока эквайринг не подключён: при отсутствии активной подписки сразу создаётся PRO на срок тарифа (строка user_subscriptions, is_pro=1), ответ 200 { "ok": true, "code": "activated_without_payment", ... }; в subscription_payment_events — activated_no_acquiring. Если активная подписка уже есть — 409 { "ok": false, "code": "already_subscribed", "message": "..." }. После подключения эквайринга замените логику на реальную оплату.
   POST .../api/v1/subscription/cancel.php   — отмена активной подписки (снимает PRO), Authorization: Bearer <token>; 200 { "ok": true } или 400 { "ok": false, "message": "..." }
   GET  .../api/v1/work-prices/list.php      — тестовый прайс работ для сметы
   POST .../api/v1/estimates/save.php        — сохранение сметы, Authorization: Bearer <token>
   GET  .../api/v1/estimates/list.php        — список смет пользователя, Authorization: Bearer <token>
   POST .../api/v1/estimates/submit.php      — отправка сохраненной сметы как заявки, Authorization: Bearer <token>
   POST .../api/v1/estimates/delete.php      — удаление сохранённой сметы текущего пользователя, JSON { "estimate_id": <int> }, Authorization: Bearer <token>
                                             тело JSON {"estimate_id":123,"comment":"..."}
                                             контакты берутся из user_profiles текущего пользователя
   GET  .../api/v1/admin/requests/list.php   — список заявок для администратора, Authorization: Bearer <токен>
                                             параметры: status=new|in_work|need_info|done|closed|cancelled, limit=1..200
   POST .../api/v1/admin/requests/status.php — смена статуса заявки, Authorization: Bearer <токен>
                                             тело JSON {"request_id":123,"status":"in_work"}
   Токен в заголовке — один из двух вариантов:
     a) admin_api_token из config.php (как раньше, для curl/скриптов);
     b) токен из POST .../api/v1/admin/auth/login.php после входа логином/паролем (таблица admin_accounts).
   POST .../api/v1/admin/auth/login.php      — тело JSON {"login":"admin","password":"..."}, ответ 200: {"token":"...","login":"admin"}
   POST .../api/v1/admin/auth/logout.php     — сброс session-токена в БД, Authorization: Bearer <токен из login>
   В приложении: Профиль -> Заявки (админ) — сначала экран входа администратора; резервно меню «Секрет из config.php».

   Администраторы в БД: выполните sql/migrate_admin_accounts.sql (создаёт admin_accounts и логин admin с паролем ChangeMe_Admin1! — смените пароль на production).
   Подробный чеклист (SQL, curl, веб admin-web, сценарии в приложении): docs/testing_admin.md
   Веб-интерфейс заявок (браузер): откройте .../admin-web/login.php относительно корня public (см. testing_admin.md §4).
   PDF сметы из веб-админки: .../admin-web/request_pdf.php?id=<id заявки> (нужен вход в admin-web); зависимости в backend/vendor/: если команды «composer» нет, на сервере из каталога backend выполните «bash scripts/install_composer_deps.sh» или «php composer.phar install» (см. docs/testing_admin.md §2).

   Для откосов и дополнительных элементов выполните:
   sql/schema_catalog_materials.sql
   Скрипт создаёт catalog_materials и загружает позиции из docs/catalogs (цены 0 — замените перед production).
   Повторный запуск INSERT обновляет строки по sku (ON DUPLICATE KEY UPDATE).

   Для сохранения смет выполните:
   sql/schema_estimates.sql

   Для тестового прайса работ выполните:
   sql/schema_work_prices.sql
   Если таблица work_prices уже была без картинок: sql/migrate_work_prices_image_path.sql (колонка image_path для админки и API).

   Веб-админка может загружать изображения в public/catalog_uploads/ — каталог должен быть доступен веб-серверу на запись (создаётся при первой загрузке).
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
