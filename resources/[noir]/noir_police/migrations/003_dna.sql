-- noir_police: banco de DNA da polícia. Uma linha por código; o código não revela o
-- personagem (hash com chave do servidor), então só a coleta liga um ao outro.
CREATE TABLE IF NOT EXISTS noir_police_dna (
    dna_code VARCHAR(32) NOT NULL,
    citizen_id VARCHAR(64) NOT NULL,
    taken_by VARCHAR(64) NULL,
    taken_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (dna_code)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
