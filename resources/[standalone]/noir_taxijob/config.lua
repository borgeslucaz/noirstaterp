-- ak4y-taxi · configuração compartilhada (client + server)
Config = {}

Config.Debug = false
Config.Locale = 'pt-br'

-- Emprego e serviço
Config.Job = 'taxi'
Config.RequireDuty = true

-- Modelos que ativam o taxímetro quando o taxista senta no banco do motorista
Config.AllowedVehicles = {
    'taxi',
    -- 'tailgater',
    -- 'stretch',
}

-- Teclas padrão (o jogador pode trocar em Configurações > Teclas do FiveM)
Config.Keybinds = {
    fan    = { key = 'G', label = 'Táxi: alterar FAN' },
    accept = { key = 'E', label = 'Táxi: aceitar chamada' },
    pause  = { key = 'J', label = 'Táxi: pausar/retomar chamadas' },
}

-- Central (dispatcher) de chamadas NPC
Config.Dispatch = {
    OfferTimeout = 10000,        -- ms para aceitar a chamada
    MinDelay = 10000,            -- intervalo mínimo entre chamadas
    MaxDelay = 30000,            -- intervalo máximo entre chamadas
    CooldownAfterFare = 8000,    -- espera após concluir uma corrida
    CooldownAfterTimeout = 6000, -- espera após ignorar uma chamada

    MinPickupDistance = 300.0,
    IdealPickupDistance = 1800.0,
    MaxPickupDistance = 3000.0,
    NearPickupWeight = 0.85,     -- chance de escolher um ponto dentro da distância ideal

    MinTripDistance = 400.0,     -- distância mínima entre coleta e destino
    MaxTripDistance = 4000.0,    -- evita Downtown → Paleto como corrida normal
    RouteFactor = 1.35,          -- linha reta × fator ≈ distância real pelas ruas
}

-- Passageiro NPC
Config.Passenger = {
    SpawnDistance = 180.0,       -- cria o ped quando o taxista chega a esta distância
    BoardingDistance = 8.0,
    MaxBoardingSpeed = 5.0,      -- km/h
    BoardingTimeout = 10000,     -- ms por tentativa de embarque
    BoardingAttempts = 2,        -- tentativas com TaskEnterVehicle antes do warp
    SeatOrder = { 2, 1, 0 },     -- traseiro direito, traseiro esquerdo, passageiro dianteiro

    DropoffDistance = 12.0,
    MaxDropoffSpeed = 3.0,       -- km/h
    ArrivalHoldMs = 1500,        -- tempo parado no destino antes de finalizar
    DropoffHoldMs = 4000,        -- táxi travado enquanto o passageiro desce
    DespawnDelay = 15000,        -- ms até o servidor remover o ped após a corrida

    DriverAwayGraceMs = 60000,   -- tempo fora do táxi antes de cancelar a corrida
    Scenario = 'WORLD_HUMAN_STAND_IMPATIENT',

    Models = {
        'a_f_m_beach_01', 'a_f_m_fatbla_01', 'a_f_m_prolhost_01', 'a_f_o_soucent_01',
        'a_f_y_juggalo_01', 'a_m_m_afriamer_01', 'a_m_m_og_boss_01', 'a_m_m_prolhost_01',
        'a_m_m_trampbeac_01', 'a_m_y_beach_03', 'a_m_y_business_02',
    },
}

-- Taxímetro (server-authoritative)
Config.Meter = {
    StartingFare = 15,           -- bandeirada
    PricePerKm = 12,
    UpdateInterval = 1000,       -- ms

    MaxRouteMultiplier = 1.8,    -- limite tarifável = esperado × multiplicador + tolerância
    ExtraDistanceTolerance = 500.0,
    AbsoluteMaxBillable = 12000.0,
    MaxValidDeltaPerTick = 150.0,-- trecho maior que isto em 1 s é ignorado (teleporte)
    MaxIgnoredJumps = 5,         -- corrida cancelada após este número de trechos impossíveis

    MinTripMeters = 100.0,
    MinTripSeconds = 10,
    MaxFare = 600,
}

-- Ar-condicionado / conforto do passageiro
Config.Climate = {
    ComfortMin = 21.0,
    ComfortMax = 24.0,
    MinTemp = 8.0,
    MaxTemp = 36.0,
    MaxFan = 5,

    -- Modo automático: com calor lá fora a FAN sopra frio (ACTarget), com frio sopra quente (HeaterTarget).
    ACTarget = 18.0,
    HeaterTarget = 26.0,
    ModeSwitchTemp = 22.5,       -- acima disto o sistema resfria, abaixo aquece
    DriftRate = 0.010,           -- aproximação à temperatura externa por segundo (FAN desligada)
    FanRate = 0.008,             -- aproximação ao alvo por segundo, por nível de FAN
    SyncInterval = 4000,         -- ms entre envios de temperatura ao servidor

    ComfortGain = 0.5,           -- por segundo dentro da faixa
    ComfortLoss = 1.0,           -- por segundo fora da faixa
    SatisfiedThreshold = 80,
    UnhappyThreshold = 50,

    WeatherTemps = {
        EXTRASUNNY = 30, CLEAR = 28, NEUTRAL = 25, SMOG = 25, FOGGY = 17,
        OVERCAST = 18, CLOUDY = 22, CLEARING = 20, RAIN = 15, THUNDER = 14,
        BLIZZARD = 5, SNOW = 0, SNOWLIGHT = 3, XMAS = 0, HALLOWEEN = 16,
    },
    DefaultOutsideTemp = 22,
}

