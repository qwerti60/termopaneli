# Порядок SQL для админки и модулей

Выполняйте на **одной БД**, которую указывает `config.php` → `db.name`.

Пути от корня репозитория: `backend/sql/`.

---

## A. Новая установка «всё приложение + админка»

| # | Файл | Зависимости |
|---|------|-------------|
| 1 | `schema_auth.sql` | — (users, OTP, subscriptions в одном файле для fresh install) |
| 2 | `schema_estimates.sql` | user_profiles |
| 3 | `schema_catalog_materials.sql` | — |
| 4 | `schema_work_prices.sql` | — |
| 5 | `schema_admin_accounts.sql` | — |
| 6 | `schema_admin_audit_log.sql` | admin_accounts (FK опционален) |

**Панели:** таблица `thermo_panel_catalog` в репозитории без отдельного schema — создайте вручную или возьмите из prod dump.

---

## B. Существующая БД (миграции)

### Обязательно для админки

| # | Файл |
|---|------|
| 1 | `migrate_admin_accounts.sql` |
| 2 | `migrate_admin_audit_log.sql` |
| 3 | `migrate_admin_password_reset.sql` |

### Модули (по необходимости)

| # | Файл | Модуль |
|---|------|--------|
| 4 | `migrate_user_profiles_is_blocked.sql` | Пользователи |
| 5 | `migrate_user_subscriptions.sql` | Подписки PRO |
| 6 | `migrate_user_profiles_is_pro.sql` | PRO flag (если нет в schema_auth) |
| 7 | `migrate_catalog_materials_package_qty.sql` | Каталог материалов |
| 8 | `migrate_work_prices_image_path.sql` | Работы + картинки |

Сметы/заявки: если таблиц нет — `schema_estimates.sql`.

---

## C. Только ядро админки (без мобильного приложения)

Достаточно пунктов **B.1–B.3**. Таблицы `user_profiles`, `estimates` не нужны, если не подключаете соответствующие модули.

---

## Проверка после миграции

```sql
SHOW TABLES LIKE 'admin_%';
SELECT login, email FROM admin_accounts LIMIT 5;
```

Ожидается запись `admin` с bcrypt-хешем пароля.
