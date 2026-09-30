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
    ClimateStaleMs = 15000,         -- sem sincronização há mais que isto → conforto cai (conta como fora da faixa)

    -- Central (NUI) e aluguel
    Central = {
        SessionTtlMs = 120000,      -- validade do token da central
        SweepIntervalMs = 30000,    -- varredura de sessões expiradas e alugueis órfãos
        RentalAccount = 'cash',     -- conta cobrada quando rentalFee > 0
        AbandonCheckMs = 5000,      -- checagem do táxi largado (regra em Config.Abandon)
        -- Denylist opcional de atividade por emprego (desligada por padrão).
        -- Ex.: Denylist = { police = true }
        DenylistEnabled = false,
        Denylist = {},
    },

    -- Progressão de Confiança (fonte canônica: somente o servidor calcula)
    Progression = {
        -- ~13 de Confiança por corrida e ~15 corridas por hora: o nível 6 fica em ~25 dias com
        -- 2 h de jogo por dia (rampa de 4 semanas, como caminhão e ônibus).
        -- Semente do banco: depois do primeiro start, os níveis mudam em /editortaxi → Níveis.
        Levels = {
            { level = 1, min = 0,     label = 'Iniciante' },
            { level = 2, min = 150,   label = 'Motorista' },
            { level = 3, min = 600,   label = 'Profissional' },
            { level = 4, min = 2000,  label = 'Especialista' },
            { level = 5, min = 5000,  label = 'Veterano' },
            { level = 6, min = 10000, label = 'Elite' },
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

    -- Nota da corrida (1 a 5 estrelas), calculada no servidor:
    --   5 satisfeito e TRANQUILO (bônus de calma) · 4 satisfeito · 3 neutro · 2 insatisfeito
    --   1 passageiro DESESPERADO (medo travado), independentemente do resto.
    Rating = {
        Stars = { calm = 5, satisfied = 4, neutral = 3, unhappy = 2, desperate = 1 },
    },

    -- Estúdio de fotos da central (/taxifotos): carro parado no alto, parede verde e câmera de
    -- lado; o PNG cru vai para dev/fotos e o `dev/fotos.sh` recorta para html/img/vehicles.
    -- Editor in-game (/editortaxi): pontos, carros, níveis, Central e ajustes, no banco.
    Editor = {
        Command = 'editortaxi',
        AdminAce = 'noir.taxijob.admin',
        SaveIntervalMs = 400,       -- rate limit das gravações por admin
        TeleportNear = 80.0,        -- teleporte livre só perto de um ponto ou da Central
    },

    Studio = {
        Command = 'taxifotos',
        AdminAce = 'noir.taxijob.admin',
        -- Maior que a tela = captura na resolução nativa. Reduzir aqui estraga o dev/fotos.sh:
        -- no Enhanced, tela fora de múltiplo de 64 px chega com faixas e só dá pra desfazer sem escala.
        Width = 7680,
        Height = 4320,
        Scene = {
            coords = { x = -2600.0, y = -4200.0, z = 900.0 }, -- sobre o mar, longe do mapa
            heading = 0.0,
            fov = 30.0,
            margin = 1.25,        -- folga em volta do carro no enquadramento
            wallDistance = 14.0,  -- parede verde atrás do carro (m)
            wallColor = { 0, 255, 0 },
            settleMs = 1500,      -- espera texturas e peças antes da foto
            windowTint = 1,       -- película só na foto (1 = preta): vidro claro deixa o verde passar
        },
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
