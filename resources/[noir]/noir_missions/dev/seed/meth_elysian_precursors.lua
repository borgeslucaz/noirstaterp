-- Semente da missão Elysian Chemical Shipment. Só dados: tudo aqui é o que o editor monta.
-- Gera missions/meth_elysian_precursors.json com:
--   lua5.4 dev/build_seed.lua meth_elysian_precursors
--
-- COORDENADAS APROXIMADAS. A missão sai como rascunho: reposicionar tudo no editor
-- (/noirmissions → DEFINIR POSIÇÃO) antes de publicar.

local W = { x = 60.0, y = -2560.0, z = 6.0 } -- centro do galpão (aproximado)

local function at(dx, dy, dz, h)
    return { x = W.x + dx, y = W.y + dy, z = W.z + (dz or 0.0), w = h or 0.0 }
end

local function guard(model, weapon, coords, extra)
    local ped = {
        model = model, weapon = weapon, coords = coords,
        armor = 25, health = 200, accuracy = 35, combatAbility = 1, combatRange = 1,
        movement = 'scenario', scenario = 'WORLD_HUMAN_GUARD_STAND',
    }
    for key, value in pairs(extra or {}) do ped[key] = value end
    return ped
end

local function crew(model, weapon)
    return { model = model, weapon = weapon, armor = 50, health = 200, accuracy = 40, combatAbility = 2, combatRange = 1 }
end

