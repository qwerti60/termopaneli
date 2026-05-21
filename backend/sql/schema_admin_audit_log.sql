-- Схема журнала админ-действий (новые установки; для существующих БД — migrate_admin_audit_log.sql).

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  admin_login VARCHAR(64) NOT NULL DEFAULT '',
  action VARCHAR(80) NOT NULL,
  target_type VARCHAR(40) NULL,
  target_id BIGINT UNSIGNED NULL,
  ip VARCHAR(45) NOT NULL DEFAULT '',
  detail TEXT NULL,
  PRIMARY KEY (id),
  KEY idx_admin_audit_created (created_at),
  KEY idx_admin_audit_action (action),
  KEY idx_admin_audit_target (target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
