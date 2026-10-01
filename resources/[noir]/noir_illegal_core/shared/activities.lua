-- Examples stay disabled until the owning gameplay resource is installed,
-- configured in permissions.lua, and explicitly enabled here.
--
-- Reputação da gang
-- -----------------
-- O nível da gang é a reputação `drug` da organização. Ela sobe com o que a gang já faz no mapa
-- e desce quando apanha. Nenhum resource de gameplay escolhe esses números: eles avisam o fato
-- (venda, tomada, roubo, troca de dono de bairro) e os adaptadores em `server/adapters/`
-- registram aqui. É a mesma fronteira do `Config.Influence.Rates` do noir_territories.
--
-- A meta de ritmo é uma gang ativa (3–4 membros, algumas horas por dia) fazendo ~50 por dia:
-- o contato da meth (nível 2, 300) em torno de uma semana e o da coca (nível 4, 1500) em torno
-- de um mês. Os valores abaixo saem dessa conta de trás para frente e são ponto de partida —
-- calibrar pelo ledger (`noir_illegal_activity_ledger`) depois de uma semana de jogo real.
--
--   venda de rua        0.5 por venda, com retorno decrescente por jogador   ~30/dia
--   venda do outpost    0.1 por venda passiva, decrescente por gang          ~15–25/dia
--   bairro dominado     5 por bairro por dia                                 ~10/dia
--   tomar outpost       25 de uma vez
--   perder bairro      -15
--   outpost roubado     -5
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
        personal = { drug = 2, street = 1 },
        organization = { drug = 0.5 },
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
        organization = { street = 5, drug = 25 },
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
        -- decrescente corta isso para ~70 vendas cheias por hora, e o 0.1 transforma em ~7 de
        -- reputação: rende, mas menos que gente vendendo na rua.
        organization = { drug = 0.1 },
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
        organization = { drug = -5 },
        metadata = { allow = { 'outpostId', 'dealerId' } },
    },
    territory_held = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        organization = { drug = 5 },
        metadata = { allow = { 'zone', 'period' } },
    },
    territory_lost = {
        enabled = true,
        subject = 'organization',
        callers = { 'noir_illegal_core' },
        idempotencyTtlSeconds = 2592000,
        organization = { drug = -15 },
        metadata = { allow = { 'zone', 'newOwner' } },
    },
    -- Rota de coleta concluída (noir_gathering). O quanto vale e em que categoria é da rota,
    -- configurada pelo admin em jogo; aqui fica só o teto por entrega. O retorno decrescente
    -- por jogador segura quem tenta repetir a rota mais curta sem parar.
    gathering_delivery = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
        variable = { organization = 100 },
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
    -- Atividades que só somam heat ao personagem: reputação desses crimes fica para a revisão de
    -- marcos. O heat vai de 0 a 100 e decai 9 por hora jogada (Config.Heat), então o número
    -- abaixo é quanto tempo online o crime "esquenta" quem fez: 9 ≈ uma hora. Sem retorno
    -- decrescente: quem repete é visto todas as vezes.
    -- Roubo de casa concluído (noir_houserobbery). Conta para cada participante.
    house_robbery = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = {},
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
        personal = {},
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
        personal = {},
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
