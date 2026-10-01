Config = {}

Config.Locale = 'pt'
Config.Theme = 'default'       -- 'default', 'green', 'yellow', 'silver', 'red'
Config.TargetSystem = 'ox-target'
Config.LogType = 'ox'          -- 'ox' (lib.logger → ox:logger), 'discord' ou 'fivemanage'
Config.DynamicPriceInterval = 30 -- Minutes between price updates (global default)

Config.WebhookURL = ''
Config.FivemanageToken = ''

-- License types that can be required on items.
-- Set 'license' on any item in Config.Shops to the key below to restrict it.
-- 'metadata' is the key inside player.metadata.licences (QBCore, QBox, ESX with esx_license).
-- 'esx_type' is optional - overrides the license type name for older ESX DB lookups.
-- Example item usage: { name = 'weapon_pistol', label = 'Pistol', price = 500, ..., license = 'weaponlicense' }
Config.Licenses = {
    ['weaponlicense'] = {
        label    = 'Porte de Arma',
        metadata = 'weapon',
    },
}

-- Catálogos por tipo de loja. Cada loja abaixo aponta para um deles; o painel
-- /smartshopedit ainda pode sobrescrever uma loja específica (saved_shops.json).
local Catalog = {
    general = {
        { name = 'burger', label = 'Burger', price = 10, image = 'burger.png', maxQty = 20, category = 'Comida' },
        { name = 'water',  label = 'Água',   price = 10, image = 'water.png',  maxQty = 20, category = 'Bebida' },
        { name = 'sprunk', label = 'Sprunk', price = 10, image = 'sprunk.png', maxQty = 20, category = 'Bebida' },
    },
    liquor = {
        { name = 'water',  label = 'Água',   price = 10, image = 'water.png',  maxQty = 20, category = 'Bebida' },
        { name = 'sprunk', label = 'Sprunk', price = 10, image = 'sprunk.png', maxQty = 20, category = 'Bebida' },
        { name = 'burger', label = 'Burger', price = 15, image = 'burger.png', maxQty = 20, category = 'Comida' },
    },
    hardware = {
        { name = 'lockpick', label = 'Lockpick', price = 10, image = 'lockpick.png', maxQty = 10, category = 'Ferramentas' },
        { name = 'zipties', label = 'Zip tie', price = 25, image = 'zipties.png', maxQty = 5, category = 'Ferramentas' },
        { name = 'cutters', label = 'Alicate de corte', price = 60, image = 'wirecutter.png', maxQty = 1, category = 'Ferramentas' },
    },
    ammunation = {
        { name = 'ammo-9',        label = 'Munição 9mm', price = 5,    image = 'ammo-9.png',        maxQty = 250, category = 'Munição' },
        { name = 'WEAPON_KNIFE',  label = 'Faca',        price = 200,  image = 'WEAPON_KNIFE.png',  maxQty = 1,   category = 'Armas brancas' },
        { name = 'WEAPON_BAT',    label = 'Taco',        price = 100,  image = 'WEAPON_BAT.png',    maxQty = 1,   category = 'Armas brancas' },
        { name = 'WEAPON_PISTOL', label = 'Pistola',     price = 1000, image = 'WEAPON_PISTOL.png', maxQty = 1,   category = 'Armas de fogo', metadata = { registered = true }, license = 'weaponlicense' },
    },
}

local Kinds = {
    general    = { name = 'Loja de Conveniência', ped = 'mp_m_shopkeep_01',  scenario = 'WORLD_HUMAN_STAND_IMPATIENT', blip = 59,  label = 'Loja' },
    liquor     = { name = 'Loja de Bebidas',      ped = 'mp_m_shopkeep_01',  scenario = 'WORLD_HUMAN_STAND_IMPATIENT', blip = 93,  label = 'Loja de Bebidas' },
    hardware   = { name = 'Loja de Ferramentas',  ped = 'mp_m_waremech_01',  scenario = 'WORLD_HUMAN_STAND_IMPATIENT', blip = 402, label = 'Loja de Ferramentas' },
    ammunation = { name = 'Ammu-Nation',          ped = 's_m_y_ammucity_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT', blip = 110, label = 'Ammu-Nation' },
}

