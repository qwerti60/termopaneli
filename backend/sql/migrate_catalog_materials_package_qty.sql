-- Округление количества в смете вверх до кратности упаковки (п. 5.2).
-- Клиент читает `package_qty` из `raw` в ответе `catalog/list.php`. NULL или 1 — без округления.
-- Таблица `catalog_materials` должна уже существовать (см. `schema_catalog_materials.sql`).
-- Повторный запуск безопасен: если колонка есть — выполняется пустой SELECT.

SET @schema := DATABASE();
SET @col_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = @schema
    AND TABLE_NAME = 'catalog_materials'
    AND COLUMN_NAME = 'package_qty'
);
SET @sql := IF(
  @col_exists > 0,
  'SELECT 1 AS package_qty_column_already_present',
  'ALTER TABLE catalog_materials
     ADD COLUMN package_qty INT UNSIGNED NULL DEFAULT NULL
       COMMENT ''Кратность упаковки (>=2); NULL — не округлять''
     AFTER length_mm'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
