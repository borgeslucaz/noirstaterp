---Catálogo inicial. Só é lido no primeiro boot, com as tabelas do editor vazias; depois
---disso o banco é a fonte e tudo muda pelo editor in-game (/editoronibus).
---Fica fora de `files{}`: não vai para o cliente.
---
---Paradas: `dock` é o ponto da parada, na calçada (ajustado com o ShadowForge; heading = sentido
---da via); o ônibus encosta a até 9 m dele. `zone` é a área onde os passageiros esperam: aqui,
---4 × 2 m centrada no próprio ponto e alinhada com a via. Ajuste pelo editor.
---As paradas 1, 7, 9, 15, 17, 26, 33, 34, 35, 39, 42, 43, 47 e 48 são rascunho gerado do
---dataset do Lachee/fivem-busdriver (MIT) e ainda não foram conferidas no jogo.

return {
    depot = {
        ped = { x = 449.37, y = -658.14, z = 28.45, w = 239.5 },
        pedModel = 's_m_m_gentransport',
        spawn = { x = 471.04, y = -583.88, z = 28.5, w = 175.5 },
        radius = 30.0,
        blip = { enabled = true, sprite = 513, color = 15, scale = 0.7, label = 'Central de Transporte' },
    },

    stop = {
        radius = 9.0,
        maxDockSpeedKmh = 8.0,
        maxDoorSpeedKmh = 3.0,
        serviceTimeoutMs = 25000,
        pedExitTimeoutMs = 7000,
        pedEnterTimeoutMs = 10000,
    },

    passenger = {
        spawnDistance = 150.0,
        minDemand = 0,
        maxDemand = 5,
        exitDespawnMs = 25000,
        models = { 'a_m_y_business_01', 'a_f_y_business_01' },
    },

    -- Bônus sobre o basePay: $ por passageiro (até passengerCap × basePay) e (nota − 80)%
    -- do basePay (até scoreCap). XP: xpPerPassenger por passageiro, até xpCap × baseXp.
    payout = { perPassenger = 5, passengerCap = 0.25, scoreCap = 0.20, xpPerPassenger = 2, xpCap = 0.15 },

    -- Tempo esperado de uma volta = km em linha reta × secondsPerKm + paradas × secondsPerStop
    -- (35 s por parada fecha com as voltas medidas: M01 em 327 s, I02 em 376–547 s).
    -- Pontualidade 100 até esperado × tolerance; volta mais rápida que minFraction × esperado
    -- não é paga (anti-teleporte).
    timing = { secondsPerKm = 80, secondsPerStop = 35, tolerance = 1.15, minFraction = 0.35 },

    -- Horário de pico (hora do servidor): a demanda máxima por parada é multiplicada.
    peak = { enabled = true, windows = { { from = 7, to = 9 }, { from = 17, to = 19 } }, demandMultiplier = 1.5 },

    vehicleFailure = { engineHealth = 0.0 },

    -- Nível 10 em ~4 semanas com ~2 h por dia (~1.200 XP/h).
    levels = {
        { xp = 0, title = 'Motorista Aprendiz' },
        { xp = 1500, title = 'Motorista Urbano' },
        { xp = 3000, title = 'Operador Municipal' },
        { xp = 5000, title = 'Motorista Sênior' },
        { xp = 9000, title = 'Motorista Expresso' },
        { xp = 15000, title = 'Motorista Regional' },
        { xp = 23000, title = 'Motorista Intermunicipal' },
        { xp = 33000, title = 'Especialista de Frota' },
        { xp = 46000, title = 'Supervisor de Linha' },
        { xp = 62000, title = 'Mestre de Operações' },
    },

    -- Capacidade de rentalbus e airbus é provisória: conferir os assentos no jogo.
    vehicles = {
        { model = 'rentalbus', label = 'Micro-ônibus', capacity = 8, doors = { 0, 1 }, minLevel = 1 },
        { model = 'bus', label = 'Ônibus urbano', capacity = 11, doors = { 0, 1 }, minLevel = 2 },
        { model = 'airbus', label = 'Ônibus do aeroporto', capacity = 11, doors = { 0, 1 }, minLevel = 4 },
        { model = 'coach', label = 'Rodoviário', capacity = 9, doors = { 0, 1 }, minLevel = 5 },
        { model = 'tourbus', label = 'Turismo', capacity = 9, doors = { 0, 1 }, minLevel = 8 },
    },

    stops = {
        { id = 1, name = 'Vespucci Blvd East', dock = { x = 357.94, y = -1070.45, z = 29.39, w = 2.3 }, zone = { x = 357.94, y = -1070.45, z = 29.39, length = 4, width = 2, height = 3, rotation = 2.3 } },
        { id = 3, name = 'Strawberry Ave', dock = { x = 302.49, y = -760.16, z = 29.31, w = 256.85 }, zone = { x = 302.49, y = -760.16, z = 29.31, length = 4, width = 2, height = 3, rotation = 256.85 } },
        { id = 5, name = 'San Andreas Ave', dock = { x = 120.53, y = -780.38, z = 31.37, w = 154.51 }, zone = { x = 120.53, y = -780.38, z = 31.37, length = 4, width = 2, height = 3, rotation = 154.51 } },
        { id = 6, name = 'Alta St', dock = { x = -177.06, y = -811.17, z = 31.26, w = 256.12 }, zone = { x = -177.06, y = -811.17, z = 31.26, length = 4, width = 2, height = 3, rotation = 256.12 } },
        { id = 7, name = 'Vespucci Blvd / Peaceful St', dock = { x = -252.21, y = -888.8, z = 30.69, w = 343.5 }, zone = { x = -252.21, y = -888.8, z = 30.69, length = 4, width = 2, height = 3, rotation = 343.5 } },
        { id = 8, name = 'Peaceful St / Vespucci', dock = { x = -265.58, y = -826.85, z = 31.77, w = 74.22 }, zone = { x = -265.58, y = -826.85, z = 31.77, length = 4, width = 2, height = 3, rotation = 74.22 } },
        { id = 9, name = 'Peaceful St / San Andreas Ave', dock = { x = -251.4, y = -712.3, z = 33.43, w = 253.72 }, zone = { x = -251.4, y = -712.3, z = 33.43, length = 4, width = 2, height = 3, rotation = 253.72 } },
        { id = 10, name = 'San Andreas Ave East', dock = { x = -508.17, y = -674.7, z = 33.13, w = 357.76 }, zone = { x = -508.17, y = -674.7, z = 33.13, length = 4, width = 2, height = 3, rotation = 357.76 } },
        { id = 11, name = 'San Andreas Ave West', dock = { x = -696, y = -673.09, z = 30.79, w = 350.33 }, zone = { x = -696, y = -673.09, z = 30.79, length = 4, width = 2, height = 3, rotation = 350.33 } },
        { id = 12, name = 'Vespucci Blvd / Ginger St', dock = { x = -713.22, y = -821.24, z = 23.6, w = 181.49 }, zone = { x = -713.22, y = -821.24, z = 23.6, length = 4, width = 2, height = 3, rotation = 181.49 } },
        { id = 13, name = 'Ginger St', dock = { x = -735.29, y = -754.58, z = 26.61, w = 92.54 }, zone = { x = -735.29, y = -754.58, z = 26.61, length = 4, width = 2, height = 3, rotation = 92.54 } },
        { id = 14, name = 'Vespucci Blvd East', dock = { x = -559.14, y = -852.15, z = 27.47, w = 2.24 }, zone = { x = -559.14, y = -852.15, z = 27.47, length = 4, width = 2, height = 3, rotation = 2.24 } },
        { id = 15, name = 'Strawberry Ave / Davis Ave', dock = { x = -111.61, y = -1682.45, z = 29.23, w = 233.34 }, zone = { x = -111.61, y = -1682.45, z = 29.23, length = 4, width = 2, height = 3, rotation = 233.34 } },
        { id = 16, name = 'Strawberry Ave / Macdonald St', dock = { x = 55.87, y = -1539.37, z = 29.29, w = 50.63 }, zone = { x = 55.87, y = -1539.37, z = 29.29, length = 4, width = 2, height = 3, rotation = 50.63 } },
        { id = 17, name = 'Roy Lowenstein Blvd / Macdonald St', dock = { x = 366.15, y = -1786.43, z = 28.96, w = 54.25 }, zone = { x = 366.15, y = -1786.43, z = 28.96, length = 4, width = 2, height = 3, rotation = 54.25 } },
        { id = 18, name = 'Carson Ave', dock = { x = 434.95, y = -2032.91, z = 23.39, w = 319.51 }, zone = { x = 434.95, y = -2032.91, z = 23.39, length = 4, width = 2, height = 3, rotation = 319.51 } },
        { id = 22, name = 'Popular St South', dock = { x = 819.23, y = -1636.33, z = 30.56, w = 271.02 }, zone = { x = 819.23, y = -1636.33, z = 30.56, length = 4, width = 2, height = 3, rotation = 271.02 } },
        { id = 24, name = 'Popular St / Olympic Fwy', dock = { x = 782.43, y = -1367.56, z = 26.57, w = 278.93 }, zone = { x = 782.43, y = -1367.56, z = 26.57, length = 4, width = 2, height = 3, rotation = 278.93 } },
        { id = 25, name = 'Popular St North', dock = { x = 764.71, y = -940.38, z = 25.68, w = 275.91 }, zone = { x = 764.71, y = -940.38, z = 25.68, length = 4, width = 2, height = 3, rotation = 275.91 } },
        { id = 26, name = 'Popular St North', dock = { x = 791.5, y = -778.06, z = 26.35, w = 93.6 }, zone = { x = 791.5, y = -778.06, z = 26.35, length = 4, width = 2, height = 3, rotation = 93.6 } },
        { id = 27, name = 'Hawick Ave / Boulevard Del Perro', dock = { x = -501.22, y = 27.24, z = 44.79, w = 188.06 }, zone = { x = -501.22, y = 27.24, z = 44.79, length = 4, width = 2, height = 3, rotation = 188.06 } },
        { id = 28, name = 'Boulevard Del Perro / Rockford Dr', dock = { x = -697.08, y = -1.81, z = 38.22, w = 211.24 }, zone = { x = -697.08, y = -1.81, z = 38.22, length = 4, width = 2, height = 3, rotation = 211.24 } },
        { id = 29, name = 'Boulevard Del Perro / Mad Wayne Thunder Dr', dock = { x = -931.81, y = -119.98, z = 37.78, w = 195.34 }, zone = { x = -931.81, y = -119.98, z = 37.78, length = 4, width = 2, height = 3, rotation = 195.34 } },
        { id = 30, name = 'Boulevard Del Perro West', dock = { x = -1527.81, y = -460.28, z = 35.42, w = 211.53 }, zone = { x = -1527.81, y = -460.28, z = 35.42, length = 4, width = 2, height = 3, rotation = 211.53 } },
        { id = 31, name = 'Marathon Ave', dock = { x = -1167.3, y = -394.93, z = 34.68, w = 185.94 }, zone = { x = -1167.3, y = -394.93, z = 34.68, length = 4, width = 2, height = 3, rotation = 185.94 } },
        { id = 32, name = 'Marathon Ave / Prosperity St', dock = { x = -1412.64, y = -563.84, z = 29.35, w = 212.87 }, zone = { x = -1412.64, y = -563.84, z = 29.35, length = 4, width = 2, height = 3, rotation = 212.87 } },
        { id = 33, name = 'Marathon Ave / Bay City Ave', dock = { x = -1476.13, y = -638.06, z = 30.37, w = 38.65 }, zone = { x = -1476.13, y = -638.06, z = 30.37, length = 4, width = 2, height = 3, rotation = 38.65 } },
        { id = 34, name = 'West Eclipse Blvd / Dorset Dr', dock = { x = -1426.29, y = -97.23, z = 51.64, w = 31.54 }, zone = { x = -1426.29, y = -97.23, z = 51.64, length = 4, width = 2, height = 3, rotation = 31.54 } },
        { id = 35, name = 'Dorset Dr', dock = { x = -685.51, y = -381.05, z = 34.19, w = 342.71 }, zone = { x = -685.51, y = -381.05, z = 34.19, length = 4, width = 2, height = 3, rotation = 342.71 } },
        { id = 36, name = 'Bay City Ave / Invention Ct', dock = { x = -1218.96, y = -1219.37, z = 6.69, w = 284.58 }, zone = { x = -1218.96, y = -1219.37, z = 6.69, length = 4, width = 2, height = 3, rotation = 284.58 } },
        { id = 37, name = 'Magellan Ave / Aguja St', dock = { x = -1174.37, y = -1474.17, z = 3.38, w = 313.82 }, zone = { x = -1174.37, y = -1474.17, z = 3.38, length = 4, width = 2, height = 3, rotation = 313.82 } },
        { id = 38, name = 'Dashound Terminal', dock = { x = 453.81, y = -622.52, z = 27.52, w = 259.08 }, zone = { x = 453.81, y = -622.52, z = 27.52, length = 4, width = 2, height = 3, rotation = 259.08 } },
        { id = 39, name = 'Vinewood Racetrack', dock = { x = 954.21, y = 175.08, z = 81.66, w = 174.56 }, zone = { x = 954.21, y = 175.08, z = 81.66, length = 4, width = 2, height = 3, rotation = 174.56 } },
        { id = 40, name = 'Sandy Shores', dock = { x = 1932.02, y = 3719.43, z = 31.87, w = 214.55 }, zone = { x = 1932.02, y = 3719.43, z = 31.87, length = 4, width = 2, height = 3, rotation = 214.55 } },
        { id = 41, name = 'Grand Senora Desert', dock = { x = 1183.52, y = 2694.71, z = 36.94, w = 194.18 }, zone = { x = 1183.52, y = 2694.71, z = 36.94, length = 4, width = 2, height = 3, rotation = 194.18 } },
        { id = 42, name = 'Grapeseed', dock = { x = 1655.38, y = 4850.98, z = 42.73, w = 280.07 }, zone = { x = 1655.38, y = 4850.98, z = 42.73, length = 4, width = 2, height = 3, rotation = 280.07 } },
        { id = 43, name = 'Paleto Bay · Duluoz Ave', dock = { x = -222.79, y = 6175.8, z = 32.04, w = 228.69 }, zone = { x = -222.79, y = 6175.8, z = 32.04, length = 4, width = 2, height = 3, rotation = 228.69 } },
        { id = 45, name = 'Route 68 West', dock = { x = -2531.68, y = 2343.37, z = 33.88, w = 32.83 }, zone = { x = -2531.68, y = 2343.37, z = 33.88, length = 4, width = 2, height = 3, rotation = 32.83 } },
        { id = 46, name = 'Route 68 / Harmony', dock = { x = -1116.8, y = 2683.68, z = 17.62, w = 238.26 }, zone = { x = -1116.8, y = 2683.68, z = 17.62, length = 4, width = 2, height = 3, rotation = 238.26 } },
        { id = 47, name = 'LSIA · Air Emu', dock = { x = -1057.06, y = -2540.32, z = 13.65, w = 243.59 }, zone = { x = -1057.06, y = -2540.32, z = 13.65, length = 4, width = 2, height = 3, rotation = 243.59 } },
        { id = 48, name = 'LSIA · Terminal', dock = { x = -1019.8, y = -2739.02, z = 13.66, w = 332.64 }, zone = { x = -1019.8, y = -2739.02, z = 13.66, length = 4, width = 2, height = 3, rotation = 332.64 } },
        { id = 49, name = 'Palomino Ave / Lindsay Circus', dock = { x = -617.35, y = -905.17, z = 23.29, w = 155.96 }, zone = { x = -617.35, y = -905.17, z = 23.29, length = 4, width = 2, height = 3, rotation = 155.96 } },
        { id = 50, name = 'Hawick Ave / Alta Pl', dock = { x = 149.72, y = -212.14, z = 53.31, w = 334.1 }, zone = { x = 149.72, y = -212.14, z = 53.31, length = 4, width = 2, height = 3, rotation = 334.1 } },
    },

    -- basePay/baseXp calibrados para ~$505–647/h e ~1.150–1.400 XP/h (modelo: 80 s por km
    -- em linha reta + 25 s por parada). A07, V08, T09 e P10 ainda sem tempo medido.
    routes = {
        { id = 'small_metro', code = 'M01', name = 'Linha M01 · Centro', minLevel = 1, stops = { 3, 5, 6, 8, 38 }, vehicles = { 'rentalbus', 'bus' }, basePay = 40, baseXp = 105 },
        { id = 'industry', code = 'I02', name = 'Linha I02 · Industrial', minLevel = 1, stops = { 50, 25, 24, 22, 18, 16, 38 }, vehicles = { 'rentalbus', 'bus' }, basePay = 70, baseXp = 180 },
        { id = 'medium_metro', code = 'M03', name = 'Linha M03 · Metropolitana', minLevel = 2, stops = { 5, 31, 32, 36, 12, 13, 11, 10, 38 }, vehicles = { 'bus' }, basePay = 85, baseXp = 210 },
        { id = 'long_beach', code = 'C04', name = 'Linha C04 · Costa Oeste', minLevel = 3, stops = { 27, 28, 29, 30, 36, 37, 49, 14, 8, 38 }, vehicles = { 'bus' }, basePay = 95, baseXp = 240 },
        { id = 'airport', code = 'A07', name = 'Linha A07 · Aeroporto', minLevel = 4, stops = { 38, 1, 15, 47, 48, 17, 38 }, vehicles = { 'airbus', 'bus' }, basePay = 90, baseXp = 235 },
        { id = 'sandy_express', code = 'X05', name = 'Expresso X05 · Sandy Shores', minLevel = 5, stops = { 38, 40, 38 }, vehicles = { 'coach' }, basePay = 120, baseXp = 325 },
        { id = 'vinewood', code = 'V08', name = 'Linha V08 · Vinewood', minLevel = 6, stops = { 38, 26, 39, 50, 9, 38 }, vehicles = { 'bus' }, basePay = 75, baseXp = 185 },
        { id = 'long_rural', code = 'R06', name = 'Regional R06 · Route 68', minLevel = 7, stops = { 38, 40, 41, 46, 45, 38 }, vehicles = { 'coach' }, basePay = 180, baseXp = 495 },
        { id = 'tour', code = 'T09', name = 'Turismo T09 · Oeste', minLevel = 8, stops = { 38, 50, 35, 34, 30, 33, 37, 7, 38 }, vehicles = { 'tourbus' }, basePay = 105, baseXp = 265 },
        { id = 'paleto', code = 'P10', name = 'Regional P10 · Paleto Bay', minLevel = 9, stops = { 38, 41, 42, 43, 45, 46, 38 }, vehicles = { 'coach' }, basePay = 235, baseXp = 635 },
    },
}
