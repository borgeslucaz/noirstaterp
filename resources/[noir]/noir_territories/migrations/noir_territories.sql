-- Fonte única do schema do noir_territories. Todo statement precisa ser idempotente: o
-- arquivo roda inteiro a cada start do resource, sem tabela de controle.

-- Uma linha por (bairro, gang). O que não está aqui vale zero, e zero não é guardado: a
-- ausência da linha É a ausência de influência, e assim a tabela não acumula uma linha para
-- cada gang que passou uma vez por cada bairro.
--
-- `zone` é o nome do bairro no Zone Manager, e `gang` é o nome da gang no noir_gangs. Não há
-- chave estrangeira para nenhum dos dois de propósito: as duas pontas são donas do próprio
-- registro e apagar um bairro no editor não pode derrubar um INSERT aqui. Linha órfã é lixo
-- inofensivo — ninguém pergunta por bairro que não existe.
CREATE TABLE IF NOT EXISTS `noir_territory_influence` (
 `zone` VARCHAR(64) NOT NULL,
 `gang` VARCHAR(64) NOT NULL,
 `points` INT NOT NULL DEFAULT 0,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`zone`, `gang`),
 INDEX `idx_noir_territory_influence_gang` (`gang`)
);

-- A placa do bairro: quem é dono e desde quando.
--
-- Ownership deixou de ser derivado da distribuição de pontos quando a trava de domínio entrou:
-- "há quanto tempo esta gang é dona" não está escrito na influência. Uma linha por bairro, e só
-- enquanto ele tiver dono — bairro sem dono não tem linha, do mesmo jeito que gang sem ponto
-- não tem linha na tabela de influência.
--
-- `taken_at` é o relógio do servidor no momento da tomada, em segundos. É dele que sai a trava:
-- `taken_at + Config.OwnershipLockSeconds`.
CREATE TABLE IF NOT EXISTS `noir_territory_ownership` (
 `zone` VARCHAR(64) NOT NULL,
 `owner` VARCHAR(64) NOT NULL,
 `taken_at` BIGINT NOT NULL,
 `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY (`zone`),
 INDEX `idx_noir_territory_ownership_owner` (`owner`)
);

-- Concessões reversíveis: quanto CADA fato rendeu, para devolver exatamente aquilo.
--
-- Existe por causa do bônus de azarão. Duas tags da mesma gang no mesmo bairro valem números
-- diferentes — 21 quando ela era fraca, 10 depois que ficou forte —, e devolver a taxa do
-- config na hora de apagar abriria um ciclo: pichar fraco rende 21, apagar forte custaria 10, e
-- a diferença seria lucro repetível.
--
-- Guardar em memória não bastaria: o registro de tags é reconstruído do noir_graffiti a cada
-- start, e ele não sabe de influência. Sem esta tabela, toda tag posta antes do restart da noite
-- voltaria pela taxa cheia — o que não é um caso raro, é a rotina do servidor.
--
-- `grant_key` é o que identifica o fato do lado de quem o produziu: 'graffiti:1734' é a tag 1734.
CREATE TABLE IF NOT EXISTS `noir_territory_grant` (
 `grant_key` VARCHAR(96) NOT NULL,
 `zone` VARCHAR(64) NOT NULL,
 `gang` VARCHAR(64) NOT NULL,
 `points` INT NOT NULL,
 `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (`grant_key`),
 INDEX `idx_noir_territory_grant_zone` (`zone`, `gang`)
);

-- Devolução que não pôde acontecer na hora.
--
-- Apagar uma tag devolve ao pool o que ela rendeu, mas durante a trava de domínio o bairro está
-- parado e a devolução é recusada. Antes, o `revokeOnce` já tinha apagado a linha quando
-- descobria isso — a tag sumia, os pontos ficavam, e não havia registro de que alguém devia. Era
-- possível pichar, tomar o bairro e apagar as próprias tags dentro da janela protegida, ficando
-- com os pontos de graça.
--
-- Agora a linha fica, marcada com a hora em que a devolução foi pedida, e é liquidada quando a
-- trava cair. A marca é coluna, e não memória, porque a dívida precisa sobreviver a restart: a
-- tag já não existe, e ninguém voltaria a pedir a devolução dela.
ALTER TABLE `noir_territory_grant` ADD COLUMN IF NOT EXISTS `revoked_at` BIGINT NULL;

-- Quando alguma coisa aconteceu pela última vez em cada bairro.
--
-- É o relógio do esfriamento, e ele mede o bairro e não a gang: qualquer atividade ali dentro
-- reinicia a contagem. Precisa de coluna própria, e não do `updated_at` da tabela de influência,
-- porque o próprio esfriamento escreve influência — aquele carimbo diria "acabou de acontecer
-- algo aqui" logo depois de cada passo, e o bairro nunca mais esfriaria de novo.
--
-- Persistido porque um servidor que reinicia toda noite zeraria o relógio em memória, e o
-- abandono nunca completaria as horas que precisa.
CREATE TABLE IF NOT EXISTS `noir_territory_activity` (
 `zone` VARCHAR(64) NOT NULL,
 `last_activity` BIGINT NOT NULL,
 PRIMARY KEY (`zone`)
);
