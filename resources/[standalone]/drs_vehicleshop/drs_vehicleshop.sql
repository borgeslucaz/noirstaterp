-- Fresh-install reference schema for MySQL 8 or MariaDB. Existing installations
-- should let the resource's automatic runtime migrator perform the upgrade.
-- This file creates only the DRS journal-table and index names. Existing QR installs
-- must let the resource rename their journals in place before using this reference.
CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `license` varchar(50) DEFAULT NULL,
    `citizenid` varchar(50) DEFAULT NULL,
    `vehicle` varchar(64) DEFAULT NULL,
    `hash` varchar(50) DEFAULT NULL,
    `mods` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
    `plate` varchar(15) NOT NULL,
    `fakeplate` varchar(50) DEFAULT NULL,
    `garage` varchar(50) DEFAULT 'pillboxgarage',
    `fuel` int(11) DEFAULT 100,
    `engine` float DEFAULT 1000,
    `body` float DEFAULT 1000,
    `state` int(11) DEFAULT 1,
    `type` varchar(20) NOT NULL DEFAULT 'car',
    `stored` tinyint(1) NOT NULL DEFAULT 1,
    `job` varchar(50) DEFAULT NULL,
    `depotprice` int(11) NOT NULL DEFAULT 0,
    `drivingdistance` int(50) DEFAULT NULL,
    `status` text DEFAULT NULL,
    `coords` text DEFAULT NULL,
    `balance` int(11) NOT NULL DEFAULT 0,
    `paymentamount` int(11) NOT NULL DEFAULT 0,
    `paymentsleft` int(11) NOT NULL DEFAULT 0,
    `financetime` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `UK_playervehicles_plate` (`plate`),
    KEY `citizenid` (`citizenid`),
    KEY `license` (`license`),
    CONSTRAINT `FK_playervehicles_players` FOREIGN KEY (`citizenid`)
        REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- A plate is held here before any payment call. The reservation and journal row
-- are inserted in one transaction, closing concurrent checkout collisions.
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

-- Paid society fleet purchases use a separate journal because their payer is a
-- job account while the resulting player_vehicles row is ownerless and belongs
-- to `job`. Mixing these records into the personal-purchase recovery queries
-- would make refund and ownership reconciliation unsafe.
CREATE TABLE IF NOT EXISTS drs_vehicle_shop_fleet_orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id VARCHAR(64) NOT NULL,
    request_id VARCHAR(96) NOT NULL,
    caller_resource VARCHAR(64) NOT NULL,
    actor_citizenid VARCHAR(50) NOT NULL,
    actor_license VARCHAR(80) NULL,
    job VARCHAR(50) NOT NULL,
    model VARCHAR(64) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL,
    garage_index INT UNSIGNED NOT NULL,
    minimum_grade INT UNSIGNED NOT NULL DEFAULT 0,
    account VARCHAR(64) NOT NULL,
    bank_provider VARCHAR(32) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    purchase_reason VARCHAR(160) NULL,
    status VARCHAR(32) NOT NULL,
    vehicle_id BIGINT NULL,
    plate VARCHAR(15) NULL,
    garage_operation_id VARCHAR(96) NULL,
    failure_reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_drs_vehicle_shop_fleet_order_id (order_id),
    UNIQUE KEY uk_drs_vehicle_shop_fleet_request_id (request_id),
    KEY idx_drs_vehicle_shop_fleet_job_status (job, status),
    KEY idx_drs_vehicle_shop_fleet_actor_status (actor_citizenid, status),
    KEY idx_drs_vehicle_shop_fleet_plate (plate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
