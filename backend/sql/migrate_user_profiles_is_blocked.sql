-- Блокировка пользователя (веб-админка). Клиент получает 403 с code=user_blocked на защищённых API.
-- Повторный запуск безопасен.

SET @schema := DATABASE();
SET @col_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @schema
    AND TABLE_NAME = 'user_profiles'
    AND COLUMN_NAME = 'is_blocked'
);
SET @sql := IF(
  @col_exists > 0,
  'SELECT 1 AS is_blocked_column_already_present',
  'ALTER TABLE user_profiles
     ADD COLUMN is_blocked TINYINT(1) NOT NULL DEFAULT 0
       COMMENT ''1 = вход и действия с аккаунтом запрещены''
     AFTER is_pro'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
