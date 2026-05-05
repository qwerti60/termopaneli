-- Каталог дополнительных материалов для API.
-- Перед запуском сделайте бэкап БД.

CREATE TABLE IF NOT EXISTS catalog_materials (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  sku VARCHAR(64) NOT NULL,
  category VARCHAR(50) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT NULL,
  material VARCHAR(100) NULL,
  color VARCHAR(100) NULL,
  texture VARCHAR(100) NULL,
  thickness_mm DECIMAL(10,2) NULL,
  width_mm DECIMAL(10,2) NULL,
  length_mm DECIMAL(10,2) NULL,
  unit VARCHAR(50) NOT NULL DEFAULT 'шт',
  price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  image_path VARCHAR(255) NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 100,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_catalog_materials_sku (sku),
  KEY idx_catalog_materials_category_active (category, is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO catalog_materials
  (sku, category, name, description, material, color, texture, thickness_mm, width_mm, length_mm, unit, price, image_path, is_active, sort_order)
VALUES
  ('SLP-PL-WHT-150', 'slope', 'Откос пластиковый белый 150 мм', 'Пластиковый откос для оконных и дверных проемов.', 'Пластик', 'Белый', NULL, NULL, 150, 3000, 'шт', 0, 'catalog/slopes/slope_plastic_white_150.jpg', 1, 10),
  ('SLP-PL-WHT-200', 'slope', 'Откос пластиковый белый 200 мм', 'Пластиковый откос увеличенной ширины для глубоких проемов.', 'Пластик', 'Белый', NULL, NULL, 200, 3000, 'шт', 0, 'catalog/slopes/slope_plastic_white_200.jpg', 1, 20),
  ('SLP-PL-BRN-150', 'slope', 'Откос пластиковый коричневый 150 мм', 'Пластиковый откос коричневого цвета.', 'Пластик', 'Коричневый', NULL, NULL, 150, 3000, 'шт', 0, 'catalog/slopes/slope_plastic_brown_150.jpg', 1, 30),
  ('SLP-MT-WHT-150', 'slope', 'Откос металлический белый 150 мм', 'Металлический откос для наружного оформления проемов.', 'Металл', 'Белый', NULL, NULL, 150, 2000, 'шт', 0, 'catalog/slopes/slope_metal_white_150.jpg', 1, 40),
  ('SLP-MT-BRN-200', 'slope', 'Откос металлический коричневый 200 мм', 'Металлический откос коричневого цвета для глубоких проемов.', 'Металл', 'Коричневый', NULL, NULL, 200, 2000, 'шт', 0, 'catalog/slopes/slope_metal_brown_200.jpg', 1, 50),
  ('CRN-PL-WHT-50', 'corner', 'Уголок пластиковый белый 50x50', 'Пластиковый уголок для оформления внешних углов фасада.', 'Пластик', 'Белый', NULL, NULL, 50, 3000, 'шт', 0, 'catalog/elements/corner_plastic_white_50.jpg', 1, 110),
  ('CRN-MT-BRN-50', 'corner', 'Уголок металлический коричневый 50x50', 'Металлический уголок коричневого цвета.', 'Металл', 'Коричневый', NULL, NULL, 50, 2000, 'шт', 0, 'catalog/elements/corner_metal_brown_50.jpg', 1, 120),
  ('GRT-GRAY-25', 'grout', 'Затирка серая 25 кг', 'Затирочная смесь для межпанельных швов.', 'Смесь', 'Серый', NULL, NULL, NULL, NULL, 'мешок', 0, 'catalog/elements/grout_gray_25kg.jpg', 1, 210),
  ('EBB-MT-WHT-150', 'ebb', 'Отлив металлический белый 150 мм', 'Металлический оконный отлив белого цвета.', 'Металл', 'Белый', NULL, NULL, 150, 2000, 'шт', 0, 'catalog/elements/ebb_metal_white_150.jpg', 1, 310),
  ('SFT-PL-WHT-PERF', 'soffit', 'Софит пластиковый белый перфорированный', 'Перфорированный софит для подшивки карнизных свесов.', 'Пластик', 'Белый', 'Перфорированный', NULL, NULL, 3000, 'шт', 0, 'catalog/elements/soffit_plastic_white_perf.jpg', 1, 410),
  ('PLN-START', 'plinth', 'Стартовый профиль для цоколя', 'Стартовый профиль для монтажа цокольной части.', 'Металл', 'Оцинкованный', NULL, NULL, NULL, 2000, 'шт', 0, 'catalog/elements/plinth_start_profile.jpg', 1, 510),
  ('FST-DWL-100', 'fastener', 'Дюбель фасадный 100 мм', 'Крепеж для монтажа фасадных термопанелей.', 'Металл/пластик', 'Стандарт', NULL, NULL, NULL, 100, 'шт', 0, 'catalog/elements/fastener_dowel_100.jpg', 1, 610),
  ('CNS-FOAM', 'consumable', 'Монтажная пена', 'Расходный материал для монтажных работ.', 'Смесь', 'Стандарт', NULL, NULL, NULL, NULL, 'баллон', 0, 'catalog/elements/consumable_foam.jpg', 1, 710)
ON DUPLICATE KEY UPDATE
  category = VALUES(category),
  name = VALUES(name),
  description = VALUES(description),
  material = VALUES(material),
  color = VALUES(color),
  texture = VALUES(texture),
  thickness_mm = VALUES(thickness_mm),
  width_mm = VALUES(width_mm),
  length_mm = VALUES(length_mm),
  unit = VALUES(unit),
  image_path = VALUES(image_path),
  is_active = VALUES(is_active),
  sort_order = VALUES(sort_order);
