-- DRS Vehicle Shop + Qbox/Lunar Garage compatibility columns.
-- The resource applies these changes automatically. This file is only the manual
-- MariaDB fallback for servers whose oxmysql account intentionally lacks schema
-- privileges. MySQL 8 servers should temporarily grant those privileges and let the
-- runtime migrator use its INFORMATION_SCHEMA-based portable path.
-- Do not drop or recreate player_vehicles.
-- Existing QR installs must first rename both legacy journal tables to their DRS names
-- together, as documented in README.md. Do not run this file while legacy QR journal
-- tables still exist or when an old/new table-name collision needs reconciliation.

ALTER TABLE `player_vehicles`
    ADD COLUMN IF NOT EXISTS `job` VARCHAR(50) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `type` VARCHAR(20) NOT NULL DEFAULT 'car',
    ADD COLUMN IF NOT EXISTS `stored` TINYINT(1) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `state` INT(11) NULL DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `balance` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `paymentamount` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `paymentsleft` INT(11) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `financetime` INT(11) NOT NULL DEFAULT 0;

UPDATE `player_vehicles`
SET `state` = CASE WHEN `stored` = 1 THEN 1 ELSE 0 END
WHERE `state` IS NULL AND `stored` IS NOT NULL;

UPDATE `player_vehicles` SET `state` = 1 WHERE `state` IS NULL;

UPDATE `player_vehicles`
SET `stored` = CASE WHEN `state` = 1 THEN 1 ELSE 0 END
WHERE `stored` IS NULL;

ALTER TABLE `player_vehicles`
    MODIFY COLUMN `state` INT(11) NOT NULL DEFAULT 1,
    MODIFY COLUMN `stored` TINYINT(1) NOT NULL DEFAULT 1,
    MODIFY COLUMN `vehicle` VARCHAR(64) DEFAULT NULL;

CREATE INDEX IF NOT EXISTS `idx_player_vehicles_citizenid_type_stored`
    ON `player_vehicles` (`citizenid`, `type`, `stored`);

CREATE INDEX IF NOT EXISTS `idx_player_vehicles_job_type_stored`
    ON `player_vehicles` (`job`, `type`, `stored`);

-- Global plate uniqueness is required for safe entity/ownership handoff. Resolve any
-- duplicate legacy rows before importing if this statement reports a duplicate key.
CREATE UNIQUE INDEX IF NOT EXISTS `uk_player_vehicles_plate`
    ON `player_vehicles` (`plate`);

-- Durable DRS purchase journal. The resource also verifies/creates this table at startup.
CREATE TABLE IF NOT EXISTS drs_vehicle_shop_orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id VARCHAR(64) NOT NULL,
    request_id VARCHAR(96) NULL,
    citizenid VARCHAR(50) NOT NULL,
    shop_id VARCHAR(50) NOT NULL,
    model VARCHAR(64) NOT NULL,
    vehicle_type VARCHAR(20) NULL,
    delivery_mode VARCHAR(16) NULL,
    plate VARCHAR(15) NOT NULL,
    account VARCHAR(20) NOT NULL,
    base_amount INT UNSIGNED NOT NULL DEFAULT 0,
    options_amount INT UNSIGNED NOT NULL DEFAULT 0,
    amount INT UNSIGNED NOT NULL,
    customization LONGTEXT NULL,
    status VARCHAR(32) NOT NULL,
    vehicle_id BIGINT NULL,
    net_id INT NULL,
    failure_reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_drs_vehicle_shop_order_id (order_id),
    UNIQUE KEY uk_drs_vehicle_shop_request_id (request_id),
    KEY idx_drs_vehicle_shop_orders_citizen_status (citizenid, status),
    KEY idx_drs_vehicle_shop_orders_plate (plate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE drs_vehicle_shop_orders ADD COLUMN IF NOT EXISTS request_id VARCHAR(96) NULL AFTER order_id;
ALTER TABLE drs_vehicle_shop_orders ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(20) NULL AFTER model;
ALTER TABLE drs_vehicle_shop_orders ADD COLUMN IF NOT EXISTS delivery_mode VARCHAR(16) NULL AFTER vehicle_type;
ALTER TABLE drs_vehicle_shop_orders ADD COLUMN IF NOT EXISTS base_amount INT UNSIGNED NOT NULL DEFAULT 0 AFTER account;
ALTER TABLE drs_vehicle_shop_orders ADD COLUMN IF NOT EXISTS options_amount INT UNSIGNED NOT NULL DEFAULT 0 AFTER base_amount;
ALTER TABLE drs_vehicle_shop_orders ADD COLUMN IF NOT EXISTS customization LONGTEXT NULL AFTER amount;
CREATE UNIQUE INDEX IF NOT EXISTS uk_drs_vehicle_shop_request_id
    ON drs_vehicle_shop_orders (request_id);
CREATE UNIQUE INDEX IF NOT EXISTS uk_drs_vehicle_shop_order_id
    ON drs_vehicle_shop_orders (order_id);
CREATE INDEX IF NOT EXISTS idx_drs_vehicle_shop_orders_citizen_status
    ON drs_vehicle_shop_orders (citizenid, status);
CREATE INDEX IF NOT EXISTS idx_drs_vehicle_shop_orders_plate
    ON drs_vehicle_shop_orders (plate);

CREATE TABLE IF NOT EXISTS drs_vehicle_shop_plate_reservations (
    plate VARCHAR(15) NOT NULL,
    request_id VARCHAR(96) NOT NULL,
    order_id VARCHAR(64) NOT NULL,
    citizenid VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (plate),
    UNIQUE KEY uk_drs_vehicle_shop_reservation_request (request_id),
    UNIQUE KEY uk_drs_vehicle_shop_reservation_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE UNIQUE INDEX IF NOT EXISTS uk_drs_vehicle_shop_reservation_plate
    ON drs_vehicle_shop_plate_reservations (plate);
CREATE UNIQUE INDEX IF NOT EXISTS uk_drs_vehicle_shop_reservation_request
    ON drs_vehicle_shop_plate_reservations (request_id);
CREATE UNIQUE INDEX IF NOT EXISTS uk_drs_vehicle_shop_reservation_order
    ON drs_vehicle_shop_plate_reservations (order_id);

-- Canonical DRS indexes now protect the same columns, so legacy QR-named indexes can
-- be removed without changing journal rows. IF EXISTS keeps this MariaDB fallback
-- repeatable for fresh installs and partially completed manual upgrades.
-- Before this cleanup, review SHOW INDEX output and confirm that any already-present
-- DRS-named index has the column order and uniqueness shown above. IF NOT EXISTS checks
-- the index name, not its definition; stop instead of dropping a valid QR index when a
-- conflicting DRS name has been customized.
DROP INDEX IF EXISTS uk_qr_vehicle_shop_order_id ON drs_vehicle_shop_orders;
DROP INDEX IF EXISTS uk_qr_vehicle_shop_request_id ON drs_vehicle_shop_orders;
DROP INDEX IF EXISTS idx_qr_vehicle_shop_orders_citizen_status ON drs_vehicle_shop_orders;
DROP INDEX IF EXISTS idx_qr_vehicle_shop_orders_plate ON drs_vehicle_shop_orders;
DROP INDEX IF EXISTS uk_qr_vehicle_shop_reservation_plate ON drs_vehicle_shop_plate_reservations;
DROP INDEX IF EXISTS uk_qr_vehicle_shop_reservation_request ON drs_vehicle_shop_plate_reservations;
DROP INDEX IF EXISTS uk_qr_vehicle_shop_reservation_order ON drs_vehicle_shop_plate_reservations;
