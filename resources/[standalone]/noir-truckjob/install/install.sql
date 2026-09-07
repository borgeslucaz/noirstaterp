-- Noir Truckjob V2. Aplicar em banco limpo; não há migração legada.
CREATE TABLE IF NOT EXISTS `noir_truckjob_players` (
  `identifier` VARCHAR(64) NOT NULL, `dailymissions` LONGTEXT DEFAULT NULL,
  `level` INT NOT NULL DEFAULT 1, `xp` INT NOT NULL DEFAULT 0,
  `totalEarnings` BIGINT NOT NULL DEFAULT 0, `completedJobs` INT NOT NULL DEFAULT 0,
  `failedJobs` INT NOT NULL DEFAULT 0, `globalCompleted` INT NOT NULL DEFAULT 0,
  `globalFailed` INT NOT NULL DEFAULT 0, `name` VARCHAR(128) DEFAULT NULL,
  `avatar` VARCHAR(512) DEFAULT NULL, PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noir_truckjob_offers` (
  `offer_id` VARCHAR(96) NOT NULL, `rotation_id` VARCHAR(32) NOT NULL,
  `route_id` VARCHAR(16) NOT NULL, `tier` VARCHAR(16) NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'available', `driver_identifier` VARCHAR(64) NULL,
  `started_at` TIMESTAMP NULL, `finished_at` TIMESTAMP NULL, `result_reason` VARCHAR(64) NULL,
  PRIMARY KEY (`offer_id`), UNIQUE KEY `uq_rotation_route` (`rotation_id`, `route_id`),
  UNIQUE KEY `uq_rotation_driver` (`rotation_id`, `driver_identifier`), KEY `ix_rotation_status` (`rotation_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `noir_truckjob_deliveries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `session_id` VARCHAR(96) NOT NULL,
  `identifier` VARCHAR(64) NOT NULL, `rotation_id` VARCHAR(32) NOT NULL,
  `offer_id` VARCHAR(96) NOT NULL, `route_id` VARCHAR(16) NOT NULL, `tier` VARCHAR(16) NOT NULL,
  `grade` CHAR(1) NULL, `score` DECIMAL(5,2) NULL, `base_payment` INT NOT NULL DEFAULT 0,
  `bonus_payment` INT NOT NULL DEFAULT 0, `penalty_payment` INT NOT NULL DEFAULT 0,
  `final_payment` INT NOT NULL DEFAULT 0, `xp_awarded` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(16) NOT NULL, `result_reason` VARCHAR(64) NULL,
  `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `finished_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uq_session` (`session_id`),
  KEY `ix_player_finished` (`identifier`, `finished_at`), KEY `ix_rotation` (`rotation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
