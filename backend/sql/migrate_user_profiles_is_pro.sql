-- Подписка PRO (флаг в профиле). Безопасно запускать повторно: колонка не дублируется.
-- Приложение читает поле в GET .../profile/me.php.
--
-- #1146 «Table ... user_profiles doesn't exist» — сначала schema_auth.sql (CREATE user_profiles).
-- #1060 «Duplicate column name 'is_pro'» — при старом варианте этого файла; текущий скрипт так не падает.

SET @exist := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'user_profiles'
    AND COLUMN_NAME = 'is_pro'
);
SET @sqlstmt := IF(
  @exist = 0,
  'ALTER TABLE user_profiles ADD COLUMN is_pro TINYINT(1) NOT NULL DEFAULT 0 COMMENT ''1 = активна подписка PRO'' AFTER email',
  'SELECT ''is_pro уже есть — ничего не делаем'' AS migrate_user_profiles_is_pro'
);
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