-- Pagamento (multiplicadores por satisfação, aplicados no servidor)
Config.Payout = {
    SatisfiedTipPercent = 10,    -- gorjeta quando satisfação ≥ SatisfiedThreshold
    NeutralMultiplier = 0.85,    -- satisfação entre Unhappy e Satisfied
    UnhappyMultiplier = 0.70,    -- satisfação ≤ UnhappyThreshold
}

-- Reputação (PlayerData.metadata.jobrep.taxi)
Config.Reputation = {
    BasePerFare = 5,
    SatisfiedBonus = 2,
    UnhappyPenalty = 2,
}

-- Central de táxi (ped, blip e vagas do veículo)
Config.Depot = {
    coords = vec4(894.9, -179.17, 74.7, 242.89),
    pedModel = 'a_m_m_eastsa_02',
    vehicleModel = 'taxi',
    interactDistance = 15.0,
    returnRadius = 30.0,
    blip = { sprite = 198, color = 46, scale = 0.7, label = 'Central de Táxi' },
    spawnPoints = {
        vec4(906.53, -185.91, 74.01, 60.35),
        vec4(908.81, -183.34, 74.21, 61.0),
        vec4(921.74, -163.52, 74.86, 96.21),
        vec4(913.71, -159.83, 74.76, 201.9),
    },
}

-- Pontos de coleta/destino (mantidos do resource original)
Config.Points = {
    ['downtown'] = {
        vec4(413.85, 133.6, 101.43, 205.55),
        vec4(116.34, -11.63, 67.7, 201.15),
        vec4(-15.48, -114.36, 56.86, 178.45),
        vec4(112.34, -939.13, 29.72, 254.85),
        vec4(196.74, -1087.24, 29.29, 279.85),
        vec4(-325.23, 264.51, 86.59, 202.99),
        vec4(257.61, -380.57, 44.71, 340.5),
        vec4(-48.58, -790.12, 44.22, 340.5),
        vec4(240.06, -862.77, 29.73, 341.5),
        vec4(826.0, -1885.26, 29.32, 81.5),
        vec4(350.84, -1974.13, 24.52, 318.5),
        vec4(-229.11, -2043.16, 27.75, 233.5),
        vec4(-774.04, -1277.25, 5.15, 171.5),
        vec4(-1184.3, -1304.16, 5.24, 293.5),
        vec4(-1321.28, -833.8, 16.95, 140.5),
        vec4(-1613.99, -1015.82, 13.12, 342.5),
        vec4(-1392.74, -584.91, 30.24, 32.5),
        vec4(-515.19, -260.29, 35.53, 201.5),
        vec4(-760.84, -34.35, 37.83, 208.5),
        vec4(-1284.06, 297.52, 64.93, 148.5),
        vec4(-808.29, 828.88, 202.89, 200.5),
    },
    ['paleto bay'] = {
        vec4(1725.94, 6405.64, 34.34, 150.57),
        vec4(1307.95, 6502.82, 20.1, 185.6),
        vec4(417.57, 6587.04, 27.16, 181.9),
        vec4(204.72, 6590.57, 31.62, 164.33),
        vec4(46.2, 6595.32, 31.65, 225.03),
        vec4(-113.93, 6437.38, 31.59, 178.04),
        vec4(-203.14, 6453.16, 31.17, 253.96),
        vec4(-390.32, 6274.2, 29.98, 46.52),
        vec4(-424.74, 6028.98, 31.49, 296.89),
        vec4(-809.04, 5410.89, 34.08, 16.65),
        vec4(-572.18, 5350.75, 70.23, 324.77),
        vec4(-784.28, 5556.99, 33.46, 165.04),
    },
    ['sandy shores'] = {
        vec4(2444.21, 4611.59, 36.83, 178.09),
        vec4(2510.72, 4145.19, 38.74, 245.24),
        vec4(2002.28, 3759.94, 32.18, 219.82),
        vec4(1583.73, 3650.02, 34.41, 25.25),
        vec4(921.15, 3591.25, 33.13, 278.83),
        vec4(754.93, 4189.9, 40.81, 11.12),
        vec4(1417.47, 4393.36, 43.8, 73.71),
        vec4(1680.86, 4823.27, 42.05, 107.33),
        vec4(1929.66, 5152.73, 44.23, 195.74),
    },
}

-- Lista plana e determinística de pontos (mesma ordem no client e no servidor)
Config.PointList = {}
do
    local zones = {}
    for name in pairs(Config.Points) do zones[#zones + 1] = name end
    table.sort(zones)
    for _, name in ipairs(zones) do
        for _, p in ipairs(Config.Points[name]) do
            Config.PointList[#Config.PointList + 1] = {
                zone = name,
                coords = vec3(p.x, p.y, p.z),
                heading = p.w,
            }
        end
    end
end

---@param model string|number
---@return boolean
function Config.IsAllowedVehicle(model)
    local hash = type(model) == 'string' and joaat(model) or model
    for _, m in ipairs(Config.AllowedVehicles) do
        if joaat(m) == hash then return true end
    end
    return false
end
