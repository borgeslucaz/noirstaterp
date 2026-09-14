-- Fonte única do schema do noir_gangs. Todo statement precisa ser idempotente:
-- o arquivo roda inteiro a cada start do resource, sem tabela de controle.
CREATE TABLE IF NOT EXISTS `noir_gang_locations` (
 `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `gang_name` VARCHAR(64) NOT NULL,
 `location_type` VARCHAR(32) NOT NULL, `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL,
 `z` DOUBLE NOT NULL, `heading` FLOAT NOT NULL DEFAULT 0,
 `size_x` FLOAT NOT NULL DEFAULT 1.5, `size_y` FLOAT NOT NULL DEFAULT 1.5,
 `size_z` FLOAT NOT NULL DEFAULT 1.5, `created_by` VARCHAR(128) NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`id`), INDEX `idx_noir_gang_locations_gang` (`gang_name`),
 INDEX `idx_noir_gang_locations_type` (`location_type`)
);
CREATE TABLE IF NOT EXISTS `noir_gang_activity` (
 `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `gang_name` VARCHAR(64) NOT NULL,
 `action` VARCHAR(64) NOT NULL, `actor_citizenid` VARCHAR(64) NULL,
 `target_citizenid` VARCHAR(64) NULL, `metadata` JSON NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`),
 INDEX `idx_noir_gang_activity_gang_created` (`gang_name`, `created_at`)
);
CREATE TABLE IF NOT EXISTS `noir_gang_state` (
 `gang_name` VARCHAR(64) NOT NULL, `reputation` INT NOT NULL DEFAULT 0,
 `archetype` VARCHAR(32) NOT NULL DEFAULT 'gueto',
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`gang_name`)
);
CREATE TABLE IF NOT EXISTS `noir_gang_products` (
 `gang_name` VARCHAR(64) NOT NULL, `product_type` VARCHAR(32) NOT NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (`gang_name`, `product_type`),
 INDEX `idx_noir_gang_products_type` (`product_type`)
);
CREATE TABLE IF NOT EXISTS `noir_gang_ranks` (
 `gang_name` VARCHAR(64) NOT NULL, `level` INT NOT NULL, `label` VARCHAR(64) NOT NULL,
 `is_boss` TINYINT(1) NOT NULL DEFAULT 0, `bank_auth` TINYINT(1) NOT NULL DEFAULT 0,
 `permissions` JSON NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`gang_name`, `level`)
);
