-- ============================================================
-- NOIR TRUCK V1 — CONFIGURAÇÃO DO MERCADO GLOBAL
-- Este arquivo NÃO contém coordenadas. Toda oferta aponta para o
-- catálogo canônico em shared/config.lua (Config.Missions) através
-- da chave 'missionId:routeIndex'.
-- ============================================================
Config = Config or {}

-- Idioma ativo da NUI/notificações. Fallback sempre para 'en'.
Config.Locale = 'pt-BR'

Config.ContractBoard = {
    -- Duração de uma rotação. Todo o V1 foi desenhado e testado com 60.
    rotationMinutes = 60,

    -- Distância máxima (metros) entre o motorista e a central para iniciar.
    startDistance = 35.0,

    -- Distâncias de validação server-side do fluxo físico.
    destinationDistance = 30.0,
    returnDistance      = 25.0,
    illegalBoardDistance = 80.0,
    illegalBoxIntervalMs = 1200,

    -- Fração mínima de estimatedMinutes que precisa ter decorrido antes de
    -- uma conclusão ser aceita (anti pagamento instantâneo).
    -- 0 = desligado (modo de teste). Em produção usar 0.20–0.25.
    minCompletionRatio = 0,

    -- Missões sempre disponíveis (sem requisito de nível/reputação).
    starterMissions = { [1] = true },

    global = {
        -- Quantidade por tier e rotação (total = 16). O catálogo tem
        -- 5 rotas low, 12 medium e 20 high; low repete entre horas.
        low    = { min = 4, max = 4 },
        medium = { min = 5, max = 5 },
        high   = { min = 7, max = 7 },
        capacityPerOffer = 1,
        maxStartsPerPlayerPerRotation = 1,
        reservationEnabled = false, -- decisão de produto; a NUI nunca expõe reserva

        levelBands = {
            low    = { min = 1,  max = 14 },
            medium = { min = 15, max = 34 },
            high   = { min = 35, max = nil },
        },

        -- Bônus de mercado por tier. Dinheiro nunca acima de 0.25.
        bonuses = {
            low    = { money = 0.10, xp = 0.15, reputation = 1 },
            medium = { money = 0.15, xp = 0.20, reputation = 1 },
            high   = { money = 0.25, xp = 0.25, reputation = 2 },
        },
        maxMoneyBonus = 0.25,

        -- Peso relativo de uma rota usada nas duas rotações anteriores.
        repeatWeight = 0.25,
    },

    -- Carga ilegal por tier (false bloqueia o ramo ilegal naquele tier).
    illegalAllowedTiers = { low = true, medium = true, high = true },

    -- Sal do gerador determinístico (troque para mudar a sequência de ofertas).
    seedSalt = 7919,

    -- Janela de recuperação após desconexão. Expirada → failed.
    -- Dentro da janela a sessão é encerrada como failed_system (sem penalidade);
    -- a carga nunca volta ao quadro.
    reconnectGraceSeconds = 180,
    completionIdempotency = true,
}

-- ============================================================
-- ECONOMIA
-- basePay = targetIncomePerHour × estimatedMinutes / 60 × difficultyMultiplier
-- finalPay = basePay × (1 + marketBonus) × gradeMultiplier − penalidades
-- ============================================================
Config.Economy = {
    targetIncomePerHour = 9000,
    difficultyMultiplier = {
        low    = 1.00,
        medium = 1.45,
        high   = 2.10,
    },
    -- Fração da perda de integridade convertida em penalidade financeira
    -- (percentual de dano × basePay × damagePenaltyRate).
    damagePenaltyRate = 0.25,
    -- extraPayment das rotas do catálogo continua somando ao basePay.
    includeRouteExtraPayment = true,
}

-- ============================================================
-- AVALIAÇÃO S–D
-- ============================================================
Config.Grading = {
    weights = {
        integrity   = 40,
        punctuality = 25,
        steps       = 20,
        handover    = 15,
    },
    -- Pontualidade: 100% até estimatedMinutes; cai linearmente até 0 em
    -- estimatedMinutes × lateFactor.
    lateFactor = 2.0,
    grades = {
        { grade = 'S', min = 95, money = 1.20, xp = 1.25, reputation = 2 },
        { grade = 'A', min = 85, money = 1.10, xp = 1.10, reputation = 1 },
        { grade = 'B', min = 70, money = 1.00, xp = 1.00, reputation = 0 },
        { grade = 'C', min = 50, money = 0.75, xp = 0.75, reputation = 0 },
        { grade = 'D', min = 0,  money = 0.40, xp = 0.40, reputation = 0 }, -- perda configurável (negativo)
    },
}

