-- Fonte única do schema do noir_skills. Todo statement precisa ser idempotente: o arquivo
-- roda inteiro a cada start do resource, sem tabela de controle.
--
-- Uma linha por (personagem, habilidade), guardando só o XP bruto. Nível não é coluna:
-- ele é derivado da curva do config, então mudar a curva não pede migração de dado.
CREATE TABLE IF NOT EXISTS `noir_skills` (
 `citizenid` VARCHAR(64) NOT NULL,
 `skill` VARCHAR(64) NOT NULL,
 `xp` INT UNSIGNED NOT NULL DEFAULT 0,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`citizenid`, `skill`),
 INDEX `idx_noir_skills_skill_xp` (`skill`, `xp`)
);
