-- ============================================================
-- Noir Truck V1 — esquema e migração
-- O resource executa esta migração automaticamente no start
-- (server/main.lua → RunMigrations). Este arquivo documenta o
-- resultado e pode ser aplicado manualmente.
-- ============================================================

-- Perfil (tabela legada preservada; ganha PK e novas colunas)
CREATE TABLE IF NOT EXISTS `peak_trucking` (
  `identifier` VARCHAR(64) NOT NULL,
  `points` LONGTEXT DEFAULT NULL,            -- reputação vitalícia por empresa (JSON {"0":n,...})
  `unlockedMissions` LONGTEXT DEFAULT NULL,  -- legado; disponibilidade agora é derivada de nível/reputação
  `dailymissions` LONGTEXT DEFAULT NULL,
  `level` INT(11) NOT NULL DEFAULT 1,
  `xp` INT(11) NOT NULL DEFAULT 0,
  `totalEarnings` BIGINT NOT NULL DEFAULT 0,
  `completedJobs` INT(11) NOT NULL DEFAULT 0,
  `failedJobs` INT(11) NOT NULL DEFAULT 0,
  `globalCompleted` INT(11) NOT NULL DEFAULT 0,
  `globalFailed` INT(11) NOT NULL DEFAULT 0,
  `name` VARCHAR(128) DEFAULT NULL,
  `avatar` VARCHAR(512) DEFAULT NULL,
  `history` LONGTEXT DEFAULT NULL,           -- legado; novas entregas ficam em peak_trucking_deliveries
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Migração de instalações antigas (idempotente; o servidor faz o mesmo em runtime)
-- ALTER TABLE `peak_trucking` ADD COLUMN `failedJobs` INT(11) NOT NULL DEFAULT 0;
-- ALTER TABLE `peak_trucking` ADD COLUMN `globalCompleted` INT(11) NOT NULL DEFAULT 0;
-- ALTER TABLE `peak_trucking` ADD COLUMN `globalFailed` INT(11) NOT NULL DEFAULT 0;
-- ALTER TABLE `peak_trucking` MODIFY `identifier` VARCHAR(64) NOT NULL;
-- ALTER TABLE `peak_trucking` ADD PRIMARY KEY (`identifier`);
-- Regra de migração da reputação: o saldo atual de `points` é mantido como
-- reputação vitalícia. Pontos gastos historicamente não são reconstruídos
-- e o saldo nunca é reduzido.

-- Rotações globais (uma linha por oferta única)
CREATE TABLE IF NOT EXISTS `peak_trucking_global_offers` (
  `offer_id` VARCHAR(96) NOT NULL,
  `rotation_id` VARCHAR(32) NOT NULL,
  `mission_id` INT NOT NULL,
  `route_index` INT NOT NULL,
  `tier` VARCHAR(16) NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'available', -- available|in_progress|completed|failed|failed_system|expired
  `driver_identifier` VARCHAR(64) NULL,
  `started_at` TIMESTAMP NULL,
  `finished_at` TIMESTAMP NULL,
  `result_reason` VARCHAR(64) NULL,
  PRIMARY KEY (`offer_id`),
  UNIQUE KEY `uq_rotation_route` (`rotation_id`, `mission_id`, `route_index`),
  UNIQUE KEY `uq_rotation_driver` (`rotation_id`, `driver_identifier`),
  KEY `ix_rotation_status` (`rotation_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Histórico normalizado de entregas (uma linha por sessão)
CREATE TABLE IF NOT EXISTS `peak_trucking_deliveries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` VARCHAR(96) NOT NULL,
  `identifier` VARCHAR(64) NOT NULL,
  `rotation_id` VARCHAR(32) NOT NULL,
  `offer_id` VARCHAR(96) NOT NULL,
  `mission_id` INT NOT NULL,
  `route_index` INT NOT NULL,
  `tier` VARCHAR(16) NOT NULL,
  `grade` CHAR(1) NULL,
  `score` DECIMAL(5,2) NULL,
  `base_payment` INT NOT NULL DEFAULT 0,
  `bonus_payment` INT NOT NULL DEFAULT 0,
  `penalty_payment` INT NOT NULL DEFAULT 0,
  `final_payment` INT NOT NULL DEFAULT 0,
  `xp_awarded` INT NOT NULL DEFAULT 0,
  `reputation_awarded` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(16) NOT NULL,             -- in_progress|completed|failed|failed_system
  `result_reason` VARCHAR(64) NULL,
  `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `finished_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_session` (`session_id`),
  KEY `ix_player_finished` (`identifier`, `finished_at`),
  KEY `ix_rotation` (`rotation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