-- ============================================================
-- REPUTAÇÃO (vitalícia, não consumível)
-- ============================================================
Config.Reputation = {
    tiers = {
        { key = 'unknown',    min = 0  },
        { key = 'partner',    min = 5  },
        { key = 'trusted',    min = 15 },
        { key = 'specialist', min = 30 },
        { key = 'elite',      min = 60 },
    },
}

Config.Companies = {
    [0] = 'National Transfer & Storage Co.',
    [1] = 'The Grain Of Truth Company',
    [2] = 'Redwood Cigarettes Company',
    [3] = 'You Tool Company',
    [4] = 'Premium Deluxe Motorsport',
    [5] = 'Fruit Computers Company',
    [6] = 'Ron Oil Company',
    [7] = 'Merry Weather Security',
}

-- ============================================================
-- MISSÕES DIÁRIAS (progresso calculado só no servidor)
-- ============================================================
Config.DailyMissions = {
    complete_global = {
        header = 'daily_complete_global_header',
        label  = 'daily_complete_global_label',
        max = 1, xp = 1500, reputation = 1,
    },
    grade_a_or_s = {
        header = 'daily_grade_header',
        label  = 'daily_grade_label',
        max = 1, xp = 2000, reputation = 1,
    },
    two_companies = {
        header = 'daily_two_companies_header',
        label  = 'daily_two_companies_label',
        max = 2, xp = 2000, reputation = 1,
    },
    medium_no_damage = {
        header = 'daily_medium_no_damage_header',
        label  = 'daily_medium_no_damage_label',
        max = 1, xp = 2500, reputation = 1,
    },
    before_rotation_expiry = {
        header = 'daily_before_expiry_header',
        label  = 'daily_before_expiry_label',
        max = 1, xp = 1500, reputation = 0,
    },
}

