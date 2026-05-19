-- Учётные записи администратора (отдельный вход, не user_profiles).
-- После создания таблицы выполните migrate_admin_accounts.sql или вставьте строку вручную.

CREATE TABLE IF NOT EXISTS admin_accounts (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    login VARCHAR(64) NOT NULL COMMENT 'логин для POST .../admin/auth/login.php',
    password_hash VARCHAR(255) NOT NULL COMMENT 'password_hash() PHP',
    token CHAR(64) NULL DEFAULT NULL COMMENT 'Bearer после успешного входа',
    token_updated_at DATETIME NULL DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_admin_accounts_login (login),
    UNIQUE KEY uq_admin_accounts_token (token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
