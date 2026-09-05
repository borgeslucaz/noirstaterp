-- ─────────────────────────────────────────────────────────────────────────────
--  RD-Taxi  ·  database/rd_taxi.sql
--  OPTIONAL – only needed if you want persistent ride history logs.
--  Import this file once into your database.
--  The script works WITHOUT this table; it only uses it if
--  Config.LogRides = true (see config.lua).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `rd_taxi_logs` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id`    VARCHAR(64)  NOT NULL COMMENT 'FiveM server ID or identifier',
    `driver_id`    INT UNSIGNED NOT NULL COMMENT 'Config.TaxiDrivers id',
    `driver_name`  VARCHAR(64)  NOT NULL,
    `pickup_x`     FLOAT        NOT NULL,
    `pickup_y`     FLOAT        NOT NULL,
    `pickup_z`     FLOAT        NOT NULL,
    `dropoff_x`    FLOAT        NULL,
    `dropoff_y`    FLOAT        NULL,
    `dropoff_z`    FLOAT        NULL,
    `fare`         INT UNSIGNED NOT NULL DEFAULT 0,
    `completed`    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 = delivered, 0 = cancelled',
    `created_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_player` (`player_id`),
    INDEX `idx_driver` (`driver_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
