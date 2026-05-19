-- Подписка PRO (флаг в профиле). Выполнить на сервере один раз после бэкапа.
-- Приложение читает поле в GET .../profile/me.php; без колонки API может вернуть 500 — накатите до деплоя клиента с ЛК.
--
-- Ошибка #1146 «Table ... user_profiles doesn't exist» — в этой БД таблица ещё не создана.
-- Сначала выполните в той же базе скрипт backend/sql/schema_auth.sql (CREATE TABLE … user_profiles, sms_otp).
-- Если таблица уже есть, но без is_pro — тогда выполняйте ALTER ниже. Если ставили свежий schema_auth.sql
-- с колонкой is_pro — этот ALTER не нужен (или оберните в проверку колонки на стороне админки).

ALTER TABLE user_profiles ADD COLUMN is_pro TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = активна подписка PRO' AFTER email;
