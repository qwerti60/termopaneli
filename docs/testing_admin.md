# Проверка админки заявок (вход, токен, API)

Пошаговая инструкция для **отдельного входа администратора** (`admin_accounts` + **`POST .../admin/auth/login.php`**) и для **резервного** доступа через **`admin_api_token`** в **`config.php`**. Постановка этапа в **`docs/development_plan.md`** → [**`#dev-plan-section-7-admin`**](development_plan.md#dev-plan-section-7-admin). Краткая сводка в **`docs/estimate_mvp.md`** → [**`#mvp-admin-lk-stage5`**](estimate_mvp.md#mvp-admin-lk-stage5).

**Развёртывание админки в новом проекте:** каталог **[`admin-kit/`](../admin-kit/README.md)** — модули, порядок SQL, манифест файлов, `php admin-kit/verify_deploy.php`.

Замените `<API>` на базовый URL API **без** завершающего `/` (как **`API_BASE_URL`** в приложении).

---

## 1. SQL на сервере

1. Выполнить **`backend/sql/migrate_admin_accounts.sql`** на той же БД, что использует **`backend/public/config.php`**. Скрипт **идемпотентен** для логина **`admin`**: используется **`INSERT IGNORE`**.
2. Для **блокировки пользователей приложения** (колонка **`user_profiles.is_blocked`**, кнопки в **`admin_users.php`**) выполните **`backend/sql/migrate_user_profiles_is_blocked.sql`**.
3. Для **журнала действий** в веб-админке выполните **`backend/sql/migrate_admin_audit_log.sql`** (таблица **`admin_audit_log`**; **`CREATE TABLE IF NOT EXISTS`**).
4. Для **подписок PRO** (таблицы **`user_subscriptions`**, **`subscription_payment_events`**, пункт меню «Подписчики») выполните **`backend/sql/migrate_user_subscriptions.sql`**.
5. После миграции **`admin_accounts`** учётная запись по умолчанию:
   - **логин:** `admin`
   - **пароль по умолчанию:** `ChangeMe_Admin1!`  
   На **production** сразу смените пароль: сгенерируйте хеш в PHP (`password_hash('новый_пароль', PASSWORD_DEFAULT)`) и выполните **`UPDATE admin_accounts SET password_hash = '...' WHERE login = 'admin'`**.

Файл **`backend/sql/schema_admin_accounts.sql`** — только **`CREATE TABLE`** (для новых установок без миграции-обёртки).

---

## 2. Заливка PHP

На сервер должны попасть (пути относительно корня API, обычно `public/api/v1/...`):

- **`include/admin_auth.php`** — общая проверка Bearer (config **или** строка в **`admin_accounts.token`**; для веб-админки — ещё токен из PHP-сессии);
- **`include/admin_requests_service.php`**, **`include/admin_login_verify.php`** — общая логика списка/смены статуса и входа (API и веб);
- **`include/admin_estimate_calc.php`** — разбор **`calculation`** для **`request_view.php`** / PDF (подключается явно; при старом **`admin_requests_service.php`** на сервере веб-просмотр всё равно работает);
- **`api/v1/admin/auth/login.php`**, **`api/v1/admin/auth/logout.php`**;
- обновлённые **`api/v1/admin/requests/list.php`** и **`status.php`**;
- **`include/admin_estimate_pdf.php`** — сборка HTML и PDF (Dompdf) для **`admin-web/request_pdf.php`**;
- **`include/admin_catalog_media.php`** — загрузка JPEG/PNG/WebP в **`catalog_uploads/`**;
- **`include/admin_catalog_materials.php`**, **`include/admin_catalog_panels.php`**, **`include/admin_work_prices.php`**, **`include/admin_estimates.php`**, **`include/admin_audit_log.php`**, **`include/admin_users.php`**, **`include/admin_subscriptions.php`** — списки/обновление каталогов для веб-админки, **все сохранённые сметы** (`admin_estimates.php`), журнал, пользователи и **подписчики / журнал оплат**;
- **`admin-web/`** — HTML-интерфейс админки (см. §4 ниже).

**Где лежит `vendor/`:** код ищет **`vendor/autoload.php`** сначала в **родителе** каталога сайта (как в репозитории: **`backend/vendor`** при структуре `backend/public/...`), затем **внутри** корня сайта (**`tp_api/vendor`**, если весь `public` развёрнут как `tp_api/`). Достаточно одного из двух вариантов.

Если в SSH команда **`composer`** не найдена (`bash: composer: команда не найдена`), используйте **PHP** и локальный **`composer.phar`** (из каталога, где лежат **`composer.json`** и **`composer.lock`** — это может быть **родитель `tp_api`** или **сам `tp_api`**, см. выше):

```bash
cd /полный/путь/к/каталогу/с/composer.json
bash scripts/install_composer_deps.sh
```

(Скрипт **`backend/scripts/install_composer_deps.sh`** в репозитории; при выкладке только **`tp_api`** скопируйте **`composer.json`**, **`composer.lock`** и этот скрипт в **`tp_api`**, либо выполните команды вручную ниже.)

Вручную, одной сессией SSH:

```bash
cd /полный/путь/к/каталогу/с/composer.json
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=. --filename=composer.phar
php -r "unlink('composer-setup.php');"
php composer.phar install --no-dev --no-interaction
```

**Без SSH:** с локальной машины, где уже есть **`vendor/`**, залейте по FTP/SFTP весь каталог **`vendor/`** в выбранное место (**`…/tp_api/vendor/`** или **`…/рядом_с_tp_api/vendor/`**).

Без **`vendor/`** ссылка **«Скачать PDF»** в **`admin-web`** ответит **503** с краткой подсказкой.

**Важно при выкладке:** в корне `public` (например **`tp_api/`**) должны быть **`admin-web/`** и **`include/`** из **`backend/public/`**. Если залита только **`admin-web/`**, будет ошибка про отсутствие файлов в **`include/`** — скопируйте весь **`public/include/`**.

---

## 3. Проверка через `curl`

### 3.1. Вход и session-токен

```bash
curl -sS -X POST "<API>/api/v1/admin/auth/login.php" \
  -H 'Content-Type: application/json; charset=utf-8' \
  -d '{"login":"admin","password":"ChangeMe_Admin1!"}'
```

Ожидание: **HTTP 200**, в JSON поле **`token`** (длинная hex-строка).

### 3.2. Список заявок и смена статуса

```bash
TOKEN='<вставьте token из ответа login>'

curl -sS -H "Authorization: Bearer $TOKEN" \
  "<API>/api/v1/admin/requests/list.php?limit=20"

curl -sS -X POST "<API>/api/v1/admin/requests/status.php" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"request_id":1,"status":"in_work"}'
```

(Подставьте реальный **`request_id`** из списка.)

### 3.3. Выход и инвалидация токена

```bash
curl -sS -X POST "<API>/api/v1/admin/auth/logout.php" \
  -H "Authorization: Bearer $TOKEN"
```

Ожидание: **HTTP 200**, **`ok: true`**. Повторный **`GET list.php`** с тем же **`TOKEN`** — **401**.

### 3.4. Резерв: только `admin_api_token` из config

Если в **`config.php`** задан непустой **`admin_api_token`**, то **`GET/POST`** к **`list.php`** / **`status.php`** с **`Authorization: Bearer <admin_api_token>`** должны проходить **без** шага **`login.php`** (удобно для скриптов и для пункта меню в приложении **«Секрет из config.php»**).

---

## 4. Веб-интерфейс заявок (`admin-web`)

Минимальный **браузерный** UI на том же хосте, что и API (корень сайта обычно указывает на **`public/`**). Статическое **руководство для пользователя и менеджера** по мобильному приложению лежит в **`admin-web/app_user_guide.html`** (внизу левого меню админки есть ссылка «Руководство по приложению», открывается в новой вкладке).

1. Откройте **`https://<хост>/…/admin-web/login.php`** — путь зависит от развёртывания (рядом с **`api/`** внутри `public`).
2. Войдите логином **`admin`** и паролем из миграции → откроется **`requests.php`**: слева меню (**Заявки**, **Сметы (все)**, **Панели**, **Материалы**, **Работы**, **Пользователи**, **Подписки PRO**, **Журнал**, **Прочее**). Пункт **Прочее** (**`admin_misc.php`**) — справочник: ссылки по разделам, быстрые GET для проверки каталога и **app-manifest**, форма **«Реклама РСЯ в приложении»** (сохранить **`R-M-19410021-1`**, затем в **app-manifest** проверить **`yandex_banner_ad_unit_id`**), подсказки по **PDF/Dompdf**, миграции подписок, версия PHP. В разделе заявок — таблица, фильтры по статусу, кнопка **OK** у строки меняет статус (тот же **`UPDATE`**, что и **`status.php`**). Ссылка **«Просмотр сметы»** открывает **`request_view.php?id=…`**. На экране просмотра — **«Скачать PDF»** → **`request_pdf.php?id=…`**. Раздел **Сметы (все)** — **`admin_estimates.php`**: таблица **`estimates`** с контактом пользователя, кнопка **Удалить** (POST **`admin_estimate_delete.php`** + CSRF; каскадом удаляются позиции и **`estimate_requests`**). **Пользователи** — **`admin_users.php`**: список клиентов, колонка блокировки, кнопки **заблокировать** / **разблокировать** (нужна миграция **`migrate_user_profiles_is_blocked.sql`**; события пишутся в **`admin_audit_log`**). **Подписки PRO** — **`subscriptions.php`**: сводка и ссылки на **`admin_subscribers.php`** (пользователи с **`is_pro = 1`** или активной строкой в **`user_subscriptions`**) и **`admin_subscription_events.php`** (таблица **`subscription_payment_events`**, фильтр **`?user_id=`**); нужна миграция **`migrate_user_subscriptions.sql`**. **Журнал** — **`admin_journal.php`** (нужна миграция **`migrate_admin_audit_log.sql`**).
3. **Панели** — **`catalog_panels.php`**: таблица **`thermo_panel_catalog`** (как в **`GET …/catalog/list.php?category=panel`**). Редактирование — **`catalog_panel_edit.php`** (поля по **`DESCRIBE`** на вашей БД).
4. **Материалы** — **`catalog_materials.php`** / **`catalog_edit.php`** (таблица **`catalog_materials`**).
5. **Работы** — **`catalog_work_prices.php`** / **`catalog_work_edit.php`** (таблица **`work_prices`**; для картинок выполните **`backend/sql/migrate_work_prices_image_path.sql`** при обновлении существующей БД).
6. **Выйти** — инвалидация session-токена в **`admin_accounts`** и очистка сессии.

Технически: **`bootstrap_web.php`** вызывает **`session_start`**, после успешного входа в сессии хранится **`admin_web_token`**; **`tp_admin_bearer()`** в **`admin_auth.php`** читает его, если нет заголовка **`Authorization`**.

Сброс и смена пароля: **`login_reset.php`** (ссылка с **`login.php`**, без входа — код на email) и **`admin_password.php`** (клик по **логину** в подвале левого меню после входа). Миграция **`backend/sql/migrate_admin_password_reset.sql`**; в **`config.php`** задайте **`mail.from`** (и при необходимости **`mail.password_reset_fallback`**, **`admin_password_otp_ttl_seconds`**); для адреса получателя можно заполнить **`admin_accounts.email`**.

---

## 5. Приложение Flutter

1. **Профиль → Заявки (админ)** — если в **`SessionService`** ещё нет сохранённого Bearer, открывается экран **`/admin-login`** (**«Вход администратора»**); после успеха открывается **`/admin-requests`**.
2. Вход логином **`admin`** и паролем после миграции → список заявок, фильтры по статусу, **Обновить список**.
3. Открыть заявку → сменить статус → **Применить** — у автора сметы в **«Мои заявки»** статус обновляется после обновления данных.
4. **Иконка «Выйти»** в шапке списка — вызов **`logout.php`** и очистка токена на устройстве; повторный вход с профиля снова показывает экран логина.
5. Меню **«⋯» → Секрет из config.php»** — ручной ввод **`admin_api_token`** (резерв для старого сценария). После **«Сохранить»** список перезагружается; диалог открывается **на следующем кадре** после закрытия `PopupMenu`, контроллер поля **не** `dispose` в том же такте, что и `Navigator.pop` диалога (избегание assert в `framework.dart`).
6. **Подписка PRO / SmartCalc / «Дом»:** повторное оформление при активной подписке — **409** на **`POST …/subscription/checkout.php`**; локальный grace и флаг **`kHomeScreenEnabled`** — в **`docs/estimate_mvp.md`** → **`#mvp-subscription-pro`** и таблица маршрутов ЛК в том же файле.

---

## 6. Файлы в репозитории (ориентир)

| Назначение | Путь |
|------------|------|
| SQL миграция | `backend/sql/migrate_admin_accounts.sql` |
| Схема таблицы | `backend/sql/schema_admin_accounts.sql` |
| Проверка Bearer (+ сессия веб) | `backend/public/include/admin_auth.php` |
| Сервис заявок (список, деталь, статус) | `backend/public/include/admin_requests_service.php` |
| Журнал админ-действий | `backend/public/include/admin_audit_log.php`, **`backend/sql/migrate_admin_audit_log.sql`**, **`backend/sql/schema_admin_audit_log.sql`** |
| Список пользователей (админ) | `backend/public/include/admin_users.php`, `backend/public/admin-web/admin_users.php` |
| Подписки PRO (сводка, подписчики, журнал оплат) | `backend/sql/migrate_user_subscriptions.sql`, `backend/public/include/admin_subscriptions.php`, `backend/public/admin-web/subscriptions.php`, `backend/public/admin-web/admin_subscribers.php`, `backend/public/admin-web/admin_subscription_events.php` |
| Веб-страница журнала | `backend/public/admin-web/admin_journal.php` |
| Разбор скидки (`calculation`) | `backend/public/include/admin_estimate_calc.php` |
| Вход (общий код) | `backend/public/include/admin_login_verify.php` |
| Сброс/смена пароля веб-админки | `backend/sql/migrate_admin_password_reset.sql`, `backend/public/include/admin_password_service.php`, `backend/public/include/admin_mail.php`, `backend/public/admin-web/login_reset.php`, `backend/public/admin-web/admin_password.php` |
| Веб-админка | `backend/public/admin-web/` (… `admin_estimates.php`, `admin_estimate_delete.php`, `catalog_material_new.php`, `catalog_material_delete.php`, …) |
| Загрузки картинок | `backend/public/catalog_uploads/` (создаётся автоматически; в git только `.gitignore` + `.gitkeep`) |
| Загрузка / MIME | `backend/public/include/admin_catalog_media.php` |
| Каталоги (админ PHP) | `admin_catalog_materials.php`, `admin_catalog_panels.php`, `admin_work_prices.php` в **`backend/public/include/`** |
| PDF сметы (Dompdf) | `backend/public/include/admin_estimate_pdf.php` + **`backend/vendor/`** (см. §2, `composer install` в **`backend/`**) |
| Вход / выход | `backend/public/api/v1/admin/auth/login.php`, `logout.php` |
| Список / статус | `backend/public/api/v1/admin/requests/list.php`, `status.php` |
| Клиент: вход | `lib/screens/admin_login_screen.dart`, `lib/services/admin_auth_api_service.dart` |
| Клиент: заявки | `lib/screens/admin_requests_screen.dart`, `lib/services/admin_requests_api_service.dart` |
| Навигация | `lib/routes/routes.dart` (`adminLogin`), `lib/routes/app_router.dart` (`pushAdminRequests`) |
| Хранение Bearer | `lib/services/session_service.dart` (ключ **`admin_api_token`** в `SharedPreferences` — для session после login и для ручного секрета) |
| Страница «Прочее» (справочник) | `backend/public/admin-web/admin_misc.php` |

---

## 7. Типичные проблемы

| Симптом | Что проверить |
|--------|----------------|
| **401** на **`login.php`** | Логин/пароль; выполнен ли **`migrate_admin_accounts.sql`**; строка **`admin`** в **`admin_accounts`**. |
| **401** на **`list.php`** после входа | Тот же **`Authorization: Bearer`** что вернул **`login`**; не подставлен ли пользовательский токен сметы. |
| **401** сразу после успешного входа в приложении | **`API_BASE_URL`** указывает на другой хост, чем БД с **`admin_accounts`**. |
| Список пустой при валидном токене | На сервере нет строк в **`estimate_requests`** или фильтр **`status`** слишком узкий. |
| Ошибка Flutter при «Сохранить» в диалоге секрета | Обновите приложение до версии с отложенным **`dispose`** контроллера диалога и **`addPostFrameCallback`** для открытия диалога из меню (**`admin_requests_screen.dart`**). |
| Веб **`admin-web`** сразу редирект на логин | Сессии PHP: права на **`session.save_path`**, не открывайте по другому домену без учёта cookie. |
| Раздел **Панели** в админке — ошибка про таблицу | На сервере должна существовать **`thermo_panel_catalog`** (как для **`GET …/catalog/list.php?category=panel`**). |
| Раздел **Работы** — ошибка про колонку | Выполните **`backend/sql/migrate_work_prices_image_path.sql`** (или полный **`schema_work_prices.sql`** на новой установке). |
| Раздел **Журнал** — ошибка про таблицу | Выполните **`backend/sql/migrate_admin_audit_log.sql`**. |
| Раздел **Подписчики** / журнал оплат — ошибка про таблицу | Выполните **`backend/sql/migrate_user_subscriptions.sql`**. |
