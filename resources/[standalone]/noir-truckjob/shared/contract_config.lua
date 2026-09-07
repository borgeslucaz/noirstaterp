-- ============================================================
-- NOIR TRUCK V1 — CONFIGURAÇÃO DO MERCADO GLOBAL
-- Este arquivo NÃO contém coordenadas. Toda oferta aponta para o
-- catálogo canônico em shared/config.lua (Config.RouteSource) através
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
            low    = { min = 1 },
            medium = { min = 15 },
            high   = { min = 35, max = nil },
        },

        -- Bônus de mercado por tier. Dinheiro nunca acima de 0.25.
        bonuses = {
            low    = { money = 0.10, xp = 0.15 },
            medium = { money = 0.15, xp = 0.20 },
            high   = { money = 0.25, xp = 0.25 },
        },
        maxMoneyBonus = 0.25,

        -- Peso relativo de uma rota usada nas duas rotações anteriores.
        repeatWeight = 0.25,
    },

    -- Carga ilegal por tier (false bloqueia o ramo ilegal naquele tier).
    illegalAllowedTiers = { low = true, medium = true, high = true },

    -- Sal do gerador determinístico (troque para mudar a sequência de ofertas).
    seedSalt = 104729,

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
        { grade = 'S', min = 95, money = 1.20, xp = 1.25 },
        { grade = 'A', min = 85, money = 1.10, xp = 1.10 },
        { grade = 'B', min = 70, money = 1.00, xp = 1.00 },
        { grade = 'C', min = 50, money = 0.75, xp = 0.75 },
        { grade = 'D', min = 0,  money = 0.40, xp = 0.40 },
    },
}

-- ============================================================
-- DIÁRIAS (somente progresso global)
-- ============================================================
Config.DailyMissions = {
    complete_global = { header = 'daily_complete_global_header', label = 'daily_complete_global_label', max = 1, xp = 1500 },
    grade_a_or_s = { header = 'daily_grade_header', label = 'daily_grade_label', max = 1, xp = 2000 },
    medium_no_damage = { header = 'daily_medium_no_damage_header', label = 'daily_medium_no_damage_label', max = 1, xp = 2500 },
    before_rotation_expiry = { header = 'daily_before_expiry_header', label = 'daily_before_expiry_label', max = 1, xp = 1500 },
}
