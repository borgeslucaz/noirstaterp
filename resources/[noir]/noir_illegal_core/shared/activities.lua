-- Examples stay disabled until the owning gameplay resource is installed,
-- configured in permissions.lua, and explicitly enabled here.
--
-- Reputação da gang
-- -----------------
-- A gang tem UMA reputação (`gang`), qualquer que seja o produto, e ela só sobe com o que só gang
-- faz: bairro e outpost (gangs de rua) e as rotas do noir_gathering. Crime que qualquer pessoa
-- faz (venda de rua, roubo) rende reputação pessoal, nunca da gang. Nenhum resource de gameplay
-- escolhe esses números: eles avisam o fato e os adaptadores em `server/adapters/` registram.
--
-- Ritmo: teto de 50 por dia por gang (Config.Organization), contato da meth em 500 (nível 2).
-- Uma gang ativa típica faz ~35–40 por dia:
--
--   tomar bairro        +25, uma vez por bairro e gang por dia
--   segurar bairro      +8 por bairro por dia, só com atividade da gang no bairro em 24h
--   perder bairro       -15 (troca feita por admin não cobra)
--   tomar outpost       +30, nada se o posto foi da mesma gang nos últimos 7 dias
--   venda do outpost    +0.1 por venda passiva, até 12 por dia
--   outpost roubado     -5
--   rota de carga       até 20 por entrega, até 12 por dia
--
-- `subject = 'organization'` marca atividade sem autor: o fato é da gang e não de um jogador
-- online (venda passiva, bairro segurado, perda). Ela só mexe na reputação da organização, pode
-- ter delta negativo — preso em zero —, e não aceita heat, cooldown nem requisito, porque todos
-- eles são de uma pessoa.
NoirIllegal.Activities = {
    drug_sale = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        -- Reputação pessoal multiplicada pelo grau e pelo peso da droga (adaptador do
        -- drugselling, `Config.SaleWeight`). Venda de rua não rende reputação de gang.
        personal = { drug = 2, street = 1 },
        -- 1.3 por venda contra o decaimento de 9 por hora jogada: 6 vendas por hora ainda
        -- esfriam, 7 empatam (9.1), 13 esquentam ~8 por hora (16.9 − 9) e 20, ~17.
        heat = 1.3,
        diminishingReturns = {
            windowSeconds = 3600,
            softCap = 20,
            floorMultiplier = 0.20,
            curve = 'linear',
            key = 'player:activity',
        },
        requirements = {},
        metadata = { allow = { 'zoneId', 'saleType', 'targetId', 'drug', 'amount' } },
    },
    outpost_claim = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = { street = 2 },
        organization = { gang = 30 },
        heat = 2.0,
        requirements = { organization = true },
        metadata = { allow = { 'outpostId', 'previousOwnerId' } },
    },
    outpost_sale = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        -- Um posto com quatro corredores fecha perto de 190 vendas por hora. O retorno
        -- decrescente corta isso para ~70 vendas cheias por hora (~7 de reputação), e o teto
        -- diário segura o posto em 12 por dia: rende, mas não carrega a gang sozinho.
        organization = { gang = 0.1 },
        dailyCap = 12,
        diminishingReturns = {
            windowSeconds = 3600,
            softCap = 30,
            floorMultiplier = 0.20,
            curve = 'linear',
            key = 'organization:activity',
        },
        metadata = { allow = { 'outpostId', 'dealerId', 'product', 'quantity' } },
    },
    outpost_robbery = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 900,
        idempotencyTtlSeconds = 2592000,
        personal = { street = 2 },
        organization = {},
        heat = 4.0,
        requirements = {},
        metadata = { allow = { 'outpostId', 'dealerId', 'lootValue' } },
    },
    outpost_robbed = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        organization = { gang = -5 },
        metadata = { allow = { 'outpostId', 'dealerId' } },
    },
    territory_held = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        organization = { gang = 8 },
        metadata = { allow = { 'zone', 'period' } },
    },
    -- Bairro tomado: o marco. Uma vez por bairro e gang por dia (o id da transação sai de
    -- bairro + gang + dia), para tomar, perder e retomar o mesmo bairro não render de novo.
    territory_taken = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        organization = { gang = 25 },
        metadata = { allow = { 'zone', 'previousOwner' } },
    },
    territory_lost = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        organization = { gang = -15 },
        metadata = { allow = { 'zone', 'newOwner' } },
    },
    -- Rota de coleta concluída (noir_gathering). O quanto vale é da rota, configurada pelo admin
    -- em jogo, e vai sempre para `gang` (a categoria da rota é ignorada na reputação); aqui
    -- fica o teto por entrega e o teto do dia da gang. O retorno decrescente por jogador segura
    -- quem tenta repetir a rota mais curta sem parar.
    gathering_delivery = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        variable = { organization = 20 },
        dailyCap = 12,
        heat = 0,
        diminishingReturns = {
            windowSeconds = 3600,
            softCap = 6,
            floorMultiplier = 0.25,
            curve = 'linear',
            key = 'player:activity',
        },
        requirements = { organization = true },
        metadata = { allow = { 'routeId', 'route' } },
    },

    -- Heat de crime
    -- -------------
    -- Crimes que qualquer pessoa faz: somam heat e, alguns, reputação pessoal de rua (roubo de
    -- casa +3, smash & grab +0.5, parquímetro +0.25). Nunca reputação de gang. Arma da bancada
    -- fica sem reputação: armas serão de outro tipo de grupo. O heat vai de 0 a 100 e decai 9 por hora jogada (Config.Heat), então o número
    -- abaixo é quanto tempo online o crime "esquenta" quem fez: 9 ≈ uma hora. Sem retorno
    -- decrescente: quem repete é visto todas as vezes.
    -- Roubo de casa concluído (noir_houserobbery). Conta para cada participante.
    house_robbery = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = { street = 3 },
        heat = 8.0,
        requirements = {},
        metadata = { allow = { 'contractId', 'houseId', 'tier' } },
    },
    -- Vidro quebrado e mochila levada (noir_prettycrimes).
    petty_smashgrab = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = { street = 0.5 },
        heat = 2.0,
        requirements = {},
        metadata = { allow = { 'prop', 'rewards' } },
    },
    -- Parquímetro esvaziado (noir_prettycrimes).
    petty_parkingmeter = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = { street = 0.25 },
        heat = 1.0,
        requirements = {},
        metadata = { allow = { 'meter', 'rewards' } },
    },
    -- Caixa de loja roubado (qbx_storerobbery).
    store_register = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 4.0,
        requirements = {},
        metadata = { allow = { 'register' } },
    },
    -- Cofre de loja aberto (qbx_storerobbery).
    store_safe = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 6.0,
        requirements = {},
        metadata = { allow = { 'safe' } },
    },
    -- Vitrine da joalheria quebrada (qbx_jewelery). Um roubo inteiro são várias.
    jewelery_vitrine = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 2.0,
        requirements = {},
        metadata = { allow = { 'vitrine' } },
    },
    -- Fleeca aberto (qbx_bankrobbery).
    bank_fleeca = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 12.0,
        requirements = {},
        metadata = { allow = { 'bankId' } },
    },
    -- Banco de Paleto aberto (qbx_bankrobbery).
    bank_paleto = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 16.0,
        requirements = {},
        metadata = { allow = { 'bankId' } },
    },
    -- Pacific Standard aberto (qbx_bankrobbery).
    bank_pacific = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 20.0,
        requirements = {},
        metadata = { allow = { 'bankId' } },
    },
    -- Carro-forte saqueado (qbx_truckrobbery).
    truck_robbery = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 12.0,
        requirements = {},
        metadata = { allow = {} },
    },
    -- Ligação direta ou lockpick de porta trancada (mri_Qcarkeys).
    vehicle_break_in = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 2.0,
        requirements = {},
        metadata = { allow = { 'kind', 'plate' } },
    },
    -- Arma ou peça pronta retirada da bancada (noir_guncraft).
    gun_craft = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        heat = 3.0,
        requirements = {},
        metadata = { allow = { 'queueId', 'item' } },
    },
}