local function Shop(kind, coords, heading)
    local k = Kinds[kind]
    local items = {}
    for i, item in ipairs(Catalog[kind]) do items[i] = item end
    return {
        name = k.name,
        coords = coords,
        PedModel = k.ped,
        PedHeading = heading,
        PedScenario = k.scenario,
        Blipname = k.label,
        BlipSprite = k.blip,
        BlipColor = 69,
        items = items,
    }
end

-- Arsenal da polícia (noir_police). Preço 0, sem porte de arma: quem controla é a
-- restrição por job, o DutyRequired (só em serviço) e o maxHeld (limite de posse,
-- porque com item de graça o maxQty por carrinho não segura quem repete o checkout).
-- `serial` com até 3 letras: com mais, o ox_inventory usa o texto como serial inteiro.
local function Armory(department, prefix)
    local registered = { police = 'LSPD', bcso = 'BCSO', sasp = 'SASP' }
    local function weapon(name, label, grade)
        return { name = name, label = label, price = 0, image = name .. '.png', maxQty = 1, maxHeld = 1, grade = grade,
            category = 'Armas', metadata = { registered = registered[department] or department, serial = prefix } }
    end
    return {
        weapon('WEAPON_STUNGUN', 'Taser', 0),
        weapon('WEAPON_NIGHTSTICK', 'Cassetete', 0),
        weapon('WEAPON_FLASHLIGHT', 'Lanterna', 0),
        weapon('WEAPON_COMBATPISTOL', 'Pistola', 0),
        weapon('WEAPON_PUMPSHOTGUN', 'Escopeta', 2),
        weapon('WEAPON_CARBINERIFLE', 'Carabina', 3),
        { name = 'ammo-9', label = 'Munição 9mm', price = 0, image = 'ammo-9.png', maxQty = 120, maxHeld = 120, grade = 0, category = 'Munição' },
        { name = 'ammo-shotgun', label = 'Munição calibre 12', price = 0, image = 'ammo-shotgun.png', maxQty = 30, maxHeld = 30, grade = 2, category = 'Munição' },
        { name = 'ammo-rifle', label = 'Munição 5.56', price = 0, image = 'ammo-rifle.png', maxQty = 120, maxHeld = 120, grade = 3, category = 'Munição' },
        { name = 'handcuffs', label = 'Algemas', price = 0, image = 'handcuffs.png', maxQty = 3, maxHeld = 3, grade = 0, category = 'Equipamento' },
        { name = 'handcuffkey', label = 'Chave de algema', price = 0, image = 'handcuffkey.png', maxQty = 1, maxHeld = 1, grade = 0, category = 'Equipamento' },
        { name = 'zipties', label = 'Zip tie', price = 0, image = 'zipties.png', maxQty = 5, maxHeld = 5, grade = 0, category = 'Equipamento' },
        { name = 'cutters', label = 'Alicate de corte', price = 0, image = 'wirecutter.png', maxQty = 1, maxHeld = 1, grade = 0, category = 'Equipamento' },
        { name = 'evidence_case', label = 'Bolsa de evidências', price = 0, image = 'case_1.png', maxQty = 1, maxHeld = 1, grade = 0, category = 'Equipamento' },
        { name = 'seized_box', label = 'Caixa de apreensão', price = 0, image = 'evidence.png', maxQty = 2, maxHeld = 2, grade = 0, category = 'Equipamento' },
        { name = 'spikestrip', label = 'Spike strip', price = 0, image = 'spikestrip.png', maxQty = 4, maxHeld = 4, grade = 1, category = 'Equipamento' },
        { name = 'shield', label = 'Escudo balístico', price = 0, image = 'shield.png', maxQty = 1, maxHeld = 1, grade = 2, category = 'Equipamento' },
    }
end

local function ArmoryShop(label, departments, coords, heading)
    return {
        name = label,
        coords = coords,
        PedModel = 's_m_y_cop_01',
        PedHeading = heading,
        PedScenario = 'WORLD_HUMAN_CLIPBOARD',
        Blipname = nil,
        items = Armory(departments[1], ({ police = 'POL', bcso = 'BCS', sasp = 'SAS' })[departments[1]]),
        JobRestriction = departments,
        DutyRequired = true,
    }
end

