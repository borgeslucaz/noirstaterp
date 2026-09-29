-- noir_outposts 006_claim_dealer_roster
-- Elenco de nomes e modelos sorteado quando a tomada é concluída.

ALTER TABLE noir_outposts ADD COLUMN IF NOT EXISTS dealer_roster JSON NULL;
