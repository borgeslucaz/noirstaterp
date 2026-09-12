-- Dados públicos: IDs, labels, coordenadas e limites visuais.
-- Este arquivo é enviado ao client. Nenhum preço, chance ou regra anti-exploit aqui.
return {
    locale = 'pt-br',

    -- Coordenadas placeholder: capturar in-game antes de produção (ver README).
    outposts = {
        docks = {
            label = 'Terminal de Elysian',
            typePool = { 'drug', 'money' },
            computer = vector4(-43.52, -2521.06, 6.4, 314.17),
            entrance = vector3(-35.2, -2520.1, 6.0),
            doorId = nil,
            dealerCorners = {
                vector4(-42.6, -2492.3, 6.0, 140.0),
                vector4(-58.1, -2530.8, 6.0, 50.0),
                vector4(-18.4, -2540.2, 6.0, 230.0),
                vector4(-5.9, -2495.7, 6.0, 300.0),
                vector4(-70.2, -2505.9, 6.0, 95.0),
                vector4(-25.3, -2470.4, 6.0, 180.0),
            },
            dispatch = { radius = 80.0, label = 'Atividade suspeita no terminal' },
            blip = { sprite = 478, color = 6, scale = 0.8 },
        },
        cypress = {
            label = 'Galpão de Cypress Flats',
            typePool = { 'drug' },
            computer = vector4(1204.6, -3115.2, 5.5, 90.0),
            entrance = vector3(1198.2, -3121.0, 5.5),
            doorId = nil,
            dealerCorners = {
                vector4(1189.4, -3100.7, 5.5, 180.0),
                vector4(1223.9, -3128.3, 5.5, 0.0),
                vector4(1176.5, -3132.1, 5.5, 90.0),
                vector4(1215.2, -3095.8, 5.5, 270.0),
                vector4(1160.8, -3110.6, 5.5, 45.0),
                vector4(1231.7, -3150.4, 5.5, 135.0),
            },
            dispatch = { radius = 80.0, label = 'Movimentação suspeita no galpão' },
            blip = { sprite = 478, color = 6, scale = 0.8 },
        },
        lamesa = {
            label = 'Ferro-velho de La Mesa',
            typePool = { 'drug', 'money' },
            computer = vector4(880.5, -2100.7, 30.5, 175.0),
            entrance = vector3(873.9, -2093.2, 30.5),
            doorId = nil,
            dealerCorners = {
                vector4(866.2, -2118.9, 30.5, 260.0),
                vector4(895.8, -2085.3, 30.5, 80.0),
                vector4(858.4, -2078.1, 30.5, 170.0),
                vector4(902.6, -2121.5, 30.5, 350.0),
                vector4(845.9, -2102.4, 30.5, 120.0),
                vector4(910.1, -2064.8, 30.5, 200.0),
            },
            dispatch = { radius = 80.0, label = 'Movimentação suspeita no ferro-velho' },
            blip = { sprite = 478, color = 6, scale = 0.8 },
        },
    },

    -- Perfis de dealer visíveis no catálogo. Preço de contratação fica em config/server.lua.
    dealerProfiles = {
        {
            key = 'ghost',
            name = 'Ghost',
            model = 'g_m_y_mexgang_01',
            description = 'Discreto, porém exige participação maior.',
            stats = { speed = 70, capacity = 55, negotiation = 60, split = 18 },
        },
        {
            key = 'trigger',
            name = 'Trigger',
            model = 'g_m_y_ballasout_01',
            description = 'Rápido nas ruas, mas vende barato.',
            stats = { speed = 85, capacity = 40, negotiation = 35, split = 15 },
        },
        {
            key = 'smokey',
            name = 'Smokey',
            model = 'g_m_y_famdnf_01',
            description = 'Equilibrado. Bom começo para qualquer operação.',
            stats = { speed = 55, capacity = 50, negotiation = 50, split = 12 },
        },
        {
            key = 'mule',
            name = 'Mule',
            model = 'g_m_y_lost_02',
            description = 'Carrega lotes grandes e cobra pouco, mas é lento.',
            stats = { speed = 35, capacity = 80, negotiation = 40, split = 10 },
        },
        {
            key = 'silk',
            name = 'Silk',
            model = 'g_m_y_salvaboss_01',
            description = 'Negociador nato. Tira o máximo de cada cliente.',
            stats = { speed = 45, capacity = 45, negotiation = 85, split = 22 },
        },
        {
            key = 'boss',
            name = 'Boss',
            model = 'g_m_m_korboss_01',
            description = 'Veterano caro que faz tudo bem.',
            stats = { speed = 75, capacity = 70, negotiation = 75, split = 25 },
        },
    },

    -- Catálogo público (labels). Preço e quantidade real ficam server-side.
    products = {
        { id = 'weed_brick', label = 'Tijolo de maconha' },
        { id = 'meth', label = 'Metanfetamina' },
        { id = 'cokebaggy', label = 'Pacote de cocaína' },
    },

    payoutItem = 'black_money',

    limits = {
        maxDealersPerOutpost = 4,
        maxStockTotal = 400,
        maxStockPerDeposit = 100,
    },

    interaction = {
        computerDistance = 2.0,
        dealerDistance = 2.5,
    },

    -- Atendente do terminal. O computador é apenas uma zona invisível, então sem MLO ou
    -- objeto no local não haveria nada para mirar. Este NPC existe para destravar os testes.
    -- O ped nasce exatamente em `computer`, sem ajuste de altura. Como o /sfdev copia a
    -- posição do jogador, que fica ~1m acima do chão, desconte isso ao cadastrar um local.
    -- Desligue aqui quando os locais tiverem um objeto próprio, ou marque
    -- `terminalNpc = false` no outpost para desligar só naquele local.
    terminalNpc = {
        enabled = true,
        model = 's_m_m_highsec_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
    },

    phone = {
        identifier = 'exchange',
        name = 'The Exchange',
        description = 'Rede de operações clandestinas',
        -- true põe o app direto na tela inicial. false deixa ele só na App Store,
        -- e o jogador precisa instalar antes de usar.
        defaultApp = true,
        -- Fase 2: exigir item 'outposts_exchange_card'. Nil libera o ícone para todos;
        -- o gate visual nunca autoriza nada (toda callback revalida no servidor).
        requiresItem = nil,
    },
}
