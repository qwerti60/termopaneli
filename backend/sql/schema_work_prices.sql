-- Тестовый прайс работ для сметы.
-- Перед запуском сделайте бэкап БД.

CREATE TABLE IF NOT EXISTS work_prices (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sku VARCHAR(64) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT NULL,
  unit VARCHAR(50) NOT NULL DEFAULT 'шт',
  price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  calc_rule VARCHAR(50) NOT NULL DEFAULT 'manual',
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 100,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_work_prices_sku (sku),
  KEY idx_work_prices_active_sort (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO work_prices
  (sku, name, description, unit, price, calc_rule, is_default, is_active, sort_order)
VALUES
  ('WORK-FACADE-PANEL-M2', 'Монтаж фасадных термопанелей', 'Монтаж фасадных термопанелей по площади фасада.', 'м²', 1800, 'facade_area_m2', 1, 1, 10),
  ('WORK-FACADE-PREP-M2', 'Подготовка основания', 'Подготовка основания под монтаж термопанелей.', 'м²', 350, 'facade_area_m2', 1, 1, 20),
  ('WORK-SCAFFOLD-M2', 'Монтаж/аренда лесов', 'Монтаж и аренда строительных лесов.', 'м²', 250, 'facade_area_m2', 0, 1, 30),
  ('WORK-SLOPE-LM', 'Монтаж откосов', 'Монтаж оконных и дверных откосов.', 'пог. м', 650, 'opening_perimeter_lm', 0, 1, 40),
  ('WORK-EBB-PCS', 'Монтаж отлива', 'Монтаж оконного отлива.', 'шт', 900, 'window_count', 0, 1, 50),
  ('WORK-CORNER-LM', 'Монтаж внешних углов', 'Монтаж внешних углов фасада.', 'пог. м', 700, 'corner_length_lm', 0, 1, 60),
  ('WORK-GROUT-M2', 'Затирка швов', 'Затирка межпанельных швов.', 'м²', 300, 'facade_area_m2', 1, 1, 70),
  ('WORK-SEALING-LM', 'Герметизация примыканий', 'Герметизация примыканий и стыков.', 'пог. м', 450, 'sealing_length_lm', 0, 1, 80),
  ('WORK-DELIVERY', 'Доставка материалов', 'Доставка материалов на объект.', 'выезд', 5000, 'fixed_once', 1, 1, 90),
  ('WORK-MEASURE', 'Выезд на замер', 'Выезд специалиста на замер.', 'выезд', 3000, 'fixed_once', 0, 1, 100)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  unit = VALUES(unit),
  price = VALUES(price),
  calc_rule = VALUES(calc_rule),
  is_default = VALUES(is_default),
  is_active = VALUES(is_active),
  sort_order = VALUES(sort_order);
