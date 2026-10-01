-- noir_police: posições editadas em jogo (/policiaeditor). Uma linha por tipo; sem linha,
-- vale o que está no config.
CREATE TABLE IF NOT EXISTS noir_police_layout (
    kind VARCHAR(32) NOT NULL,
    data LONGTEXT NOT NULL,
    updated_by VARCHAR(64) NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (kind)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
