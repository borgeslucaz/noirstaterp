-- noir_taxijob · configuração somente do servidor
ServerConfig = {
    -- Webhook opcional para registrar tentativas suspeitas (vazio = desligado)
    Webhook = '',

    -- Limites de chamadas por jogador (ms)
    RateLimits = {
        setAvailable = 1000,
        accept = 500,
        requestPassenger = 1000,
        boarded = 1000,
        complete = 1500,
        climate = 900,
        openCentral = 1000,
        retryBootstrap = 2000,
        ranking = 5000,
        rent = 3000,
        returnVehicle = 2000,
        scare = 2000,
        vehicleBroken = 2000,
    },

    -- Tolerâncias das validações de posição
    PickupSpawnTolerance = 60.0,    -- além de Passenger.SpawnDistance
    DropoffTolerance = 10.0,        -- além de Passenger.DropoffDistance
    ClimateMaxDeltaPerSecond = 0.6, -- variação máxima plausível de temperatura enviada pelo client
    ClimateStaleMs = 15000,         -- sem sincronização há mais que isto → conforto não muda

    -- Central (NUI) e aluguel
    Central = {
        SessionTtlMs = 120000,      -- validade do token da central
        SweepIntervalMs = 30000,    -- varredura de sessões expiradas e alugueis órfãos
        RentalAccount = 'cash',     -- conta cobrada quando rentalFee > 0
        -- Denylist opcional de atividade por emprego (desligada por padrão).
        -- Ex.: Denylist = { police = true }
        DenylistEnabled = false,
        Denylist = {},
    },

    -- Progressão de Confiança (fonte canônica: somente o servidor calcula)
    Progression = {
        Levels = {
            { level = 1, min = 0,    label = 'Iniciante' },
            { level = 2, min = 100,  label = 'Motorista' },
            { level = 3, min = 250,  label = 'Profissional' },
            { level = 4, min = 500,  label = 'Especialista' },
            { level = 5, min = 850,  label = 'Veterano' },
            { level = 6, min = 1300, label = 'Elite' },
        },
        MaxConfidence = 2000000000, -- limite técnico (evita overflow)

        -- Ganho por corrida validada
        BasePerFare = 10,
        SatisfiedBonus = 5,
        NeutralBonus = 2,
        UnhappyBonus = 0,

        -- Corrida válida com pagamento final zero ainda conta como concluída (decisão 8 do TAXI_V2).
        CountZeroFare = true,

        -- Dia canônico (chave `YYYY-MM-DD`) derivado de epoch + offset + hora de corte, sem timer de meia-noite.
        DayUtcOffsetMinutes = -180,
        DayResetHour = 0,

        -- Política quando a persistência falhar na conclusão: pagar a corrida mesmo assim e avisar o jogador.
        -- A Confiança nunca é concedida sem registro no ledger.
        PayWhenPersistFails = true,
    },

    Ranking = {
        CacheTtlMs = 60000,
        TopSize = 10,
        MinCompletedRides = 1,      -- perfis com menos corridas ficam fora da lista geral
    },

    -- Migração controlada das tabelas legadas (somente na primeira criação do perfil V2)
    Migration = {
        Enabled = true,
        Sources = { 'ak4y_taxi', 'noir_taxijob' }, -- ordem de prioridade
        XpConversionFactor = 0.2,   -- Confiança = XP legado × fator (aprovar no balanceamento)
        MaxLegacyRoutes = 100000,
        MaxLegacyXp = 100000000,
    },
}
