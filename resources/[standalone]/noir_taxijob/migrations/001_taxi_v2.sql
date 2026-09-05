-- noir_taxijob · Taxi V2 · schema (também criado automaticamente pelo resource em MySQL.ready)
-- Não remove nem altera as tabelas legadas (`ak4y_taxi`, `noir_taxijob`).

CREATE TABLE IF NOT EXISTS `noir_taxi_profiles` (
    `citizenid` VARCHAR(50) NOT NULL,
    `display_name` VARCHAR(48) NOT NULL DEFAULT '',
    `confidence` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `completed_rides` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `confidence_reached_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `schema_version` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    `migrated_from` VARCHAR(32) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    INDEX `idx_noir_taxi_ranking` (`completed_rides`, `confidence` DESC, `confidence_reached_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noir_taxi_daily_stats` (
    `citizenid` VARCHAR(50) NOT NULL,
    `day_key` CHAR(10) NOT NULL,
    `earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `completed_rides` INT UNSIGNED NOT NULL DEFAULT 0,
    `confidence_earned` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `day_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noir_taxi_fare_results` (
    `fare_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `fare_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `confidence_delta` INT UNSIGNED NOT NULL DEFAULT 0,
    `distance_meters` INT UNSIGNED NOT NULL DEFAULT 0,
    `satisfaction` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `day_key` CHAR(10) NOT NULL,
    `completed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`fare_id`),
    INDEX `idx_noir_taxi_fare_citizen` (`citizenid`, `day_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
