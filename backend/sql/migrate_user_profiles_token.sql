-- Миграция существующей таблицы user_profiles под новую auth-логику.
-- Логика: токен хранится в user_profiles.token.
--
-- Перед запуском:
-- 1) сделайте бэкап БД;
-- 2) выполните скрипт в своей MySQL базе (той же, что указана в config.php).

-- 1) Добавляем/приводим колонку phone (формат 7XXXXXXXXXX)
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS phone VARCHAR(11) NULL COMMENT 'формат 7XXXXXXXXXX';

-- 2) Добавляем колонки токена
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS last_name VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS middle_name VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS email VARCHAR(255) NULL,
  ADD COLUMN IF NOT EXISTS token CHAR(64) NULL DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS token_updated_at DATETIME NULL DEFAULT NULL;

-- 3) Чистим пустые значения токена (чтобы уникальный индекс не ломался)
UPDATE user_profiles
SET token = NULL
WHERE token = '' OR token = '0';

-- 4) Проверяем дубли перед созданием уникальных индексов
-- Если здесь есть строки, сначала устраните дубли вручную.
SELECT phone, COUNT(*) AS cnt
FROM user_profiles
WHERE phone IS NOT NULL AND phone <> ''
GROUP BY phone
HAVING COUNT(*) > 1;

SELECT token, COUNT(*) AS cnt
FROM user_profiles
WHERE token IS NOT NULL AND token <> ''
GROUP BY token
HAVING COUNT(*) > 1;

-- 5) Добавляем уникальные индексы
ALTER TABLE user_profiles
  ADD UNIQUE KEY uq_user_profiles_phone (phone),
  ADD UNIQUE KEY uq_user_profiles_token (token);

-- 6) Если есть старая таблица auth_tokens и она больше не нужна:
-- DROP TABLE IF EXISTS auth_tokens;

-- Готово.
