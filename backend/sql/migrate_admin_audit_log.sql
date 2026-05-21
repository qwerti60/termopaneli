-- Журнал действий администратора в веб-админке (§16 development_plan).
-- Идемпотентно: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS admin_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  admin_login VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'логин из admin_accounts или пусто',
  action VARCHAR(80) NOT NULL COMMENT 'код события: admin_login, admin_logout, request_status, ...',
  target_type VARCHAR(40) NULL COMMENT 'тип сущности: estimate, estimate_request, panel, ...',
  target_id BIGINT UNSIGNED NULL,
  ip VARCHAR(45) NOT NULL DEFAULT '',
  detail TEXT NULL COMMENT 'человекочитаемое пояснение или JSON',
  PRIMARY KEY (id),
  KEY idx_admin_audit_created (created_at),
  KEY idx_admin_audit_action (action),
  KEY idx_admin_audit_target (target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
