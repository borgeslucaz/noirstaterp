-- A tabela também é criada sozinha no MySQL.ready (server/store.lua); este arquivo existe
-- para quem prefere aplicar o schema à mão.
--
-- A v1 do script tinha as colunas graffiti_type, gang_name e territory_id. Nada mais
-- escreve nelas: a tabela antiga foi derrubada e recriada neste formato em 14/09/2026.
CREATE TABLE IF NOT EXISTS `noir_graffiti` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `text_value` VARCHAR(64) NOT NULL,
    `font` VARCHAR(32) NOT NULL,
    `color` CHAR(7) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `normal_x` FLOAT NOT NULL,
    `normal_y` FLOAT NOT NULL,
    `normal_z` FLOAT NOT NULL,
    `rotation` FLOAT NOT NULL DEFAULT 0,
    `scale` FLOAT NOT NULL DEFAULT 1,
    `thickness` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `gang` VARCHAR(50) NULL,
    `placed_by` VARCHAR(64) NOT NULL,
    `placed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `removed_by` VARCHAR(64) NULL,
    `removed_at` TIMESTAMP NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_noir_graffiti_active` (`removed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
