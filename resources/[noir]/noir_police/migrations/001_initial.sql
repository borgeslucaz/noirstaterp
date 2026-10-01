-- noir_police: schema inicial. Só CREATE TABLE IF NOT EXISTS (server/storage.lua recusa o resto).

-- Pendências: cada item que um policial tirou do inventário de outro jogador.
-- Sai de 'pending' quando o depósito na sala de evidências bate com ela.
CREATE TABLE IF NOT EXISTS noir_police_seizures (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    officer_cid VARCHAR(64) NOT NULL,
    target_cid VARCHAR(64) NOT NULL,
    department VARCHAR(32) NOT NULL,
    item VARCHAR(64) NOT NULL,
    count INT UNSIGNED NOT NULL,
    serial VARCHAR(64) NULL,
    coords VARCHAR(64) NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    deposit_id INT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    KEY idx_seizures_officer_status (officer_cid, status),
    KEY idx_seizures_status_created (status, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Depósitos: cada seized_box entregue na sala de evidências.
CREATE TABLE IF NOT EXISTS noir_police_deposits (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    box_id VARCHAR(64) NOT NULL,
    department VARCHAR(32) NOT NULL,
    officer_cid VARCHAR(64) NOT NULL,
    target_cid VARCHAR(64) NULL,
    reason VARCHAR(255) NULL,
    contents LONGTEXT NOT NULL,
    unmatched LONGTEXT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'stored',
    resolved_by VARCHAR(64) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_deposits_box (box_id),
    KEY idx_deposits_department_status (department, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Placas marcadas (ANPR).
CREATE TABLE IF NOT EXISTS noir_police_flagged_plates (
    plate VARCHAR(16) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    officer_cid VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (plate)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
