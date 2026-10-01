---Configuração pública do noir_police.
---
---Vai para o cliente: só entra aqui o que o cliente precisa para desenhar, mirar e
---mostrar. Limites anti-exploit, tetos de multa e regras de apreensão ficam em
---`config/server.lua`, que nunca sai do servidor (§19.1 do SCRIPT_GOOD_PRACTICES).

return {
    debug = false,

    -- Categoria de job que conta como polícia. Todo job `leo` que estiver em
    -- `departments` é polícia; a lista de jobs mora num lugar só.
    policeJobType = 'leo',
    emsJobType = 'ems',

    -- Um departamento por job. `account` é a conta da sociedade no banco. `phoneCompany` é a
    -- empresa do sky_phone cuja linha manda os SMS (só a LSPD tem linha: 911).
    -- `serialPrefix` precisa ter até 3 letras: o ox_inventory usa texto maior como
    -- serial inteiro, e todas as armas sairiam com o mesmo número.
    departments = {
        police = { label = 'LSPD', account = 'police', serialPrefix = 'POL', blipColor = 38, phoneCompany = 'police' },
        bcso = { label = 'BCSO', account = 'bcso', serialPrefix = 'BCS', blipColor = 47, phoneCompany = 'police' },
        sasp = { label = 'SASP', account = 'sasp', serialPrefix = 'SAS', blipColor = 29, phoneCompany = 'police' },
    },

    -- Grade mínima por ação. Um departamento pode sobrescrever em
    -- `departments.<job>.grades`.
    grades = {
        fine = 0,
        seize = 0,
        evidenceStash = 0,
        evidenceManage = 2,
        license = 2,
        anklet = 1,
        interdict = 0,
        unitStatus = 0,
        meeting = 2,
        cameras = 0,
        flagPlate = 0,
        fingerprint = 0,
        takeDna = 1,
        dnaLab = 0,
    },

    -- Subunidades: permissão por config (§ regra estrutural mínima). O Qbox dá um job
    -- só por personagem, então K9 e SWAT não podem ser grupo.
    -- citizenIds = { 'ABC12345' } libera independentemente da grade.
    subunits = {
        k9 = { label = 'K9', minGrade = 2, citizenIds = {} },
        swat = { label = 'SWAT', minGrade = 3, citizenIds = {} },
    },

    stations = {
        {
            id = 'mrpd',
            label = 'Mission Row',
            departments = { 'police', 'sasp' },
            blip = { coords = vec3(434.0, -983.0, 30.7), sprite = 60, color = 29, scale = 0.8 },
            duty = { vec3(440.085, -974.924, 30.689) },
            lockers = { vec3(458.14, -990.82, 30.69) },
            evidence = { coords = vec3(459.07, -984.07, 30.69), radius = 1.5 },
            fingerprint = { coords = vec3(460.97, -989.18, 24.92), radius = 1.5 },
            -- Bancada de análise de DNA. Posição estimada: acertar com o /policiaeditor.
            lab = { coords = vec3(463.2, -986.9, 24.92), radius = 1.2 },
            -- Recepção: onde o dono retira pertences liberados. Sem ela, vale o ponto de serviço.
            reception = { coords = vec3(441.8, -981.9, 30.69), radius = 1.5 },
            cameras = { coords = vec3(440.3, -978.9, 30.69), radius = 1.2 },
            garages = {
                {
                    type = 'car',
                    point = vec3(454.6, -1017.4, 28.4),
                    spawns = { vec4(438.4, -1018.3, 27.7, 90.0), vec4(438.4, -1022.0, 27.7, 90.0) },
                },
                {
                    type = 'air',
                    point = vec3(449.17, -981.33, 43.69),
                    spawns = { vec4(449.17, -981.33, 43.69, 87.23) },
                },
            },
        },
        {
            id = 'paleto',
            label = 'Paleto Bay',
            departments = { 'bcso' },
            blip = { coords = vec3(-448.4, 6011.8, 31.7), sprite = 60, color = 47, scale = 0.8 },
            duty = { vec3(-449.811, 6012.909, 31.815) },
            lockers = { vec3(-452.41, 6013.89, 31.72) },
            evidence = { coords = vec3(-446.84, 6008.48, 31.72), radius = 1.5 },
            fingerprint = { coords = vec3(-444.96, 6010.72, 31.72), radius = 1.5 },
            lab = { coords = vec3(-443.3, 6012.2, 31.72), radius = 1.2 },
            garages = {
                {
                    type = 'car',
                    point = vec3(-455.39, 6002.02, 31.34),
                    spawns = { vec4(-460.3, 5998.8, 31.24, 90.0) },
                },
                {
                    type = 'air',
                    point = vec3(-475.43, 5988.35, 31.72),
                    spawns = { vec4(-475.43, 5988.35, 31.72, 315.0) },
                },
            },
        },
    },

    -- Frota: viatura de departamento, sem dono. `departments` vazio = todos.
    fleet = {
        car = {
            { model = 'police', label = 'Viatura (Stanier)', grade = 0, departments = { 'police', 'sasp' } },
            { model = 'police2', label = 'Viatura (Buffalo)', grade = 0, departments = { 'police', 'sasp' } },
            { model = 'police3', label = 'Viatura (Interceptor)', grade = 1, departments = { 'police', 'sasp' } },
            { model = 'police4', label = 'Descaracterizada', grade = 3 },
            { model = 'policeb', label = 'Moto', grade = 1 },
            { model = 'policet', label = 'Transporte', grade = 2 },
            { model = 'sheriff', label = 'Viatura (Sheriff)', grade = 0, departments = { 'bcso' } },
            { model = 'sheriff2', label = 'SUV (Sheriff)', grade = 1, departments = { 'bcso' } },
        },
        air = {
            { model = 'polmav', label = 'Helicóptero', grade = 2 },
        },
        platePrefix = { police = 'LSPD', bcso = 'BCSO', sasp = 'SASP' },
    },

    handsUp = {
        key = 'X',
        -- Segurar a tecla por este tempo ajoelha em vez de só levantar as mãos.
        kneelHoldMs = 700,
    },

    -- Solta quem está no ombro ou escoltado (a pílula mostra a tecla).
    release = { key = 'J' },

    cuffs = {
        -- Props próprios do ND (`police_cuffs`, `police_zip_tie_positioned`), em `stream/`
        -- já convertidos para o Enhanced. Desligado, a algema usa o prop do jogo e o zip
        -- tie fica sem prop.
        customProps = true,
        vanillaCuffModel = 'p_cs_cuffs_02_s',
        -- Som próprio do ND (awc). Também desligado até ser testado no Enhanced.
        customSound = false,
        interactDistance = 1.5,
        lockpickItem = 'lockpick',
    },

    items = {
        cuffs = 'handcuffs',
        zipties = 'zipties',
        cuffKey = 'handcuffkey',
        cutters = 'cutters',
        seizedBox = 'seized_box',
        -- Bolsa de evidências (container): toda coleta cai dentro dela.
        evidenceCase = 'evidence_case',
        filledBag = 'filled_evidence_bag',
        casing = 'casing',
        projectile = 'projectile',
        shield = 'shield',
        spikestrip = 'spikestrip',
    },

    -- Munição que deixa evidência. Chave = item de munição do ox_inventory.
    ammoEvidence = {
        ['ammo-22'] = { label = '.22 LR', projectile = true, casing = true },
        ['ammo-38'] = { label = '.38', projectile = true, casing = true },
        ['ammo-44'] = { label = '.44 Magnum', projectile = true, casing = true },
        ['ammo-45'] = { label = '.45 ACP', projectile = true, casing = true },
        ['ammo-50'] = { label = '.50 AE', projectile = true, casing = true },
        ['ammo-9'] = { label = '9mm', projectile = true, casing = true },
        ['ammo-rifle'] = { label = '5.56x45', projectile = true, casing = true },
        ['ammo-rifle2'] = { label = '7.62x39', projectile = true, casing = true },
        ['ammo-sniper'] = { label = '7.62x51', projectile = true, casing = true },
        ['ammo-heavysniper'] = { label = '.50 BMG', projectile = true, casing = true },
        ['ammo-shotgun'] = { label = 'Calibre 12', projectile = false, casing = true },
        ['ammo-musket'] = { label = '.50 Ball', projectile = true, casing = false },
    },

    gsr = {
        -- Minutos de resíduo de pólvora depois do último tiro.
        durationMinutes = 15,
        -- Minutos na água para lavar.
        waterMinutes = 1,
    },

    -- Supressores: o cliente conta se a arma tem um deles; o shotspotter ignora.
    suppressors = {
        `COMPONENT_AT_PI_SUPP_02`,
        `COMPONENT_AT_PI_SUPP`,
        `COMPONENT_AT_AR_SUPP_02`,
        `COMPONENT_AT_AR_SUPP`,
        `COMPONENT_AT_SR_SUPP`,
    },

    spikes = {
        model = `p_ld_stinger_s`,
        maxPerDeploy = 4,
    },

    shield = {
        model = `prop_ballistic_shield`,
    },

    -- Objetos do porta-malas da viatura.
    objects = {
        { id = 'cone', label = 'Cone', model = `prop_roadcone02a`, freeze = false },
        { id = 'barrier', label = 'Barreira', model = `prop_barrier_work06a`, freeze = true },
        { id = 'roadsign', label = 'Placa', model = `prop_snow_sign_road_06g`, freeze = true },
        { id = 'tent', label = 'Tenda', model = `prop_gazebo_03`, freeze = true },
        { id = 'light', label = 'Refletor', model = `prop_worklight_03b`, freeze = true },
    },

    licenses = {
        driver = 'Carteira de motorista',
        weapon = 'Porte de arma',
    },

    unitStatuses = {
        { value = 'patrol', label = 'Em patrulha' },
        { value = 'available', label = 'Disponível' },
        { value = 'busy', label = 'Ocupado' },
        { value = 'pursuit', label = 'Em perseguição' },
        { value = 'break', label = 'Em pausa' },
    },

    interdict = {
        maxRadius = 250.0,
        maxMinutes = 60,
        color = 1,
    },

    -- Radar de velocidade. `speedLimit` na unidade de `useMph`.
    radars = {
        enabled = true,
        useMph = false,
        locations = {
            { coords = vec4(-623.44, -823.08, 25.26, 145.0), speedLimit = 60 },
            { coords = vec4(-652.44, -854.08, 24.56, 325.0), speedLimit = 80 },
            { coords = vec4(1623.01, 1068.99, 80.9, 84.0), speedLimit = 110 },
            { coords = vec4(-2604.9, 2996.34, 27.53, 175.0), speedLimit = 110 },
            { coords = vec4(2136.65, -591.81, 94.27, 318.0), speedLimit = 110 },
            { coords = vec4(2117.58, -558.51, 95.68, 158.0), speedLimit = 110 },
            { coords = vec4(406.9, -969.06, 29.44, 33.0), speedLimit = 60 },
            { coords = vec4(657.32, -218.82, 44.06, 320.0), speedLimit = 110 },
            { coords = vec4(2118.29, 6040.03, 50.93, 172.0), speedLimit = 110 },
            { coords = vec4(-106.3, -1127.55, 30.78, 230.0), speedLimit = 60 },
            { coords = vec4(-823.37, -1146.98, 8.0, 300.0), speedLimit = 60 },
        },
    },

    -- Câmeras de segurança (portadas do qbx_police).
    securityCameras = {
        { label = 'LTD Gasoline - Palomino Ave. - CAM#1', coords = vec3(-705.79, -909.91, 20.9), r = vec3(-30.0, 0.0, -210.0), canRotate = false },
        { label = 'LTD Gasoline - Palomino Ave. - CAM#2', coords = vec3(-710.23, -904.35, 20.78), r = vec3(-55.0, 0.0, -130.0), canRotate = false },
        { label = '24/7 - Innocence Blvd. - CAM#1', coords = vec3(25.28, -1348.78, 31.22), r = vec3(-40.0, 0.0, -25.0), canRotate = false },
        { label = '24/7 - Innocence Blvd. - CAM#2', coords = vec3(23.8, -1339.77, 30.79), r = vec3(-20.0, 0.0, -92.0), canRotate = false },
        { label = 'LTD Gasoline - Davis Ave. - CAM#1', coords = vec3(-43.08, -1755.2, 31.61), r = vec3(-30.0, 0.0, -260.0), canRotate = false },
        { label = 'LTD Gasoline - Davis Ave. - CAM#2', coords = vec3(-43.97, -1747.98, 31.21), r = vec3(-55.0, 0.0, -160.0), canRotate = false },
        { label = 'LTD Gasoline - Mirror Park - CAM#1', coords = vec3(1164.9, -318.34, 71.28), r = vec3(-30.0, 0.0, -210.0), canRotate = false },
        { label = 'LTD Gasoline - Mirror Park - CAM#2', coords = vec3(1158.9, -314.25, 71.05), r = vec3(-55.0, 0.0, -110.0), canRotate = false },
        { label = '24/7 - Clinton Ave - CAM#1', coords = vec3(373.21, 324.7, 105.24), r = vec3(-40.0, 0.0, -35.0), canRotate = false },
        { label = '24/7 - Clinton Ave - CAM#2', coords = vec3(373.73, 333.89, 104.86), r = vec3(-20.0, 0.0, -105.0), canRotate = false },
        { label = 'LTD Gasoline - Banham Canyon - CAM#1', coords = vec3(-1822.22, 798.55, 139.73), r = vec3(-30.0, 0.0, -180.0), canRotate = false },
        { label = 'LTD Gasoline - Banham Canyon - CAM#2', coords = vec3(-1829.57, 798.34, 140.0), r = vec3(-55.0, 0.0, -91.48), canRotate = false },
        { label = '24/7 - Palomino Freeway - CAM#1', coords = vec3(2558.76, 381.7, 110.33), r = vec3(-40.0, 0.0, 60.0), canRotate = false },
        { label = '24/7 - Palomino Freeway - CAM#2', coords = vec3(2549.13, 380.56, 109.58), r = vec3(-20.0, 0.0, -10.0), canRotate = false },
        { label = '24/7 - Señora Freeway - CAM#1', coords = vec3(2679.56, 3279.89, 56.67), r = vec3(-40.0, 0.0, 40.0), canRotate = false },
        { label = '24/7 - Señora Freeway - CAM#2', coords = vec3(2670.66, 3282.85, 56.09), r = vec3(-10.0, 0.0, -40.0), canRotate = false },
        { label = '24/7 - Niland Ave. - CAM#1', coords = vec3(1961.97, 3739.42, 33.77), r = vec3(-40.0, 0.0, 20.0), canRotate = false },
        { label = '24/7 - Niland Ave. - CAM#2', coords = vec3(1955.55, 3746.76, 33.2), r = vec3(-10.0, 0.0, -70.0), canRotate = false },
        { label = '24/7 - Route 68 - CAM#1', coords = vec3(547.68, 2672.88, 44.02), r = vec3(-40.0, 0.0, 160.0), canRotate = false },
        { label = '24/7 - Route 68 - CAM#2', coords = vec3(550.93, 2662.73, 44.37), r = vec3(-40.0, 0.0, 60.0), canRotate = false },
        { label = '24/7 - Mount Chiliad - CAM#1', coords = vec3(1726.85, 6413.76, 37.64), r = vec3(-40.0, 0.0, -80.0), canRotate = false },
        { label = '24/7 - Mount Chiliad - CAM#2', coords = vec3(1731.16, 6423.27, 37.28), r = vec3(-40.0, 0.0, 210.0), canRotate = false },
        { label = 'LTD Gasoline - Grapeseed - CAM#1', coords = vec3(1700.33, 4919.91, 44.04), r = vec3(-30.0, 0.0, 0.0), canRotate = false },
        { label = 'LTD Gasoline - Grapeseed - CAM#2', coords = vec3(1708.34, 4920.88, 43.68), r = vec3(-55.0, 0.0, 100.0), canRotate = false },
        { label = '24/7 - Barbareno Rd. - CAM#1', coords = vec3(-3240.69, 1000.9, 14.51), r = vec3(-40.0, 0.0, 65.0), canRotate = false },
        { label = '24/7 - Barbareno Rd. - CAM#2', coords = vec3(-3249.74, 999.95, 14.13), r = vec3(-10.0, 0.0, -5.0), canRotate = false },
        { label = '24/7 - Ineseno Rd. - CAM#1', coords = vec3(-3037.53, 584.58, 10.15), r = vec3(-40.0, 0.0, 65.0), canRotate = false },
        { label = '24/7 - Ineseno Rd. - CAM#2', coords = vec3(-3047.28, 582.21, 9.93), r = vec3(-30.0, 0.0, -5.0), canRotate = false },
        { label = "Rob's Liquors - San Andreas Ave. - CAM#1", coords = vec3(-1224.87, -911.09, 14.4), r = vec3(-35.0, 0.0, -6.78), canRotate = false },
        { label = "Rob's Liquors - Prosperity St. - CAM#1", coords = vec3(-1482.9, -380.46, 42.36), r = vec3(-35.0, 0.0, 79.53), canRotate = false },
        { label = "Rob's Liquors - El Rancho Blvd. - CAM#1", coords = vec3(1133.02, -978.71, 48.52), r = vec3(-35.0, 0.0, -137.3), canRotate = false },
        { label = "Rob's Liquors - Route 68 - CAM#1", coords = vec3(1169.86, 2711.49, 40.43), r = vec3(-35.0, 0.0, 127.17), canRotate = false },
        { label = "Rob's Liquors - Great Ocean - CAM#1", coords = vec3(-2966.1, 386.92, 17.39), r = vec3(-35.0, 0.0, 20.0), canRotate = false },
        { label = 'Fleeca - Meteor St. - CAM#1', coords = vec3(309.34, -281.44, 55.88), r = vec3(-35.0, 0.0, -146.16), canRotate = false },
        { label = 'Fleeca - Vespucci Blvd. - CAM#1', coords = vec3(144.87, -1043.04, 31.02), r = vec3(-35.0, 0.0, -143.98), canRotate = false },
        { label = 'Fleeca - Hawick Ave. - CAM#1', coords = vec3(-355.76, -52.51, 50.75), r = vec3(-35.0, 0.0, -143.87), canRotate = false },
        { label = 'Fleeca - Del Perro Blvd. - CAM#1', coords = vec3(-1214.23, -335.86, 39.52), r = vec3(-35.0, 0.0, -97.86), canRotate = false },
        { label = 'Fleeca - Great Ocean Hwy. - CAM#1', coords = vec3(-2958.89, 478.98, 17.41), r = vec3(-35.0, 0.0, -34.7), canRotate = false },
        { label = 'Fleeca - Route 68 - CAM#1', coords = vec3(1178.8, 2710.78, 39.66), r = vec3(-35.0, 0.0, 50.0), canRotate = false },
        { label = 'Pacific Bank - CAM#1', coords = vec3(265.61, 212.97, 111.28), r = vec3(-25.0, 0.0, 28.05), canRotate = false },
        { label = 'Pacific Bank - CAM#2', coords = vec3(232.86, 221.46, 107.83), r = vec3(-25.0, 0.0, -140.91), canRotate = false },
        { label = 'Pacific Bank - CAM#3', coords = vec3(232.21, 233.69, 99.42), r = vec3(-45.05, 10.0, 120.0), canRotate = false },
        { label = 'Paleto Bank - CAM#1', coords = vec3(-102.94, 6467.67, 33.42), r = vec3(-35.0, 0.0, 24.66), canRotate = false },
        { label = 'Vangelico - CAM#1', coords = vec3(-627.54, -239.74, 40.33), r = vec3(-35.0, 0.0, 5.78), canRotate = true },
        { label = 'Vangelico - CAM#2', coords = vec3(-627.51, -229.51, 40.24), r = vec3(-35.0, 0.0, -95.78), canRotate = true },
        { label = 'Vangelico - CAM#3', coords = vec3(-620.3, -224.31, 40.23), r = vec3(-35.0, 0.0, 165.78), canRotate = true },
        { label = 'Vangelico - CAM#4', coords = vec3(-622.57, -236.3, 40.31), r = vec3(-35.0, 0.0, 5.78), canRotate = true },
    },

    heli = {
        models = { `polmav` },
        -- Controles do GTA (não teclas): 74 = farol (H), 51 = interagir (E).
        spotlightControl = 74,
        cameraControl = 51,
    },

    -- Status de evidência (vindo do qbx_consumables e do corpo): o que a polícia vê
    -- ao examinar alguém. O GSR mora no módulo próprio; `gunpowder` não entra.
    evidenceStatuses = {
        fight = 'Mãos vermelhas',
        widepupils = 'Pupilas dilatadas',
        redeyes = 'Olhos vermelhos',
        weedsmell = 'Cheiro de maconha',
        chemicals = 'Cheiro de produto químico',
        heavybreath = 'Respiração ofegante',
        sweat = 'Suando muito',
        handbleed = 'Sangue nas mãos',
        confused = 'Confuso',
        alcohol = 'Cheiro de álcool',
        heavyalcohol = 'Cheiro forte de álcool',
        agitated = 'Agitado, com sinais de crack',
    },
}
