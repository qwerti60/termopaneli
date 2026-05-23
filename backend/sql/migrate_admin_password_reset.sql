-- Сброс пароля админки по коду из e-mail + опционально email в учётке.
-- Повторный запуск: ADD COLUMN пропускается через проверку INFORMATION_SCHEMA (см. ниже).

CREATE TABLE IF NOT EXISTS admin_password_reset_otp (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  login VARCHAR(64) NOT NULL,
  code CHAR(6) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_apro_login (login),
  KEY idx_apro_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @exist := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'admin_accounts'
    AND COLUMN_NAME = 'email'
);
SET @sqlstmt := IF(
  @exist = 0,
  'ALTER TABLE admin_accounts ADD COLUMN email VARCHAR(255) NULL DEFAULT NULL COMMENT ''для кода сброса пароля'' AFTER login',
  'SELECT ''admin_accounts.email уже есть'' AS migrate_admin_password_reset'
);
PREPARE stmt FROM @sqlstmt;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
