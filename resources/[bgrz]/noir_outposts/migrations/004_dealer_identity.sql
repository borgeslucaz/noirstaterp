-- Nome e ped deixam de vir do perfil e passam a ser sorteados por corredor contratado.
-- Linhas antigas ficam nulas de propósito: o código cai no nome e no modelo do arquétipo.
ALTER TABLE noir_outpost_dealers ADD COLUMN IF NOT EXISTS display_name VARCHAR(32) NULL;
ALTER TABLE noir_outpost_dealers ADD COLUMN IF NOT EXISTS ped_model VARCHAR(64) NULL;