-- Mesmas lojas que o ox_inventory tinha em data/shops.lua (General, Liquor, YouTool, Ammunation).
Config.Shops = {
    ['247_davis']          = Shop('general', vector3(24.47, -1346.62, 28.5), 271.66),
    ['247_pacificbluffs']  = Shop('general', vector3(-3039.54, 584.38, 6.91), 17.27),
    ['247_banhamcanyon']   = Shop('general', vector3(-3242.97, 1000.01, 11.83), 357.57),
    ['247_paletobay']      = Shop('general', vector3(1728.07, 6415.63, 34.04), 242.95),
    ['247_sandyshores']    = Shop('general', vector3(1959.82, 3740.48, 31.34), 301.57),
    ['247_harmony']        = Shop('general', vector3(549.13, 2670.85, 41.16), 99.39),
    ['247_grapeseed']      = Shop('general', vector3(2677.47, 3279.76, 54.24), 335.08),
    ['247_tataviam']       = Shop('general', vector3(2556.66, 380.84, 107.62), 356.67),
    ['247_eastvinewood']   = Shop('general', vector3(372.66, 326.98, 102.57), 253.73),
    ['ltd_northsandyshores'] = Shop('general', vector3(1697.87, 4922.96, 41.06), 324.71),

    ['robs_littleseoul']   = Shop('liquor', vector3(-1221.58, -908.15, 11.33), 35.49),
    ['robs_westvinewood']  = Shop('liquor', vector3(-1486.59, -377.68, 39.16), 139.51),
    ['robs_chumash']       = Shop('liquor', vector3(-2966.39, 391.42, 14.04), 87.48),
    ['robs_grandsenora']   = Shop('liquor', vector3(1165.17, 2710.88, 37.16), 179.43),
    ['robs_mirrorpark']    = Shop('liquor', vector3(1134.2, -982.91, 45.42), 277.24),

    ['hardware_grapeseed'] = Shop('hardware', vector3(2747.71, 3472.85, 54.67), 255.08),

    ['ammu_vespucci']      = Shop('ammunation', vector3(-661.96, -933.53, 20.83), 177.05),
    ['ammu_cypressflats']  = Shop('ammunation', vector3(809.68, -2159.13, 28.62), 1.43),
    ['ammu_sandyshores']   = Shop('ammunation', vector3(1692.67, 3761.38, 33.71), 227.65),
    ['ammu_paletobay']     = Shop('ammunation', vector3(-331.23, 6085.37, 30.45), 228.02),
    ['ammu_pillboxhill']   = Shop('ammunation', vector3(253.63, -51.02, 68.94), 72.91),
    ['ammu_littleseoul']   = Shop('ammunation', vector3(23.0, -1105.67, 28.8), 162.91),
    ['ammu_tataviam']      = Shop('ammunation', vector3(2567.48, 292.59, 107.73), 349.68),
    ['ammu_chiliad']       = Shop('ammunation', vector3(-1118.59, 2700.05, 17.55), 221.89),
    ['ammu_lamesa']        = Shop('ammunation', vector3(841.92, -1035.32, 27.19), 1.56),

    -- Arsenais (noir_police). Paleto: conferir a posição em jogo.
    -- Um arsenal por departamento: é o que põe o registro e o prefixo do serial certos na arma.
    ['armory_mrpd']        = ArmoryShop('Arsenal LSPD - Mission Row', { 'police' }, vector3(451.51, -979.44, 30.68), 90.0),
    ['armory_mrpd_sasp']   = ArmoryShop('Arsenal SASP - Mission Row', { 'sasp' }, vector3(451.51, -981.2, 30.68), 90.0),
    ['armory_paleto']      = ArmoryShop('Arsenal - Paleto Bay', { 'bcso' }, vector3(-447.14, 6015.84, 31.72), 225.0),
}

-- Raio (m) em que o NPC da loja existe no cliente; fora dele o ped é apagado.
Config.PedSpawnDistance = 40.0

-- Distância máxima (m) entre o jogador e o ponto da loja para o servidor aceitar a compra.
Config.MaxCheckoutDistance = 5.0

-- Formas de pagamento aceitas no checkout (tipos de dinheiro do qbx_core).
Config.PaymentTypes = { cash = true, bank = true }

Config.Notify = function(msg, type, title)
    lib.notify({ title = title or 'Loja', description = msg, type = type })
end

function _U(key, ...)
    if Locales and Locales[Config.Locale] and Locales[Config.Locale][key] then
        return string.format(Locales[Config.Locale][key], ...)
    end
    return "Locale error: " .. key
end
