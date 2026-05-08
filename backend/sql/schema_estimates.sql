-- Таблицы сохраненных смет.
-- Перед запуском сделайте бэкап БД.

CREATE TABLE IF NOT EXISTS estimates (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL DEFAULT 'Смета',
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  raw_json LONGTEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_estimates_user_created (user_id, created_at),
  CONSTRAINT fk_estimates_user
    FOREIGN KEY (user_id) REFERENCES user_profiles(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Совместимо со старыми MySQL/MariaDB, где нет ADD COLUMN IF NOT EXISTS.
SET @column_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'estimates'
    AND COLUMN_NAME = 'raw_json'
);

SET @sql := IF(
  @column_exists = 0,
  'ALTER TABLE estimates ADD COLUMN raw_json LONGTEXT NULL AFTER total_amount',
  'SELECT 1'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS estimate_items (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  estimate_id INT UNSIGNED NOT NULL,
  item_key VARCHAR(255) NOT NULL,
  category VARCHAR(50) NOT NULL,
  sku VARCHAR(100) NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT NULL,
  material VARCHAR(100) NULL,
  color VARCHAR(100) NULL,
  unit VARCHAR(50) NOT NULL DEFAULT 'шт',
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  raw_json LONGTEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_estimate_items_estimate (estimate_id),
  CONSTRAINT fk_estimate_items_estimate
    FOREIGN KEY (estimate_id) REFERENCES estimates(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS estimate_requests (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  estimate_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'new',
  contact_name VARCHAR(255) NULL,
  contact_phone VARCHAR(50) NULL,
  contact_email VARCHAR(255) NULL,
  comment TEXT NULL,
  raw_json LONGTEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_estimate_requests_user_created (user_id, created_at),
  KEY idx_estimate_requests_estimate (estimate_id),
  CONSTRAINT fk_estimate_requests_estimate
    FOREIGN KEY (estimate_id) REFERENCES estimates(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_estimate_requests_user
    FOREIGN KEY (user_id) REFERENCES user_profiles(id)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