-- ============================================================
-- ROUTE META — classificação das 37 rotas canônicas
-- Chave 'missionId:routeIndex'. estimatedMinutes foi derivado da
-- distância real spawn → coleta → destino → devolução (fator viário
-- 1,35 e média de 55 km/h), mais overhead de manobra.
-- ============================================================
Config.RouteMeta = {
    -- National Transfer & Storage (low)
    ['1:1']  = { tier = 'low',    estimatedMinutes = 30, baseXP = 520 },
    ['1:2']  = { tier = 'low',    estimatedMinutes = 32, baseXP = 560 },
    ['1:3']  = { tier = 'low',    estimatedMinutes = 30, baseXP = 540 },
    ['2:1']  = { tier = 'low',    estimatedMinutes = 14, baseXP = 320 },
    ['2:2']  = { tier = 'low',    estimatedMinutes = 18, baseXP = 380 },

    -- Redwood Cigarettes (medium)
    ['3:1']  = { tier = 'medium', estimatedMinutes = 32, baseXP = 820 },
    ['3:2']  = { tier = 'medium', estimatedMinutes = 33, baseXP = 840 },
    ['4:1']  = { tier = 'medium', estimatedMinutes = 28, baseXP = 780 },
    ['4:2']  = { tier = 'medium', estimatedMinutes = 30, baseXP = 800 },

    -- Grain Of Truth (medium)
    ['5:1']  = { tier = 'medium', estimatedMinutes = 28, baseXP = 760 },
    ['5:2']  = { tier = 'medium', estimatedMinutes = 34, baseXP = 860 },
    ['5:3']  = { tier = 'medium', estimatedMinutes = 29, baseXP = 780 },
    ['6:1']  = { tier = 'medium', estimatedMinutes = 28, baseXP = 760 },

    -- You Tool (medium)
    ['15:1'] = { tier = 'medium', estimatedMinutes = 24, baseXP = 700 },
    ['15:2'] = { tier = 'medium', estimatedMinutes = 25, baseXP = 720 },
    ['16:1'] = { tier = 'medium', estimatedMinutes = 29, baseXP = 800 }, -- carregamento manual de 10 caixas
    ['16:2'] = { tier = 'medium', estimatedMinutes = 30, baseXP = 820 },

    -- Premium Deluxe Motorsport (high)
    ['7:1']  = { tier = 'high',   estimatedMinutes = 11, baseXP = 620 },
    ['7:2']  = { tier = 'high',   estimatedMinutes = 13, baseXP = 660 },
    ['8:1']  = { tier = 'high',   estimatedMinutes = 16, baseXP = 760 },
    ['8:2']  = { tier = 'high',   estimatedMinutes = 21, baseXP = 860 },
    ['8:3']  = { tier = 'high',   estimatedMinutes = 23, baseXP = 900 },

    -- Fruit Computers (high)
    ['9:1']  = { tier = 'high',   estimatedMinutes = 26, baseXP = 980 },
    ['9:2']  = { tier = 'high',   estimatedMinutes = 18, baseXP = 820 },
    ['9:3']  = { tier = 'high',   estimatedMinutes = 12, baseXP = 700 },
    ['10:1'] = { tier = 'high',   estimatedMinutes = 14, baseXP = 760 },
    ['10:2'] = { tier = 'high',   estimatedMinutes = 17, baseXP = 820 },

    -- Ron Oil (high)
    ['11:1'] = { tier = 'high',   estimatedMinutes = 34, baseXP = 1200 },
    ['11:2'] = { tier = 'high',   estimatedMinutes = 34, baseXP = 1200 },
    ['12:1'] = { tier = 'high',   estimatedMinutes = 16, baseXP = 800 },
    ['12:2'] = { tier = 'high',   estimatedMinutes = 13, baseXP = 740 },
    ['12:3'] = { tier = 'high',   estimatedMinutes = 22, baseXP = 920 },

    -- Merry Weather (high)
    ['13:1'] = { tier = 'high',   estimatedMinutes = 25, baseXP = 1100 },
    ['13:2'] = { tier = 'high',   estimatedMinutes = 31, baseXP = 1250 },
    ['13:3'] = { tier = 'high',   estimatedMinutes = 24, baseXP = 1080 },
    ['14:1'] = { tier = 'high',   estimatedMinutes = 25, baseXP = 1150 },
    ['14:2'] = { tier = 'high',   estimatedMinutes = 25, baseXP = 1150 },
}

--- Chave canônica de uma rota.
--- @param missionId number
--- @param routeIndex number
--- @return string
function RouteKey(missionId, routeIndex)
    return tostring(missionId) .. ':' .. tostring(routeIndex)
end

--- Resolve missão + rota do catálogo canônico. Nunca copia coordenadas.
--- @param missionId number
--- @param routeIndex number
--- @return table|nil mission, table|nil route
function ResolveCatalogRoute(missionId, routeIndex)
    missionId  = tonumber(missionId)
    routeIndex = tonumber(routeIndex)
    if not missionId or not routeIndex then return nil, nil end

    for _, mission in ipairs(Config.Missions) do
        if mission.id == missionId then
            local route = mission.routes and mission.routes[routeIndex]
            if route then return mission, route end
            return nil, nil
        end
    end
    return nil, nil
end

--- Retorna o RouteMeta de uma rota, ou nil se não classificada.
--- @param missionId number
--- @param routeIndex number
--- @return table|nil
function GetRouteMeta(missionId, routeIndex)
    return Config.RouteMeta[RouteKey(missionId, routeIndex)]
end

--- Retorna o patamar de reputação (chave e próximo requisito).
--- @param reputation number
--- @return string tierKey, number|nil nextMin
function GetReputationTier(reputation)
    reputation = tonumber(reputation) or 0
    local current = Config.Reputation.tiers[1]
    local nextMin = nil
    for i, tier in ipairs(Config.Reputation.tiers) do
        if reputation >= tier.min then
            current = tier
            local nxt = Config.Reputation.tiers[i + 1]
            nextMin = nxt and nxt.min or nil
        end
    end
    return current.key, nextMin
end
