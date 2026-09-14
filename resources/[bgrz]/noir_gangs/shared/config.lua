Config = {}
Config.AdminAce = 'noir.gangsetup'
Config.Invitation = { maxDistance = 3.0, duration = 30, cooldown = 10 }
Config.ManagementDistance = 2.0
Config.DefaultGrade = 0
Config.DefaultZoneSize = vec3(1.5, 1.5, 1.5)
Config.ActivityLimit = 50
Config.LocationRequestCooldown = 3

---Enquanto não existe editor de cargos em jogo, o config manda: a cada start ele
---reescreve `noir_gang_ranks` e `noir_gang_products`. Reputação nunca é tocada, porque é
---dado vivo. No dia em que o editor entrar, vire isto para `false` e o banco passa a ser a
---verdade sem precisar de migração — as tabelas já estão no formato final, por gang.
Config.RanksFromConfig = true

-- ---------------------------------------------------------------------------
-- Permissões
-- ---------------------------------------------------------------------------
-- Catálogo fechado. Cada cargo declara as suas; não há herança entre cargos, então o que
-- está escrito no arquétipo é exatamente o que o cargo pode. Um nome fora desta lista
-- derruba o start, porque permissão com erro de digitação falha em silêncio: ela
-- simplesmente nunca é verdadeira, e ninguém descobre até precisar dela.
--
-- Só `promote` e `demote`/`remove_member` têm regra estrutural por cima da permissão:
-- quem é chefe (`isBoss`) não é desligado nem muda de cargo, e ninguém é promovido PARA
-- chefe. Liderança se troca por admin (`/setgang`), não por mecanismo de jogador.
Config.Permissions = {
    'view_members',        -- ver a lista de membros
    'view_offline_members',-- ver também quem está offline
    'invite',              -- convidar alguém próximo
    'remove_member',       -- expulsar
    'promote',             -- subir cargo de alguém abaixo
    'demote',              -- descer cargo de alguém abaixo
    'view_reputation',     -- ver a reputação da gang
    'view_products',       -- ver os produtos que a gang opera
}

-- ---------------------------------------------------------------------------
-- Produtos
-- ---------------------------------------------------------------------------
-- O que a gang opera. Destrava craft, laboratório e tipo de missão nos outros resources,
-- que perguntam por `HasGangProduct`/`GetGangProducts`. Normalmente uma gang tem um só,
-- mas o armazenamento é por (gang, produto), então várias já funcionam sem mudar nada.
Config.ProductTypes = {
    drugs       = { label = 'Drogas' },
    weapons     = { label = 'Armas' },
    items       = { label = 'Itens' },
    ammo        = { label = 'Munições' },
    attachments = { label = 'Acessórios de arma' },
}

-- ---------------------------------------------------------------------------
-- Arquétipos de cargo
-- ---------------------------------------------------------------------------
-- `level` é o número que o Qbox guarda; o rótulo é publicado lá por nós no start, porque
-- `PlayerData.gang.grade.name` é o que o resto do servidor lê. As permissões ficam só
-- aqui — o Qbox não tem conceito delas.
-- `isBoss` não é enfeite: é ele que torna o cargo intocável por jogador (não desliga, não
-- promove, não rebaixa, e ninguém é promovido até ele).
-- Os níveis não precisam ser contíguos nem começar em 0, mas o menor é a porta de entrada
-- de quem aceita convite e o maior é quem lidera.
Config.RankArchetypes = {
    -- Os quatro cargos que as gangs já usam hoje.
    gueto = {
        label = 'Gueto',
        ranks = {
            { level = 0, label = 'Recruit', permissions = { 'view_members' } },
            { level = 1, label = 'Enforcer', permissions = { 'view_members', 'view_reputation' } },
            -- O cargo abaixo do chefe gere de verdade. Como o chefe é intocável e ninguém é
            -- promovido até ele, se só ele pudesse promover e desligar, um chefe inativo
            -- deixaria a gang sem gestão e sem saída.
            { level = 2, label = 'Shot Caller', permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
                'view_reputation', 'view_products' } },
            { level = 3, label = 'Boss', isBoss = true, bankAuth = true, permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
                'view_reputation', 'view_products' } },
        },
    },

    mc = {
        label = 'Motoclube',
        ranks = {
            { level = 0, label = 'Prospect', permissions = { 'view_members' } },
            { level = 1, label = 'Member', permissions = { 'view_members', 'view_reputation' } },
            { level = 2, label = 'Road Captain', permissions = {
                'view_members', 'view_offline_members', 'view_reputation', 'view_products' } },
            { level = 3, label = 'Sergeant at Arms', permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'view_reputation', 'view_products' } },
            { level = 4, label = 'Vice President', permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
                'view_reputation', 'view_products' } },
            { level = 5, label = 'President', isBoss = true, bankAuth = true, permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
                'view_reputation', 'view_products' } },
        },
    },

    cartel = {
        label = 'Cartel',
        ranks = {
            { level = 0, label = 'Halcón', permissions = { 'view_members' } },
            { level = 1, label = 'Sicario', permissions = { 'view_members', 'view_reputation' } },
            { level = 2, label = 'Lugarteniente', permissions = {
                'view_members', 'view_offline_members', 'invite', 'view_reputation', 'view_products' } },
            { level = 3, label = 'Jefe de Plaza', permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
                'view_reputation', 'view_products' } },
            { level = 4, label = 'Patrón', isBoss = true, bankAuth = true, permissions = {
                'view_members', 'view_offline_members', 'invite', 'remove_member', 'promote', 'demote',
                'view_reputation', 'view_products' } },
        },
    },
}

-- ---------------------------------------------------------------------------
-- Gangs
-- ---------------------------------------------------------------------------
-- Cada gang aponta para um arquétipo e lista os produtos que opera. Gang que existe no
-- Qbox e não está aqui cai em `Config.FallbackArchetype` e fica sem produto, sem quebrar.
Config.FallbackArchetype = 'gueto'

Config.Gangs = {
    ballas   = { archetype = 'gueto',  products = { 'drugs' } },
    families = { archetype = 'gueto',  products = { 'drugs' } },
    vagos    = { archetype = 'gueto',  products = { 'drugs' } },
    lostmc   = { archetype = 'mc',     products = { 'weapons' } },
    cartel   = { archetype = 'cartel', products = { 'items' } },
    triads   = { archetype = 'cartel', products = { 'attachments' } },

    -- Exemplos do que ainda não existe em shared/gangs.lua do qbx_core. Criar a gang lá
    -- e descomentar aqui é tudo que falta:
    -- yakuza    = { archetype = 'cartel', products = { 'ammo' } },
    -- outro_mc  = { archetype = 'mc',     products = { 'weapons' } },
    -- Uma gang com mais de um produto já funciona hoje:
    -- ballas = { archetype = 'gueto', products = { 'drugs', 'ammo' } },
}

-- ---------------------------------------------------------------------------
-- Reputação
-- ---------------------------------------------------------------------------
-- Um inteiro por gang. Ninguém edita a própria reputação pelo menu: ela é concedida por
-- admin (`/gangrep`) ou por outro resource via export, e o menu só mostra.
Config.Reputation = { min = -100000, max = 100000, maxDelta = 10000 }
