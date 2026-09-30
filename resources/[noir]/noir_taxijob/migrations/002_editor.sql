-- Editor in-game (/editortaxi): catálogo no banco. O server/catalog.lua cria estas tabelas no
-- start e, com elas vazias, preenche com o config.lua. Este arquivo é só referência.

CREATE TABLE IF NOT EXISTS taxijob_points (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    data LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS taxijob_vehicles (
    id VARCHAR(24) NOT NULL,
    sort INT NOT NULL DEFAULT 0,
    data LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS taxijob_settings (
    `key` VARCHAR(32) NOT NULL,
    data LONGTEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`key`)
);

CREATE TABLE IF NOT EXISTS taxijob_editor_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    citizenid VARCHAR(50) NULL,
    player_name VARCHAR(100) NULL,
    action VARCHAR(16) NOT NULL,
    entity VARCHAR(16) NOT NULL,
    entity_id VARCHAR(32) NOT NULL,
    data LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_taxijob_editor_log_entity (entity, entity_id, created_at)
);
