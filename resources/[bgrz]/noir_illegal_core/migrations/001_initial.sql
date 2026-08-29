CREATE TABLE IF NOT EXISTS noir_illegal_schema_migrations (
  version VARCHAR(64) NOT NULL,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_profiles (
  citizenid VARCHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_player_reputation (
  citizenid VARCHAR(64) NOT NULL,
  category VARCHAR(64) NOT NULL,
  value DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (citizenid, category),
  CONSTRAINT chk_noir_illegal_player_rep_nonnegative CHECK (value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_organization_reputation (
  organization_id VARCHAR(64) NOT NULL,
  category VARCHAR(64) NOT NULL,
  value DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (organization_id, category),
  CONSTRAINT chk_noir_illegal_org_rep_nonnegative CHECK (value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_player_heat (
  citizenid VARCHAR(64) NOT NULL,
  value DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  last_decay_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (citizenid),
  CONSTRAINT chk_noir_illegal_player_heat_nonnegative CHECK (value >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_unlocks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject_type ENUM('player', 'organization') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  unlock_key VARCHAR(96) NOT NULL,
  state ENUM('granted', 'revoked') NOT NULL DEFAULT 'granted',
  source VARCHAR(96) NOT NULL,
  granted_by VARCHAR(128) NULL,
  reason VARCHAR(255) NULL,
  metadata JSON NULL,
  granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_noir_illegal_unlock_subject_key (subject_type, subject_id, unlock_key),
  KEY idx_noir_illegal_unlock_lookup (subject_type, subject_id, state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_cooldowns (
  subject_type ENUM('player', 'organization') NOT NULL,
  subject_id VARCHAR(64) NOT NULL,
  cooldown_key VARCHAR(128) NOT NULL,
  expires_at DATETIME NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (subject_type, subject_id, cooldown_key),
  KEY idx_noir_illegal_cooldown_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_activity_ledger (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  transaction_id CHAR(36) NOT NULL,
  activity_key VARCHAR(96) NOT NULL,
  caller_resource VARCHAR(128) NOT NULL,
  citizenid VARCHAR(64) NOT NULL,
  organization_id VARCHAR(64) NULL,
  status ENUM('accepted', 'rejected') NOT NULL,
  rejection_code VARCHAR(64) NULL,
  base_personal JSON NOT NULL,
  applied_personal JSON NOT NULL,
  base_organization JSON NOT NULL,
  applied_organization JSON NOT NULL,
  base_heat DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  applied_heat DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  diminishing_multiplier DECIMAL(8,4) NOT NULL DEFAULT 1.0000,
  metadata JSON NULL,
  result_payload JSON NULL,
  occurred_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_noir_illegal_ledger_transaction (transaction_id),
  KEY idx_noir_illegal_ledger_citizen_activity_time (citizenid, activity_key, occurred_at),
  KEY idx_noir_illegal_ledger_org_activity_time (organization_id, activity_key, occurred_at),
  KEY idx_noir_illegal_ledger_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS noir_illegal_audit_log (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  action VARCHAR(96) NOT NULL,
  actor_type ENUM('resource', 'player', 'console', 'system') NOT NULL,
  actor_id VARCHAR(128) NOT NULL,
  target_type VARCHAR(32) NULL,
  target_id VARCHAR(128) NULL,
  transaction_id CHAR(36) NULL,
  before_state JSON NULL,
  after_state JSON NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_noir_illegal_audit_target (target_type, target_id, created_at),
  KEY idx_noir_illegal_audit_transaction (transaction_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO noir_illegal_schema_migrations (version)
VALUES ('001_initial');
