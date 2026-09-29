-- noir_outposts 001_initial
-- Timestamps em epoch UTC (segundos). Valores monetários inteiros.

CREATE TABLE IF NOT EXISTS noir_outposts (
    id VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'inactive',
    operation_type VARCHAR(16) NULL,
    rotation_id BIGINT UNSIGNED NULL,
    owner_organization_id VARCHAR(64) NULL,
    kingpin_citizenid VARCHAR(64) NULL,
    claimed_at INT UNSIGNED NULL,
    expires_at INT UNSIGNED NULL,
    claim_session_id VARCHAR(64) NULL,
    claim_organization_id VARCHAR(64) NULL,
    claim_started_at INT UNSIGNED NULL,
    purse_available BIGINT UNSIGNED NOT NULL DEFAULT 0,
    purse_pending BIGINT UNSIGNED NOT NULL DEFAULT 0,
    last_corner_rotation_at INT UNSIGNED NULL,
    expiry_warned_at INT UNSIGNED NULL,
    version INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_outposts_owner (owner_organization_id),
    INDEX idx_outposts_rotation (rotation_id, status)
);

CREATE TABLE IF NOT EXISTS noir_outpost_dealers (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    outpost_id VARCHAR(40) NOT NULL,
    profile_key VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'deployed',
    corner_index SMALLINT UNSIGNED NULL,
    hired_by_citizenid VARCHAR(64) NOT NULL,
    hired_at INT UNSIGNED NOT NULL,
    next_sale_at INT UNSIGNED NULL,
    robbed_until INT UNSIGNED NULL,
    lifetime_sales BIGINT UNSIGNED NOT NULL DEFAULT 0,
    lifetime_gross BIGINT UNSIGNED NOT NULL DEFAULT 0,
    version INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_outpost_profile (outpost_id, profile_key),
    INDEX idx_dealers_due (status, next_sale_at),
    CONSTRAINT fk_dealer_outpost FOREIGN KEY (outpost_id)
        REFERENCES noir_outposts (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS noir_outpost_stock (
    outpost_id VARCHAR(40) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (outpost_id, item_name),
    CONSTRAINT fk_stock_outpost FOREIGN KEY (outpost_id)
        REFERENCES noir_outposts (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS noir_outpost_operations (
    operation_id CHAR(36) NOT NULL,
    operation_type VARCHAR(24) NOT NULL,
    outpost_id VARCHAR(40) NOT NULL,
    dealer_id BIGINT UNSIGNED NULL,
    citizenid VARCHAR(64) NULL,
    organization_id VARCHAR(64) NULL,
    item_name VARCHAR(64) NULL,
    quantity INT UNSIGNED NULL,
    gross_amount BIGINT UNSIGNED NULL,
    net_amount BIGINT UNSIGNED NULL,
    status VARCHAR(20) NOT NULL,
    request_id VARCHAR(64) NULL,
    payload JSON NULL,
    created_at INT UNSIGNED NOT NULL,
    committed_at INT UNSIGNED NULL,
    PRIMARY KEY (operation_id),
    INDEX idx_operations_outpost (outpost_id, created_at),
    INDEX idx_operations_status (status, created_at),
    INDEX idx_operations_request (citizenid, request_id)
);

CREATE TABLE IF NOT EXISTS noir_outpost_rotations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    cycle_key VARCHAR(32) NOT NULL,
    starts_at INT UNSIGNED NOT NULL,
    ends_at INT UNSIGNED NOT NULL,
    state JSON NOT NULL,
    created_at INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_rotation_cycle (cycle_key)
);

CREATE TABLE IF NOT EXISTS noir_outpost_organizations (
    organization_id VARCHAR(64) NOT NULL,
    claim_cooldown_until INT UNSIGNED NULL,
    last_claim_at INT UNSIGNED NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (organization_id)
);

CREATE TABLE IF NOT EXISTS noir_outpost_migrations (
    name VARCHAR(64) NOT NULL,
    applied_at INT UNSIGNED NOT NULL,
    PRIMARY KEY (name)
);