return {
    id = 'meth_elysian_precursors',
    name = 'Elysian Chemical Shipment',
    description = 'Roubar tambores de precursor químico de um galpão em Elysian Island e entregar a um contato.',
    category = 'meth',
    difficulty = 'medium',
    minPlayers = 2,
    maxPlayers = 6,
    cooldownMinutes = 180,
    timeLimitMinutes = 60,
    gangRequired = true,
    gangMinGrade = 0,
    participantRadius = 60,

    start = {
        type = 'phone',
        caller = 'Contato',
        text = 'Tem um carregamento de químico parado num galpão em Elysian. Quatro tambores. Topa?',
    },

    variables = {
        { id = 'alarm_active', type = 'boolean', default = 'false' },
        { id = 'hack_success', type = 'boolean', default = 'false' },
        { id = 'reinforcement_called', type = 'boolean', default = 'false' },
        { id = 'shipment', type = 'string', random = { 'Composto de Limpeza Industrial', 'Solvente Industrial X-9', 'Desengraxante Pesado' } },
        { id = 'cargo_batch', type = 'string', random = { 'B-04', 'C-17', 'F-11', 'A-32' } },
        { id = 'cargo_storage', type = 'string', random = { 'Galpão B', 'Galpão C', 'Depósito 4' } },
        { id = 'delivery_location', type = 'string' },
    },

    zones = {
        { id = 'elysian', label = 'Elysian Island', coords = at(0, 0), radius = 220 },
        { id = 'restricted', label = 'Galpão (área restrita)', coords = at(0, 0), radius = 22 },
    },

    pedGroups = {
        {
            id = 'ext_guards', label = 'Seguranças externos', behavior = 'guard',
            hostileZone = 'restricted', hostileOnAlarm = true, alarmVar = 'alarm_active',
            hostileOnShot = true, shotRadius = 80, hostileOnDamage = true, alarmOnHostile = true,
            warnRadius = 15,
            warnText = { 'Ei! Área restrita. Dá meia volta.', 'Aqui não é lugar de passeio. Vaza.' },
            peds = {
                guard('s_m_m_security_01', 'WEAPON_PISTOL', at(-14, 12, 0, 180)),
                guard('s_m_m_security_01', 'WEAPON_PISTOL', at(14, 12, 0, 180)),
                guard('s_m_m_security_01', 'WEAPON_SMG', at(0, 18, 0, 200), { movement = 'patrol', patrolRadius = 12 }),
            },
        },
        {
            id = 'warehouse_guards', label = 'Seguranças do galpão', behavior = 'guard',
            hostileZone = 'restricted', hostileOnAlarm = true, alarmVar = 'alarm_active',
            hostileOnShot = true, shotRadius = 60, hostileOnDamage = true, alarmOnHostile = true,
            warnRadius = 8,
            warnText = { 'Quem deixou você entrar?' },
            peds = {
                guard('g_m_y_mexgoon_01', 'WEAPON_SMG', at(-6, -8, 0, 90)),
                guard('g_m_y_mexgoon_01', 'WEAPON_PUMPSHOTGUN', at(6, -10, 0, 270)),
                guard('g_m_y_mexgoon_01', 'WEAPON_PISTOL', at(0, -14, 0, 0), { movement = 'scenario', scenario = 'WORLD_HUMAN_SMOKING' }),
            },
        },
        {
            id = 'office_guard', label = 'Segurança do escritório', behavior = 'guard',
            hostileZone = 'restricted', hostileOnAlarm = true, alarmVar = 'alarm_active',
            hostileOnShot = true, shotRadius = 40, hostileOnDamage = true, alarmOnHostile = true,
            warnRadius = 5, warnText = { 'O escritório tá fechado.' },
            peds = {
                guard('s_m_m_security_01', 'WEAPON_PISTOL', at(9, 4, 0, 135), { movement = 'scenario', scenario = 'WORLD_HUMAN_CLIPBOARD' }),
            },
        },
    },

    vehicles = {
        {
            id = 'van', label = 'Van da carga', model = 'speedo', coords = at(-25, 5, 0, 90),
            spawnOnStart = true, locked = false, giveKeys = true, required = true, cargoCapacity = 4,
        },
    },

    props = {},

    cargo = {
        {
            id = 'barrels', label = 'Tambores químicos', model = 'prop_barrel_02a', mode = 'carry',
            quantity = 4, randomizeCorrect = true, revealed = false,
            inspect = true, correctLabel = 'Lote {{cargo_batch}} — {{shipment}}', decoyVar = 'cargo_batch',
            carryPreset = 'barrel', canSprint = false,
            requireVehicle = true, vehicleMode = 'mission', vehicleId = 'van',
            pieces = {
                at(-8, -2, 0, 0), at(-7, -3.2, 0, 0), at(-8.2, -4.4, 0, 0),
                at(-2, -5, 0, 0), at(-0.8, -5.2, 0, 0),
                at(4, -3, 0, 0), at(5.2, -3.1, 0, 0), at(4.6, -4.3, 0, 0),
            },
        },
    },

    interactions = {
        {
            id = 'office_pc', label = 'Hackear computador', kind = 'hack',
            coords = at(10, 2, 0.95, 270), model = 'prop_laptop_01a', distance = 1.5,
            revealed = true, minigame = 'noir:circuit', difficulty = 2, duration = 6,
            once = true, retry = false,
            infoTitle = 'MANIFESTO DE CARGA',
            infoLines = {
                { label = 'Carga', value = '{{shipment}}' },
                { label = 'Lote', value = '{{cargo_batch}}' },
                { label = 'Armazenado', value = '{{cargo_storage}}' },
            },
            onSuccess = {
                { type = 'set_var', var = 'hack_success', value = 'true' },
                { type = 'set_var', var = 'alarm_active', value = 'false' },
                { type = 'reveal_cargo', cargo = 'barrels' },
            },
            onFailure = {
                { type = 'set_var', var = 'alarm_active', value = 'true' },
                { type = 'notify', kind = 'warning', text = 'O alarme disparou. Deu pra ver o lote antes de travar: {{cargo_batch}}.' },
                { type = 'reveal_cargo', cargo = 'barrels' },
            },
        },
    },

    reinforcements = {
        {
            id = 'suv', label = 'SUV de reforço', model = 'granger',
            spawn = { x = -260.0, y = -2470.0, z = 6.0, w = 230.0 },
            destination = at(-20, 20, 0),
            arrivalDistance = 18, speed = 28, drivingStyle = 'rushed',
            exitOnArrival = true, engage = true, maxTravelSeconds = 150,
            crew = {
                crew('g_m_y_mexgoon_01', 'WEAPON_PISTOL'),
                crew('g_m_y_mexgoon_01', 'WEAPON_SMG'),
                crew('g_m_y_mexgoon_01', 'WEAPON_SMG'),
                crew('g_m_y_mexgoon_01', 'WEAPON_PUMPSHOTGUN'),
            },
        },
    },

    chases = {
        {
            id = 'enemy_suv', label = 'SUV inimiga', model = 'granger',
            countMin = 1, countMax = 2,
            spawnPoints = {
                { x = 220.0, y = -2240.0, z = 6.0, w = 180.0 },
                { x = -180.0, y = -2290.0, z = 6.0, w = 200.0 },
                { x = 420.0, y = -2580.0, z = 6.0, w = 90.0 },
                { x = 160.0, y = -2880.0, z = 6.0, w = 0.0 },
            },
            minSpawnDistance = 120, maxSpawnDistance = 450, maxSpeed = 45,
            drivingStyle = 'aggressive', passengersShoot = true, driverShoots = false, ram = true,
            durationSeconds = 240, loseDistance = 450,
            crew = {
                crew('g_m_y_mexgoon_01', 'WEAPON_PISTOL'),
                crew('g_m_y_mexgoon_01', 'WEAPON_MICROSMG'),
                crew('g_m_y_mexgoon_01', 'WEAPON_MICROSMG'),
            },
            waves = {
                { model = 'bati', countMin = 1, countMax = 2, delaySeconds = 15 },
            },
        },
    },

    deliveryGroups = {
        {
            id = 'meth_dropoffs', label = 'Pontos de entrega de meth',
            points = {
                { label = 'Cypress Flats', coords = { x = 912.0, y = -2280.0, z = 30.5, w = 90.0 }, radius = 10 },
                { label = 'La Mesa', coords = { x = 836.0, y = -1110.0, z = 26.4, w = 0.0 }, radius = 10 },
                { label = 'Harmony', coords = { x = 588.0, y = 2744.0, z = 42.0, w = 0.0 }, radius = 10 },
                { label = 'Sandy Shores', coords = { x = 1694.0, y = 3604.0, z = 35.4, w = 0.0 }, radius = 10 },
                { label = 'El Burro Heights', coords = { x = 1384.0, y = -2080.0, z = 52.0, w = 0.0 }, radius = 10 },
            },
        },
    },

    steps = {
        {
            id = 'go_elysian', type = 'goto', label = 'Ir até Elysian Island',
            objective = 'Vá até o galpão em Elysian Island.',
            coords = at(0, 0), radius = 100, who = 'any', showGps = true, showBlip = true,
            blipLabel = 'Galpão de Elysian', blipSprite = 473, blipColor = 5,
            onComplete = {
                { type = 'spawn_group', group = 'ext_guards' },
                { type = 'spawn_group', group = 'warehouse_guards' },
                { type = 'spawn_group', group = 'office_guard' },
            },
        },
        {
            id = 'find_manifest', type = 'interact', label = 'Achar o manifesto',
            objective = 'Encontre informações sobre o carregamento.',
            interaction = 'office_pc', complete = 'any',
        },
        {
            id = 'load_barrels', type = 'cargo', label = 'Carregar a van',
            objective = 'Carregue os tambores químicos na van.',
            cargo = 'barrels', target = 'loaded', count = 0, reveal = true,
        },
        {
            id = 'escape', type = 'leave_area', label = 'Sair de Elysian',
            objective = 'Saia de Elysian Island com a carga.',
            coords = at(0, 0), radius = 350, who = 'vehicle', cargo = 'barrels', cargoCount = 0, showArea = true,
            onComplete = {
                { type = 'send_sms', text = 'Bom trabalho. Tenho um lugar para vocês deixarem isso.' },
                { type = 'pick_delivery', group = 'meth_dropoffs', var = 'delivery_location' },
                { type = 'chance', percent = 60, ['then'] = {
                    { type = 'wait', seconds = 20, secondsMax = 40 },
                    { type = 'start_chase', chase = 'enemy_suv' },
                } },
            },
        },
        {
            id = 'deliver', type = 'deliver', label = 'Entregar a carga',
            objective = 'Entregue os tambores em {{delivery_location}}.',
            source = 'var', var = 'delivery_location', mode = 'vehicle', cargo = 'barrels',
            required = 0, consume = true, holdSeconds = 3,
            npcModel = 'g_m_m_chicold_01', npcOffset = 4, npcText = { 'Coloca os tambores atrás. Rápido.' },
            blipLabel = 'Entrega',
        },
    },

    triggers = {
        {
            id = 'arrive_area', label = 'Chegada a Elysian cria os seguranças', on = 'zone_enter', match = 'elysian',
            once = true,
            actions = {
                { type = 'spawn_group', group = 'ext_guards' },
                { type = 'spawn_group', group = 'warehouse_guards' },
                { type = 'spawn_group', group = 'office_guard' },
            },
        },
        {
            id = 'alarm_first_barrel', label = 'Primeiro tambor com alarme = reforço', on = 'cargo_picked', match = 'barrels',
            once = false,
            condition = { mode = 'all', rules = {
                { var = 'alarm_active', op = 'true' },
                { var = 'reinforcement_called', op = 'false' },
            } },
            actions = {
                { type = 'set_var', var = 'reinforcement_called', value = 'true' },
                { type = 'wait', seconds = 30 },
                { type = 'send_reinforcement', reinforcement = 'suv' },
            },
        },
        {
            id = 'alarm_after_pickup', label = 'Alarme depois do primeiro tambor = reforço', on = 'var_changed', match = 'alarm_active',
            once = false,
            condition = { mode = 'all', rules = {
                { var = 'alarm_active', op = 'true' },
                { var = 'cargo.barrels.picked', op = 'gte', value = '1' },
                { var = 'reinforcement_called', op = 'false' },
            } },
            actions = {
                { type = 'set_var', var = 'reinforcement_called', value = 'true' },
                { type = 'wait', seconds = 30 },
                { type = 'send_reinforcement', reinforcement = 'suv' },
            },
        },
    },

    rewards = {
        { type = 'item', item = 'chemical_precursor', amount = 2, split = 'each' },
    },
}
