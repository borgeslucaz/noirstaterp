-- Regras econômicas, chances, limites e providers. Nunca declarado em `files`.
return {
    adminAce = 'noir.outposts.admin',

    rotation = {
        activeDrugOutposts = 1,
        activeMoneyOutposts = 0,
        durationHours = 24,
        rotateDealersMinutes = 20,
        -- Ao desativar um outpost (rotação/expiração), a carteira não coletada é perdida.
        forfeitPurseOnDeactivate = true,
        expiryWarningMinutes = 30,
    },

    limits = {
        maxDealersPerOutpost = 4,
        maxStockTotal = 400,
        maxStockPerDeposit = 100,
        maxHistoryEntries = 25,
    },

    sales = {
        baseIntervalSeconds = 75,
        minimumIntervalSeconds = 30,
        requireOwnerMemberOnline = true,
        maxStartupCatchupSalesPerDealer = 1,
        priceJitter = { min = 0.95, max = 1.05 },
        dispatchChance = 10,
        dispatchCooldownSeconds = 180,
        -- Lote máximo por venda em função da capacidade do dealer (capacity / divisor).
        capacityLotDivisor = 20,
    },

    -- Valores iniciais; calibrar junto com op-drugselling. Passivo rende menos por unidade.
    products = {
        weed_brick = {
            unitPrice = 55,
            quantity = { min = 1, max = 2 },
        },
        meth = {
            unitPrice = 155,
            quantity = { min = 1, max = 3 },
        },
        cokebaggy = {
            unitPrice = 460,
            quantity = { min = 1, max = 2 },
        },
    },

    dealerHirePrice = {
        ghost = 6500,
        trigger = 4200,
        smokey = 3500,
        mule = 3000,
        silk = 7800,
        boss = 12000,
    },

    hire = {
        -- 'money' debita conta via bgrz_core; 'item' remove o item configurado.
        payment = { type = 'money', account = 'cash', item = 'black_money' },
        refundOnFire = false,
    },

    dealers = {
        -- Corredor morto sai de operação e volta depois deste tempo.
        downCooldownSeconds = 1200,
        -- Varredura que detecta ped morto e recria ped ausente.
        auditSeconds = 10,
    },

    robbery = {
        durationMs = 12500,
        cooldownSeconds = 1200,
        pursePercent = { min = 10, max = 25 },
        stockPercent = { min = 5, max = 15 },
        maxStockUnits = 10,
        dispatchChance = 75,
        interactionDistance = 2.5,
        -- Exige arma na mão no client (UX). O servidor não confia nisso e não gera loot maior.
        requireWeapon = false,
    },

    claim = {
        durationMs = 45000,
        interactionDistance = 2.0,
        -- TESTE: zerados para permitir tomada solo no servidor de desenvolvimento.
        -- Restaurar para 8 e 2 antes de abrir para os jogadores.
        minOnlinePlayers = 0,
        minPolice = 0,
        requiresOrganization = true,
        ownerDurationHours = 24,
        -- Cooldown da organização depois de assumir um outpost (evita monopólio imediato).
        organizationCooldownMinutes = 30,
        -- Cooldown curto após cancelar/falhar um claim.
        cancelCooldownSeconds = 60,
        completionGraceMs = 15000,
        completionToleranceMs = 1500,
    },

    permissions = {
        claim = 3,
        hire = 2,
        fire = 2,
        stock = 1,
        collect = 3,
        view = 0,
    },

    payout = {
        item = 'black_money',
        maxPerCollection = 250000,
    },

    police = {
        jobs = { 'police' },
    },

    dispatch = {
        code = '10-90',
        duration = 150,
        priority = 3,
        -- Blip aproximado: deslocamento aleatório em metros.
        offset = { min = 15.0, max = 35.0 },
        robberyCode = '10-31',
    },

    notifications = {
        aggregateWindowSeconds = 45,
        lowStockThreshold = 20,
        minGradeForSales = 1,
    },

    scheduler = {
        tickMs = 5000,
        expiryCheckSeconds = 60,
    },

    sessions = {
        panelTtlSeconds = 900,
        requestIdTtlSeconds = 300,
    },

    rateLimits = {
        openPanel = 1000,
        refresh = 1000,
        claim = 3000,
        hire = 2000,
        fire = 2000,
        deposit = 1500,
        collect = 3000,
        inspect = 1000,
        robbery = 3000,
        phone = 1500,
    },

    validation = {
        maxDistanceTolerance = 1.0,
    },
}
