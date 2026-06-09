# Админка PHP — развёртывание в новых проектах

Переиспользуемая **веб-админка** и **admin API** из репозитория termopaneli. Подходит для проектов на том же стеке: PHP 8.1+, MySQL, server-rendered UI + JSON API.

**Источник файлов в репозитории:** `backend/public/` (`admin-web/`, `include/`, `api/v1/admin/`).

---

## Что умеет

| Раздел | Страницы | Назначение |
|--------|----------|------------|
| **Ядро** | login, logout, сброс пароля, журнал | Вход, CSRF, audit log |
| **Заявки** | requests, request_view, request_pdf | Заявки на смету, PDF (Dompdf) |
| **Каталог** | panels, materials, works | CRUD + загрузка картинок |
| **Пользователи** | admin_users | Список, блокировка |
| **Подписки** | subscriptions, subscribers, events | PRO-подписки |
| **API** | `/api/v1/admin/*` | Тот же вход для Flutter/скриптов |

---

## Требования

- PHP **≥ 8.1** (`pdo_mysql`, `json`, `mbstring`; для PDF — `dompdf/dompdf`)
- MySQL **5.7+** / MariaDB **10.3+**
- Веб-сервер (Apache/Nginx) → document root на каталог `public` API
- Запись: PHP sessions, `catalog_uploads/` (если включён каталог)
- Composer: `dompdf/dompdf ^3.0` — только для PDF заявок

---

## Структура на сервере

Корень сайта API (часто `tp_api/` или `public/`):

```
tp_api/
├── config.php              ← из config.example.php (не в git)
├── admin-web/              ← HTML-интерфейс
│   ├── bootstrap_web.php
│   ├── login.php
│   ├── requests.php
│   └── …
├── include/                ← общая логика (API + админка)
│   ├── api_bootstrap.php
│   ├── admin_auth.php
│   └── …
├── api/v1/
│   ├── admin/              ← JSON для мобильной админки
│   └── …                   ← пользовательское API (по необходимости)
├── catalog_uploads/        ← writable (каталог с картинками)
└── vendor/                 ← composer (или ../vendor/)
```

**Важно:** `admin-web/` и `include/` должны лежать **на одном уровне**. Иначе `bootstrap_web.php` выдаст 500 с подсказкой.

---

## Модули: что копировать

### Ядро (минимум для входа)

| Путь | Назначение |
|------|------------|
| `admin-web/bootstrap_web.php` | Layout, меню, CSRF, guard |
| `admin-web/login.php`, `logout.php`, `index.php` | Вход |
| `admin-web/login_reset.php`, `admin_password.php` | Сброс/смена пароля |
| `admin-web/admin_journal.php` | Журнал действий |
| `include/api_bootstrap.php` | config + PDO |
| `include/admin_auth.php` | Bearer + session |
| `include/admin_login_verify.php` | Проверка логина/пароля |
| `include/admin_audit_log.php` | Audit log |
| `include/admin_mail.php` | mail() для OTP |
| `include/admin_password_service.php` | OTP сброс пароля |
| `api/v1/admin/auth/login.php`, `logout.php` | JSON-вход |

**SQL ядра:**

1. `sql/migrate_admin_accounts.sql` (или `schema_admin_accounts.sql`)
2. `sql/migrate_admin_audit_log.sql`
3. `sql/migrate_admin_password_reset.sql`

**Config ядра:** `db.*`, `mail.from`, опционально `admin_api_token`, `admin_password_otp_ttl_seconds`.

**Первый вход:** логин `admin`, пароль `ChangeMe_Admin1!` — **сразу сменить на production**.

---

### Модуль «Заявки и сметы»

| Доп. файлы |
|------------|
| `admin-web/requests.php`, `request_view.php`, `request_pdf.php` |
| `admin-web/admin_estimates.php`, `admin_estimate_delete.php` |
| `include/admin_requests_service.php`, `admin_estimate_calc.php`, `admin_estimate_pdf.php` |
| `include/admin_estimates.php`, `company_pdf_defaults.php` |
| `api/v1/admin/requests/list.php`, `status.php` |

**SQL:** `schema_estimates.sql` (или миграции смет), Dompdf в `vendor/`.

**Config:** `company_pdf.*` — реквизиты в PDF (переопределите под новый проект).

---

### Модуль «Каталог»

| Доп. файлы |
|------------|
| `admin-web/catalog_*.php` (panels, materials, works) |
| `include/admin_catalog_*.php`, `admin_work_prices.php`, `admin_catalog_media.php` |

**SQL:** `schema_catalog_materials.sql`, `schema_work_prices.sql`, таблица панелей (`thermo_panel_catalog` — создайте под свой проект или адаптируйте include).

**FS:** `catalog_uploads/` с правами на запись.

