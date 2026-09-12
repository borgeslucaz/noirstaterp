-- Regras econômicas, chances, limites e providers. Nunca declarado em `files`.
return {
    adminAce = 'noir.outposts.admin',

    rotation = {
        -- TESTE: fixa a rotação nestes postos, ignorando o sorteio e a rotação já persistida
        -- do ciclo. Todo posto fora desta lista é desativado. Esvazie antes de abrir para os
        -- jogadores, senão a rotação nunca mais sai do lugar.
        forced = { pier = 'drug' }, --TODO: NÃO SUBIR PRA PRODUÇÃO ASSIM

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
        feedPageSize = 20,
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
        -- Morte limpa, sem assalto antes. Curta de propósito: matar o corredor não é a forma
        -- de tirar um posto de operação. Quem só atira devolve um corredor em um minuto, então
        -- a sabotagem por tiro não compensa e o roubo continua sendo o caminho.
        downCooldownSeconds = 60,
        -- Morte depois de um assalto. Aqui o corredor já tinha sido rendido e revistado, e a
        -- execução fecha o episódio: substitui o que restava do roubo pelo prazo cheio. Precisa
        -- ser maior que `robbery.cooldownSeconds`, senão executar o rendido o devolveria mais
        -- cedo do que deixá-lo vivo.
        downAfterRobberyCooldownSeconds = 1200,
        -- Chance de a morte de um corredor virar chamado para a polícia. Alta de propósito:
        -- executar gente na rua é mais visível que vender na esquina, e sem chamado nenhum três
        -- rivais limpam os quatro corredores e vão embora em silêncio. O cooldown de dispatch é
        -- por posto, então uma chacina inteira gera uma ocorrência, não quatro.
        dispatchChance = 75,
        -- Varredura que detecta ped morto e recria ped ausente.
        auditSeconds = 10,
    },

    -- Proteção da gang dona offline.
    -- Sem ninguém da organização dona online o corredor deixa de ser alvo: nem abordagem, nem
    -- assalto. Isso é o outro lado do `sales.requireOwnerMemberOnline`: se a venda passiva já
    -- para quando a gang está offline, deixar o roubo aberto faz da madrugada ganho de graça
    -- para o rival e perda pura para quem não tem ninguém para reagir. Com isto ligado o posto
    -- fica congelado no período: não rende e não perde.
    --
    -- Matar o corredor continua possível, porque ele é um ped como qualquer outro. Mas isso não
    -- tira nada da organização: ele volta sozinho pelo cooldown de morte, sem carteira nem
    -- estoque a menos.
    ownerOffline = {
        protectDealers = true,
    },

    -- Abordagem à mão armada, antes do assalto em si.
    holdup = {
        -- Chance de o corredor reagir em vez de se render. A rolagem é server-side.
        reactionChance = 60,
        -- Quanto tempo ele fica de mãos para o alto, janela para revistar.
        surrenderSeconds = 30,
        -- Quanto tempo ele fica hostil depois de reagir.
        hostileSeconds = 60,
        -- Impede ficar mirando de novo até tirar a rendição na sorte.
        cooldownSeconds = 120,
        -- Distância máxima entre quem mira e o corredor.
        maxDistance = 12.0,
    },

    robbery = {
        durationMs = 12500,
        -- Depois de assaltado o corredor sai de operação por este tempo, e nesse período
        -- também não pode ser assaltado de novo. As duas coisas são a mesma janela.
        cooldownSeconds = 600,
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
        minOnlinePlayers = 0, --TODO: NÃO SUBIR PRA PRODUÇÃO ASSIM
        minPolice = 0, --TODO: NÃO SUBIR PRA PRODUÇÃO ASSIM
        requiresOrganization = true,
        ownerDurationHours = 12,
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
        downCode = '10-71',
    },

    -- Categorias de alerta que o jogador pode desligar no telefone.
    -- Vale só para o alerta empurrado: o feed dentro do app mostra tudo sempre.
    alerts = {
        categories = { 'sales', 'stock', 'security', 'control' },
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

    operationRetention = {
        days = 15,
        intervalSeconds = 12 * 60 * 60,
        batchSize = 1000,
        maxBatchesPerRun = 10,
    },

    sessions = {
        panelTtlSeconds = 900,
        requestIdTtlSeconds = 300,
    },

    rateLimits = {
        openPanel = 1000,
        holdup = 1500,
        refresh = 1000,
        claim = 3000,
        hire = 2000,
        fire = 2000,
        deposit = 1500,
        collect = 3000,
        inspect = 1000,
        robbery = 3000,
        phone = 1500,
        feed = 700,
        settings = 1000,
        debug = 1000,
        position = 400,
    },

    validation = {
        maxDistanceTolerance = 1.0,
        -- A partir de quantos metros uma leitura fora da esquina de spawn conta como prova de
        -- que o servidor recebe a posição do ped. Abaixo disso pode ser só ruído de sincronia.
        positionSyncEpsilon = 0.75,

        -- Posição reportada pelo dono de rede do ped.
        -- Por quanto tempo um reporte continua valendo antes de o servidor voltar a se virar
        -- com a leitura própria. Curto de propósito: dono que saiu não deixa rastro velho.
        reportedPositionTtlSeconds = 6,
        -- O reporte não é limitado pela esquina, e sim pela continuidade: um corredor assustado
        -- pode ir parar longe, e prendê-lo ao raio de caminhada tornaria o assalto impossível
        -- justamente quando ele fugiu. O que se recusa é o salto impossível.
        reportedPositionMaxSpeed = 12.0,
        -- Teto do orçamento acumulado entre dois reportes. Sem dono o ped fica parado, então
        -- um intervalo longo não deve virar licença para teleporte.
        reportedPositionMaxGapSeconds = 10,
        -- Folga fixa por reporte, para ruído de sincronia e passo de contorno.
        reportedPositionSlack = 2.0,
    },
}
