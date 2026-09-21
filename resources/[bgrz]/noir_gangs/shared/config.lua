Config = {}
Config.AdminAce = 'noir.gangsetup'
Config.Invitation = { maxDistance = 3.0, duration = 30, cooldown = 10 }
Config.ManagementDistance = 2.0
-- Cargo de entrada quando a gang não tem cargo nenhum. No caso normal a porta é o menor
-- cargo que a gang TEM, porque o editor pode apagar o mais baixo; isto é só o fallback.
Config.DefaultGrade = 0
Config.DefaultZoneSize = vec3(1.5, 1.5, 1.5)
Config.ActivityLimit = 50
Config.LocationRequestCooldown = 3

-- Quantas linhas de histórico cada gang guarda. A tabela só cresce — cada ação de cada
-- gang deixa uma linha — e a tela lê as `ActivityLimit` mais novas, então o que passa
-- disso é rastro de auditoria, não tela. A poda é por contagem e por gang, e não por
-- data, porque é assim que ela usa o mesmo índice da leitura (`gang_name`, `id`).
-- Zero desliga a poda e guarda tudo.
Config.ActivityRetention = 500
-- De quantas em quantas horas a poda passa. Ela também roda no start do resource.
Config.ActivityPruneInterval = 6

-- De quantos em quantos segundos o console repete que o bootstrap falhou. O alarme só
-- existe nesse estado, e ele repete porque a linha do start some do console em minutos.
Config.BootstrapAlertInterval = 60

-- Validade da matéria-prima do snapshot (roster, nomes e histórico), em segundos. Ela é
-- descartada antes disso a cada mutação da gang, então o valor só decide de quanto em
-- quanto tempo um pedido repetido volta a tocar o banco. Zero desliga o cache.
Config.SnapshotCacheTTL = 3

---Quem manda nos CARGOS: o config ou o banco.
---
---`false` (padrão): o arquétipo é **semente**. Uma gang sem nenhum cargo recebe os do
---arquétipo no start; uma gang que já tem cargos nunca mais é tocada, porque a partir do
---primeiro start ela é editada em jogo (permissão `manage_ranks`). É o modo que faz o
---editor existir: com `true`, toda edição some no restart seguinte.
---
---`true`: o config reescreve `noir_gang_ranks` a cada start, como antes do editor. Serve
---para servidor que prefere versionar a hierarquia no arquivo, e para desfazer uma
---bagunça — sobe uma vez com `true`, volta para `false`.
---
---Produtos não dependem desta chave: eles não têm editor, então continuam saindo do
---config a cada start. Reputação nunca é tocada por nenhum dos dois modos.
Config.RanksFromConfig = false

---Mesmo acordo dos cargos, agora que produtos têm editor no `/gangsetup`.
---
---`false` (padrão): o config é **semente**. Gang que nunca foi semeada recebe a lista de
---`Config.Gangs`; depois disso quem manda é o que foi editado em jogo — inclusive a
---escolha de não ter produto nenhum.
---
---`true`: o config reescreve `noir_gang_products` a cada start, como antes do editor.
Config.ProductsFromConfig = false

-- Tetos do editor de cargos. O máximo existe porque cada cargo vira também um grade no
-- Qbox, publicado por nós e nunca removido de lá: sem teto, um clique repetido enche a
-- tabela de grades do provider para sempre.
Config.Ranks = { max = 10, labelMaxLength = 32 }

-- Limites do registro de gangs. O nome é o identificador que vai para o Qbox e para o
-- `player_groups`, então ele é minúsculo, sem espaço e imutável depois de criado: renomear
-- deixaria para trás toda linha de personagem que aponta para o nome antigo.
Config.Gang = { nameMaxLength = 24, labelMaxLength = 40, max = 32 }

