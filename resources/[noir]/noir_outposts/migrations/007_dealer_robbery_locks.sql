-- noir_outposts 007_dealer_robbery_locks
-- Cooldown de assalto por identidade, separado da janela em que o corredor fica fora de operação.
--
-- `robbed_until`, na linha do corredor, continua respondendo "por quanto tempo ele não vende".
-- Esta tabela responde outra pergunta: "quem já o roubou e ainda não pode de novo". Uma trava por
-- gang vale para todos os membros dela; um jogador sem gang tranca a si mesmo.
--
-- O detentor é gravado como `gang:<id>` ou `citizen:<citizenid>`, e todo assalto grava os dois
-- quando há gang — senão sair da organização e voltar renderia um assalto extra.
--
-- A chave primária faz assalto repetido pelo mesmo detentor ATUALIZAR a linha em vez de criar
-- outra, e o CASCADE apaga tudo junto com o corredor: tomada nova contrata gente nova, e a conta
-- recomeça com ela.

CREATE TABLE IF NOT EXISTS noir_outpost_dealer_locks (
    dealer_id BIGINT UNSIGNED NOT NULL,
    holder VARCHAR(80) NOT NULL,
    locked_until INT UNSIGNED NOT NULL,
    locked_at INT UNSIGNED NOT NULL,
    PRIMARY KEY (dealer_id, holder),
    INDEX idx_dealer_locks_expiry (locked_until),
    CONSTRAINT fk_dealer_lock_dealer FOREIGN KEY (dealer_id)
        REFERENCES noir_outpost_dealers (id) ON DELETE CASCADE
);
