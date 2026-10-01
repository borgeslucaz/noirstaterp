---Configuração só do servidor: limites, tetos e regras anti-exploit. Nunca vai para o
---cliente (não está em `files{}` do manifest).

return {
    -- Distâncias máximas (m) medidas no servidor. Há folga para o atraso de rede.
    distance = {
        interact = 3.0,
        vehicle = 6.0,
        station = 4.0,
        evidenceNode = 3.0,
        shotEvidence = 80.0,
        objectPlace = 6.0,
    },

    -- Intervalos mínimos (ms) entre pedidos da mesma ação, por jogador.
    rateLimit = {
        cuff = 1500,
        escort = 750,
        duty = 2000,
        garage = 3000,
        fine = 5000,
        shot = 250,
        evidenceCollect = 1000,
        evidenceDrop = 2000,
        spikes = 3000,
        object = 1000,
        lockpick = 5000,
        interdict = 10000,
        status = 5000,
        meeting = 30000,
        officerDown = 30000,
        radar = 20000,
        anklet = 3000,
        deposit = 3000,
        alert = 30000,
        default = 1000,
    },

    cuff = {
        -- Janela do minigame de fuga na algema agressiva.
        escapeWindowMs = 4500,
        -- Depois de uma fuga, o mesmo alvo não escapa de novo por este tempo.
        escapeCooldownSeconds = 120,
        -- Arrombar algema com lockpick: tempo mínimo e chance de quebrar o lockpick.
        lockpickMinMs = 8000,
        lockpickMaxMs = 30000,
        lockpickBreakChance = 35,
        -- Algema devolve o item ao tirar; zip tie é cortado e some.
        returnCuffsOnRemove = true,
    },

    fines = {
        -- Teto por multa, por departamento.
        max = { police = 25000, bcso = 25000, sasp = 25000 },
        min = 50,
        -- Prazo da multa no banco. Vencida ou não, ela trava saque e transferência até ser paga.
        dueDays = 7,
    },

    radar = {
        -- Faixas de excesso (na unidade de config.shared.radars.useMph) e multa.
        fines = {
            { over = 10, fine = 150 },
            { over = 30, fine = 400 },
            { over = 60, fine = 1000 },
            { over = 120, fine = 2500 },
        },
        -- Maior excesso aceito: acima disso a leitura é tratada como inválida.
        maxOver = 250,
        cooldownSeconds = 60,
        -- Conta que recebe a multa do radar.
        account = 'police',
    },

    fleet = {
        -- Viaturas ativas por policial ao mesmo tempo.
        maxActivePerOfficer = 1,
        -- Distância máxima entre viatura e ponto para guardar.
        storeDistance = 15.0,
    },

    objects = {
        maxPerOfficer = 12,
    },

    spikes = {
        maxSegmentLength = 20.0,
    },

    evidence = {
        -- Minutos até uma evidência no chão sumir sozinha.
        ttlMinutes = 90,
        -- Teto global de pontos de evidência no mapa.
        maxNodes = 2500,
        -- Pontos novos aceitos por relatório de tiro.
        maxNodesPerShot = 3,
        -- Raio (m) coletado de uma vez.
        collectRadius = 1.5,
        -- Bolsa de evidências: espaço para o que for coletado no turno.
        caseSlots = 40,
        caseMaxWeight = 20000,
        -- Raio (m) da limpeza de área.
        clearRadius = 10.0,
    },

    seizure = {
        -- Horas até uma pendência (item tirado e não depositado) virar alerta de desvio.
        pendingDeadlineHours = 24,
        -- Itens que contam como dinheiro para a conferência por valor.
        moneyItems = { money = true, black_money = true },
        cleanMoneyItem = 'money',
        -- Nunca voltam ao dono na devolução: só podem ser destruídos.
        neverReturn = { black_money = true },
        -- Slots e peso máximo da seized_box (container).
        boxSlots = 20,
        boxMaxWeight = 150000,
        -- Stash de evidências por departamento.
        stashSlots = 300,
        stashMaxWeight = 5000000,
    },

    anklet = {
        -- Minutos de validade de uma leitura de localização.
        pingSeconds = 60,
    },

    interdict = {
        maxActivePerOfficer = 2,
    },

    -- Recebem o "officer down" além da polícia.
    officerDownExtraJobs = { 'ambulance' },

    shotspotter = {
        enabled = true,
        delaySeconds = 2,
        cooldownSeconds = 120,
        radius = 550.0,
        ignoredWeapons = {
            `weapon_flaregun`, `weapon_stungun`, `weapon_stungun_mp`, `weapon_grenade`, `weapon_bzgas`,
            `weapon_molotov`, `weapon_stickybomb`, `weapon_proxmine`, `weapon_snowball`, `weapon_pipebomb`,
            `weapon_ball`, `weapon_smokegrenade`, `weapon_flare`, `weapon_petrolcan`,
            `weapon_fireextinguisher`, `weapon_hazardcan`, `weapon_fertilizercan`,
        },
        locations = {
            vec3(653.42, -648.74, 57.18), vec3(1015.98, -255.25, 85.58), vec3(329.99, 288.96, 120.10),
            vec3(-202.76, -327.34, 66.04), vec3(31.32, -875.29, 31.46), vec3(70.14, -1718.33, 34.21),
            vec3(1196.92, -1624.66, 50.34), vec3(-852.91, -1215.88, 9.25), vec3(-932.76, -448.88, 42.94),
            vec3(-1713.68, 478.43, 130.38), vec3(-596.56, 515.08, 109.68), vec3(716.63, -1958.74, 44.76),
            vec3(-1889.92, -351.62, 49.31), vec3(-978.85, -2089.64, 10.19), vec3(-1169.81, -2763.41, 13.95),
            vec3(-96.09, 6377.95, 31.48), vec3(1415.54, 2695.04, 37.42), vec3(-3069.58, 735.29, 21.70),
            vec3(-2729.48, 3.24, 15.51), vec3(74.06, -2644.79, 21.90), vec3(984.14, -3117.20, 5.90),
            vec3(236.19, 1240.05, 229.83), vec3(1806.03, 3705.84, 33.96), vec3(1702.34, 4881.44, 42.03),
            vec3(2868.15, 3567.91, 53.38), vec3(2566.92, 383.00, 108.46), vec3(1358.59, -942.04, 69.29),
            vec3(-1591.69, -1140.81, 2.15), vec3(-2380.90, 2136.90, 88.54), vec3(375.02, 2778.28, 55.97),
        },
    },

    -- Intervalo (ms) do envio de posições de colegas em serviço.
    blipIntervalMs = 3000,
}
