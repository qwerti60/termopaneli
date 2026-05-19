-- Картинка для строки прайса работ (веб-админка).
-- Повторный запуск даст ошибку «Duplicate column» — это нормально.

ALTER TABLE work_prices
  ADD COLUMN image_path VARCHAR(255) NULL DEFAULT NULL COMMENT 'Путь относительно public' AFTER description;
