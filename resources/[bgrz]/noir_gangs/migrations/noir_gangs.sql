-- Fonte única do schema do noir_gangs. Todo statement precisa ser idempotente:
-- o arquivo roda inteiro a cada start do resource, sem tabela de controle.
CREATE TABLE IF NOT EXISTS `noir_gang_locations` (
 `id` INT UNSIGNED NOT NULL AUTO_INCREMENT, `gang_name` VARCHAR(64) NOT NULL,
 `location_type` VARCHAR(32) NOT NULL, `x` DOUBLE NOT NULL, `y` DOUBLE NOT NULL,
 `z` DOUBLE NOT NULL, `heading` FLOAT NOT NULL DEFAULT 0,
 `size_x` FLOAT NOT NULL DEFAULT 1.5, `size_y` FLOAT NOT NULL DEFAULT 1.5,
 `size_z` FLOAT NOT NULL DEFAULT 1.5, `created_by` VARCHAR(128) NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`id`), INDEX `idx_noir_gang_locations_gang` (`gang_name`),
 INDEX `idx_noir_gang_locations_type` (`location_type`)
);
CREATE TABLE IF NOT EXISTS `noir_gang_activity` (
 `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, `gang_name` VARCHAR(64) NOT NULL,
 `action` VARCHAR(64) NOT NULL, `actor_citizenid` VARCHAR(64) NULL,
 `target_citizenid` VARCHAR(64) NULL, `metadata` JSON NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`),
 INDEX `idx_noir_gang_activity_gang_id` (`gang_name`, `id`)
);
-- A leitura do histórico é `WHERE gang_name = ? ORDER BY id DESC LIMIT n`. O índice antigo
-- terminava em `created_at`, então o servidor filtrava pela gang e ordenava à parte — um
-- filesort sobre tudo que aquela gang já fez, a cada leitura. Com `(gang_name, id)` a
-- ordem já vem do índice e só as linhas mostradas são lidas. Em banco que já existe o
-- índice antigo continua lá sem atrapalhar; apagá-lo é manual, porque este arquivo roda a
-- cada start e nada aqui pode destruir.
CREATE INDEX IF NOT EXISTS `idx_noir_gang_activity_gang_id` ON `noir_gang_activity` (`gang_name`, `id`);
CREATE TABLE IF NOT EXISTS `noir_gang_state` (
 `gang_name` VARCHAR(64) NOT NULL, `reputation` INT NOT NULL DEFAULT 0,
 `archetype` VARCHAR(32) NOT NULL DEFAULT 'gueto',
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`gang_name`)
);
CREATE TABLE IF NOT EXISTS `noir_gang_products` (
 `gang_name` VARCHAR(64) NOT NULL, `product_type` VARCHAR(32) NOT NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (`gang_name`, `product_type`),
 INDEX `idx_noir_gang_products_type` (`product_type`)
);
-- `noir_gang_state` deixou de ser só o placar da gang: ela é o registro de quais gangs
-- existem. O rótulo e a cor entram por ALTER porque a tabela já está em produção.
ALTER TABLE `noir_gang_state` ADD COLUMN IF NOT EXISTS `label` VARCHAR(64) NOT NULL DEFAULT '';
ALTER TABLE `noir_gang_state` ADD COLUMN IF NOT EXISTS `color` VARCHAR(16) NOT NULL DEFAULT '';
-- Produtos deixaram de sair do config a cada start quando o editor entrou. Esta marca é o
-- que separa "nunca foi semeada" de "foi esvaziada de propósito": sem ela, tirar o último
-- produto em jogo seria desfeito no start seguinte.
ALTER TABLE `noir_gang_state` ADD COLUMN IF NOT EXISTS `products_seeded` TINYINT(1) NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS `noir_gang_ranks` (
 `gang_name` VARCHAR(64) NOT NULL, `level` INT NOT NULL, `label` VARCHAR(64) NOT NULL,
 `is_boss` TINYINT(1) NOT NULL DEFAULT 0, `bank_auth` TINYINT(1) NOT NULL DEFAULT 0,
 `permissions` JSON NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`gang_name`, `level`)
);

-- `level` é IDENTIDADE e `sort_order` é POSIÇÃO. Enquanto eram a mesma coluna, criar um
-- cargo no meio da escada obrigava a renumerar quem estava acima -- e renumerar um cargo
-- significa mover cada membro dele de nível, no `player_groups` e no `players.gang` do
-- Qbox. Foi assim que um cargo "TESTE" criado no nível 3 empurrou o Boss do vagos para o
-- 4 e deixou membros com os dois lados dessincronizados.
--
-- Separadas, `level` nunca muda depois de atribuído e `sort_order` muda à vontade: nada
-- persiste contra ela.
--
-- O default -1 é sentinela de "linha antiga, nunca ordenada". O carregador troca por
-- `level` no primeiro start, preservando exatamente a ordem que a gang já tinha.
ALTER TABLE `noir_gang_ranks` ADD COLUMN IF NOT EXISTS `sort_order` INT NOT NULL DEFAULT -1;

-- Marca d'água dos níveis de cargo já usados por cada gang.
--
-- Antes ela era lida do provider, que nunca esquecia um grade publicado. Sem publicar, a
-- memória precisa ser nossa: sem ela, apagar o cargo mais alto e criar outro reaproveitaria
-- o número, e o histórico -- que grava `oldGrade`/`newGrade` como inteiros -- passaria a
-- dizer duas coisas diferentes com o mesmo número.
ALTER TABLE `noir_gang_state` ADD COLUMN IF NOT EXISTS `next_rank_level` INT NOT NULL DEFAULT 0;

-- Membresia. A partir daqui ela é NOSSA, e não do `player_groups` do Qbox.
--
-- Enquanto morava lá, o mesmo dado existia em dois lugares -- `player_groups.grade` e
-- `players.gang` -- e o Qbox conseguia rebaixar um sem tocar no outro, em silêncio, a cada
-- republicação de gang. Não havia conserto por relog: o login relê a coluna errada.
--
-- Uma linha por personagem: o servidor sempre tratou gang como exclusiva, e a chave
-- primária passa a garantir isso em vez de depender de um teto configurado.
CREATE TABLE IF NOT EXISTS `noir_gang_members` (
 `citizenid` VARCHAR(64) NOT NULL,
 `gang_name` VARCHAR(64) NOT NULL,
 `level` INT NOT NULL,
 `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`citizenid`),
 INDEX `idx_noir_gang_members_gang` (`gang_name`, `level`)
);
