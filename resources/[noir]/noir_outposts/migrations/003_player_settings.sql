-- noir_outposts 003_player_settings
-- Preferências de alerta e marcador de "limpo" por personagem.
-- Limpar notificações não apaga o ledger: guarda até quando o jogador já viu.

CREATE TABLE IF NOT EXISTS noir_outpost_player_settings (
    citizenid VARCHAR(64) NOT NULL,
    feed_cleared_at INT UNSIGNED NOT NULL DEFAULT 0,
    alerts JSON NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (citizenid)
);
