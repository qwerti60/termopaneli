-- Получатели для рассылки (импорт из 2ГИС и др.) + журнал отправок.
-- Выполнить на сервере: mysql ... < migrate_mail_leads.sql

CREATE TABLE IF NOT EXISTS mail_leads (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NULL DEFAULT NULL,
    address VARCHAR(512) NULL DEFAULT NULL,
    source VARCHAR(64) NULL DEFAULT NULL COMMENT 'например 2gis:Поесть',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_mail_leads_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mail_campaign_log (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    campaign VARCHAR(64) NOT NULL DEFAULT 'default',
    email VARCHAR(255) NOT NULL,
    lead_id INT UNSIGNED NULL DEFAULT NULL,
    subject VARCHAR(500) NOT NULL,
    subject_hash CHAR(64) NOT NULL,
    body_hash CHAR(64) NOT NULL,
    status ENUM('sent', 'failed', 'skipped') NOT NULL DEFAULT 'sent',
    error_message VARCHAR(512) NULL DEFAULT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_mail_campaign_log_email (email),
    KEY idx_mail_campaign_log_campaign (campaign),
    KEY idx_mail_campaign_log_subject_hash (subject_hash),
    KEY idx_mail_campaign_log_body_hash (body_hash),
    CONSTRAINT fk_mail_campaign_log_lead
        FOREIGN KEY (lead_id) REFERENCES mail_leads (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