-- ---------------------------------------------------------------------------
-- Cores
-- ---------------------------------------------------------------------------
-- A cor é identidade da gang, escolhida no `/gangsetup` e guardada com ela. Antes vivia
-- numa lista fixa dentro do `noir_territories`, que é quem desenha o mapa — mas quem manda
-- na identidade é a gang, não o mapa. Ele agora pergunta por `GetGangColor`.
--
-- A paleta é fechada de propósito: cor livre em campo de texto vira gang preta no fundo
-- preto, e duas gangs com o mesmo tom de roxo no mapa.
Config.Colors = {
    vermelho = { label = 'Vermelho', r = 224, g = 50,  b = 50  },
    verde    = { label = 'Verde',    r = 114, g = 204, b = 114 },
    azul     = { label = 'Azul',     r = 93,  g = 182, b = 229 },
    amarelo  = { label = 'Amarelo',  r = 240, g = 200, b = 80  },
    laranja  = { label = 'Laranja',  r = 255, g = 133, b = 85  },
    roxo     = { label = 'Roxo',     r = 190, g = 120, b = 255 },
    rosa     = { label = 'Rosa',     r = 255, g = 102, b = 178 },
    cinza    = { label = 'Cinza',    r = 155, g = 155, b = 155 },
}

Config.FallbackColor = 'cinza'

-- Além da paleta, o `/gangsetup` aceita cor livre — guardada como `#RRGGBB`.
--
-- Livre, mas não qualquer uma: a tela e o mapa são quase pretos, e uma gang em `#101014`
-- fica invisível exatamente onde ela mais precisa ser vista. O piso é o contraste mínimo
-- que o guia pede para objeto gráfico (3:1), medido contra a superfície mais escura em que
-- a cor aparece — o fundo do mapa de território.
--
-- É a mesma conta do WCAG, então a régua é objetiva e não gosto pessoal: todas as cores da
-- paleta acima passam com folga, e o que ela barra é preto sobre preto.
Config.CustomColor = { minContrast = 3.0, against = { r = 11, g = 11, b = 13 } }

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
    'manage_ranks',        -- criar, renomear e definir o que cada cargo pode
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
                'view_reputation', 'view_products', 'manage_ranks' } },
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
                'view_reputation', 'view_products', 'manage_ranks' } },
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
                'view_reputation', 'view_products', 'manage_ranks' } },
        },
    },
}

-- ---------------------------------------------------------------------------
-- Gangs
-- ---------------------------------------------------------------------------
-- **Quem existe mora no banco**, em `noir_gang_state`, e é de lá que as gangs são
-- registradas no Qbox a cada start. O `shared/gangs.lua` do provider virou só o dicionário
-- que ele monta a partir daqui.
--
-- Esta lista é a **semente**: gang que não estiver no banco é criada a partir dela no
-- start, e depois nunca mais é tocada — quem manda passa a ser o `/gangsetup`. É o mesmo
-- acordo dos cargos, e pelo mesmo motivo: sem ele, toda gang criada em jogo sumiria no
-- restart seguinte.
Config.FallbackArchetype = 'gueto'

Config.Gangs = {
    ballas   = { label = 'Ballas',      color = 'roxo',     archetype = 'gueto',  products = { 'drugs' } },
    families = { label = 'Families',    color = 'verde',    archetype = 'gueto',  products = { 'drugs' } },
    vagos    = { label = 'Vagos',       color = 'amarelo',  archetype = 'gueto',  products = { 'drugs' } },
    lostmc   = { label = 'The Lost MC', color = 'cinza',    archetype = 'mc',     products = { 'weapons' } },
    cartel   = { label = 'Cartel',      color = 'laranja',  archetype = 'cartel', products = { 'items' } },
    triads   = { label = 'Triads',      color = 'vermelho', archetype = 'cartel', products = { 'attachments' } },
}

-- ---------------------------------------------------------------------------
-- Reputação
-- ---------------------------------------------------------------------------
-- Um inteiro por gang. Ninguém edita a própria reputação pelo menu: ela é concedida por
-- admin (`/gangrep`) ou por outro resource via export, e o menu só mostra.
Config.Reputation = { min = -100000, max = 100000, maxDelta = 10000 }
