-- Подписки PRO и журнал попыток оплаты (до подключения эквайринга — события checkout_stub).
-- Повторный запуск безопасен (CREATE TABLE IF NOT EXISTS).

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  plan_code VARCHAR(16) NOT NULL COMMENT '1m,3m,6m,1y',
  status ENUM('pending','active','cancelled','expired') NOT NULL DEFAULT 'pending',
  price_rub DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  started_at DATETIME NULL DEFAULT NULL,
  expires_at DATETIME NULL DEFAULT NULL,
  cancelled_at DATETIME NULL DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_us_user_status (user_id, status),
  KEY idx_us_expires (expires_at),
  CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES user_profiles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS subscription_payment_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  subscription_id INT UNSIGNED NULL DEFAULT NULL,
  plan_code VARCHAR(16) NOT NULL DEFAULT '',
  amount_rub DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  event_type VARCHAR(48) NOT NULL COMMENT 'checkout_stub, subscription_cancelled, …',
  detail VARCHAR(512) NULL DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_spe_user (user_id),
  KEY idx_spe_created (created_at),
  KEY idx_spe_sub (subscription_id),
  CONSTRAINT fk_spe_user FOREIGN KEY (user_id) REFERENCES user_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_spe_sub FOREIGN KEY (subscription_id) REFERENCES user_subscriptions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