---

### Модуль «Пользователи приложения»

| Доп. файлы |
|------------|
| `admin-web/admin_users.php`, `admin_user_toggle.php` |
| `include/admin_users.php` |

**SQL:** `schema_auth.sql` + `migrate_user_profiles_is_blocked.sql`.

---

### Модуль «Подписки PRO»

| Доп. файлы |
|------------|
| `admin-web/subscriptions.php`, `admin_subscribers.php`, `admin_subscription_events.php` |
| `include/admin_subscriptions.php`, `subscriptions_repo.php`, `subscription_plans.php` |
| `api/v1/subscription/*` (если нужен PRO в приложении) |

**SQL:** `migrate_user_subscriptions.sql` (в свежем `schema_auth.sql` таблицы уже есть).

---

## Пошаговое развёртывание (новый проект)

### 1. База данных

```bash
# Минимум — только админка
mysql -u USER -p DB_NAME < backend/sql/migrate_admin_accounts.sql
mysql -u USER -p DB_NAME < backend/sql/migrate_admin_audit_log.sql
mysql -u USER -p DB_NAME < backend/sql/migrate_admin_password_reset.sql

# По модулям — см. admin-kit/SQL_ORDER.md
```

### 2. Конфигурация

```bash
cp backend/public/config.example.php /path/to/tp_api/config.php
# Заполните db.*, mail.from, admin_api_token (длинная случайная строка)
```

Фрагмент для админки — `admin-kit/config.admin.example.php`.

### 3. Копирование PHP

Из репозитория скопируйте на сервер:

- выбранные каталоги из раздела **Модули** выше;
- весь `include/` проще копировать целиком, если не режете функциональность.

```bash
# Пример rsync (пути подставьте свои)
rsync -av backend/public/admin-web/  user@host:/var/www/tp_api/admin-web/
rsync -av backend/public/include/     user@host:/var/www/tp_api/include/
rsync -av backend/public/api/v1/admin/ user@host:/var/www/tp_api/api/v1/admin/
```

### 4. Composer (PDF)

```bash
cd /path/to/backend   # или tp_api, где лежит composer.json
bash scripts/install_composer_deps.sh
# либо: composer install --no-dev
```

### 5. Права

```bash
chmod 755 tp_api/catalog_uploads
chown www-data:www-data tp_api/catalog_uploads   # пользователь PHP-FPM
```

### 6. Проверка

```bash
cd admin-kit
php verify_deploy.php --public=/path/to/tp_api --url=https://example.com/tp_api
```

Откройте в браузере: `https://example.com/tp_api/admin-web/login.php`

---

## Авторизация

Один механизм для **веба** и **API**:

1. **Веб:** POST `login.php` → PHP session `admin_web_token` + запись в `admin_accounts.token`.
2. **API:** POST `/api/v1/admin/auth/login.php` → JSON `{ "token": "…" }` → заголовок `Authorization: Bearer …`.
3. **Резерв:** `admin_api_token` в `config.php` (не сбрасывается при logout — только для автomation/legacy).

Logout инвалидирует токен в БД (кроме config token).

---

## Кастомизация под новый проект

| Что | Где менять |
|-----|------------|
| Пункты меню | `admin-web/bootstrap_web.php` → массив `$nav` |
| Заголовок «админ» | `tp_admin_web_layout_start()` в том же файле |
| Реквизиты PDF | `config.php` → `company_pdf` или `include/company_pdf_defaults.php` |
| Статусы заявок | `include/admin_requests_service.php` |
| Имена таблиц каталога | `include/admin_catalog_panels.php` (сейчас `thermo_panel_catalog`) |
| Статичная справка | замените или удалите `admin-web/app_user_guide.html` |

Для **минимальной** админки без Termopaneli: оставьте ядро + нужные модули, вырежите пункты меню и страницы лишних разделов.

---

## Документация в репозитории

| Файл | Содержание |
|------|------------|
| [admin-kit/SQL_ORDER.md](SQL_ORDER.md) | Порядок всех SQL-скриптов |
| [admin-kit/MODULES.md](MODULES.md) | Таблица файлов по модулям |
| [docs/testing_admin.md](../docs/testing_admin.md) | curl-тесты, смена пароля, деплой |
| [docs/development_plan.md](../docs/development_plan.md) | §7 — план развития админки |

---

## Безопасность (production)

- Сменить пароль `admin` сразу после миграции.
- Задать уникальный `admin_api_token`; не публиковать в клиенте, если не нужен.
- `config.php` и `config.local.php` — **вне git**, права `640`.
- HTTPS для admin-web; cookie session с `Secure` на HTTPS.
- Ограничить доступ к `/admin-web/` по IP или basic auth на уровне Nginx (опционально).
