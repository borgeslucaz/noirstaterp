-- noir_police: bônus por apreensão destruída. Uma linha por depósito (o bônus sai uma vez
-- só); `paid` = 0 quando o policial estava offline e recebe no próximo ponto batido.
CREATE TABLE IF NOT EXISTS noir_police_seizure_bonus (
    deposit_id INT UNSIGNED NOT NULL,
    officer_cid VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    base_value INT UNSIGNED NOT NULL,
    paid TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (deposit_id),
    KEY idx_seizure_bonus_officer (officer_cid, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
