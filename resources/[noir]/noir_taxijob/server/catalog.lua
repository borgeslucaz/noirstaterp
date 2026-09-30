---Catálogo editável do táxi: pontos de coleta/destino, carros da central, níveis, a Central e os
---ajustes de tarifa, chamada e pagamento. Mora no banco (taxijob_*); no primeiro start é
---preenchido com o que está no config.lua. Cada gravação reaplica tudo em Config/ServerConfig
---(as tabelas são mexidas no lugar, então os `local D = Config.Depot` dos módulos continuam
---valendo) e publica para os clients o que eles usam.

Catalog = { ready = false }

local STATE_KEY = 'noir_taxijob:catalog'

-- Regiões de Config.Points: o sorteio por classe (zoneWeights da SUV) usa estes nomes.
Catalog.REGIONS = {
    { key = 'downtown', label = 'Los Santos' },
    { key = 'sandy shores', label = 'Sandy Shores' },
    { key = 'paleto bay', label = 'Paleto Bay' },
}
local REGION = {}
for _, r in ipairs(Catalog.REGIONS) do REGION[r.key] = true end

local points = {}   ---@type table<integer, { id: integer, region: string, x: number, y: number, z: number, w: number, enabled: boolean }>
local vehicles = {} ---@type table[] na ordem da central
local settings = {} ---@type { levels: table[], depot: table, meter: table, dispatch: table, payout: table }

-- Campos numéricos editáveis de cada ajuste, com a faixa aceita.
local NUMERIC = {
    meter = {
        StartingFare = { 0, 1000 }, PricePerKm = { 0, 1000 }, MaxFare = { 10, 100000 },
    },
    dispatch = {
        OfferTimeout = { 3000, 60000 }, MinDelay = { 1000, 600000 }, MaxDelay = { 1000, 600000 },
        MinPickupDistance = { 0, 10000 }, IdealPickupDistance = { 0, 10000 }, MaxPickupDistance = { 50, 10000 },
        MinTripDistance = { 0, 20000 }, MaxTripDistance = { 100, 20000 },
    },
    payout = {
        SatisfiedTipPercent = { 0, 100 }, NeutralMultiplier = { 0, 2 }, UnhappyMultiplier = { 0, 2 }, CalmBonusPercent = { 0, 300 },
    },
}

local function log(fmt, ...)
    print(('[noir_taxijob] ' .. fmt):format(...))
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function inRange(value, min, max)
    return finite(value) and value >= min and value <= max
end

---{x,y,z,w} dentro do mapa.
local function point4(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z, w = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.w) or 0.0
    if not (inRange(x, -8000, 8000) and inRange(y, -8000, 10000) and inRange(z, -200, 2000) and finite(w)) then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (w % 360) + 0.0 }
end

local function text(value, max)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' or #value > max then return nil end
    return value
end

-- ───────────────────────── banco ─────────────────────────

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS taxijob_points (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        data LONGTEXT NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    )]],
    [[CREATE TABLE IF NOT EXISTS taxijob_vehicles (
        id VARCHAR(24) NOT NULL,
        sort INT NOT NULL DEFAULT 0,
        data LONGTEXT NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    )]],
    [[CREATE TABLE IF NOT EXISTS taxijob_settings (
        `key` VARCHAR(32) NOT NULL,
        data LONGTEXT NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`key`)
    )]],
    [[CREATE TABLE IF NOT EXISTS taxijob_editor_log (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        citizenid VARCHAR(50) NULL,
        player_name VARCHAR(100) NULL,
        action VARCHAR(16) NOT NULL,
        entity VARCHAR(16) NOT NULL,
        entity_id VARCHAR(32) NOT NULL,
        data LONGTEXT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        INDEX idx_taxijob_editor_log_entity (entity, entity_id, created_at)
    )]],
}

local function exec(query, params)
    local ok, result = pcall(MySQL.query.await, query, params or {})
    if not ok then log('catálogo: falha no banco: %s', tostring(result)) end
    return ok, result
end

function Catalog.log(citizenId, playerName, action, entity, entityId, data)
    exec('INSERT INTO taxijob_editor_log (citizenid, player_name, action, entity, entity_id, data) VALUES (?, ?, ?, ?, ?, ?)',
        { citizenId, playerName, action, entity, tostring(entityId), data })
end

-- ───────────────────────── aplicar no runtime ─────────────────────────

local function vec4Of(p) return vec4(p.x, p.y, p.z, p.w) end

---Reaplica o catálogo em Config/ServerConfig/Progression e publica para os clients.
local function apply()
    -- Pontos: só os ativos, por região e id (ordem determinística do PointList).
    local byRegion = {}
    for _, r in ipairs(Catalog.REGIONS) do byRegion[r.key] = {} end
    local ids = {}
    for id in pairs(points) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local p = points[id]
        if p.enabled and byRegion[p.region] then byRegion[p.region][#byRegion[p.region] + 1] = p end
    end
    for key in pairs(Config.Points) do Config.Points[key] = nil end
    for i = #Config.PointList, 1, -1 do Config.PointList[i] = nil end
    local regionKeys = {}
    for key, list in pairs(byRegion) do
        Config.Points[key] = {}
        for _, p in ipairs(list) do Config.Points[key][#Config.Points[key] + 1] = vec4Of(p) end
        regionKeys[#regionKeys + 1] = key
    end
    table.sort(regionKeys)
    for _, key in ipairs(regionKeys) do
        for _, p in ipairs(byRegion[key]) do
            Config.PointList[#Config.PointList + 1] = { zone = key, coords = vec3(p.x, p.y, p.z), heading = p.w, id = p.id }
        end
    end

    -- Carros: a lista inteira (inativos aparecem como indisponíveis na central).
    for i = #Config.RentalVehicles, 1, -1 do Config.RentalVehicles[i] = nil end
    for i = #Config.AllowedVehicles, 1, -1 do Config.AllowedVehicles[i] = nil end
    for _, v in ipairs(vehicles) do
        Config.RentalVehicles[#Config.RentalVehicles + 1] = v
        Config.AllowedVehicles[#Config.AllowedVehicles + 1] = v.model
    end

    local depot = settings.depot
    local D = Config.Depot
    D.coords = vec4Of(depot.ped)
    D.pedModel = depot.pedModel
    D.interactDistance = depot.interactDistance
    D.returnRadius = depot.returnRadius
    D.spawnPoints = {}
    for _, p in ipairs(depot.spawnPoints) do D.spawnPoints[#D.spawnPoints + 1] = vec4Of(p) end
    D.blip = { sprite = depot.blip.sprite, color = depot.blip.color, scale = depot.blip.scale, label = depot.blip.label }

    for key, target in pairs({ meter = Config.Meter, dispatch = Config.Dispatch, payout = Config.Payout }) do
        for field, value in pairs(settings[key]) do target[field] = value end
    end

    Progression.setLevels(settings.levels)

    GlobalState[STATE_KEY] = {
        vehicles = vehicles,
        allowed = Config.AllowedVehicles,
        depot = depot,
        offerTimeout = Config.Dispatch.OfferTimeout,
    }
end

---Mods e extras têm índice numérico esparso (10 e 48; 5 a 11): em JSON viram lista com buracos.
---Grava com chave de texto; o client converte de volta ao aplicar.
local function keyed(tbl)
    if type(tbl) ~= 'table' then return nil end
    local out = {}
    for k, v in pairs(tbl) do
        local key, value = tonumber(k), tonumber(v)
        if key and value then out[tostring(math.tointeger(key) or key)] = value end
    end
    return out
end

---@return table|nil|false appearance (false = inválida)
local function sanitizeAppearance(appearance)
    if appearance == nil or appearance == json.null then return nil end
    if type(appearance) ~= 'table' then return false end
    local copy = json.decode(json.encode(appearance) or 'null')
    if type(copy) ~= 'table' then return false end
    if copy.mods then copy.mods = keyed(copy.mods) end
    if type(copy.props) == 'table' and copy.props.extras then copy.props.extras = keyed(copy.props.extras) end
    if copy.extras then
        local list = {}
        for _, id in pairs(copy.extras) do if tonumber(id) then list[#list + 1] = tonumber(id) end end
        copy.extras = list
    end
    local encoded = json.encode(copy)
    if not encoded or #encoded > 6000 then return false end
    return copy
end

-- ───────────────────────── semente (config.lua) ─────────────────────────

local function seedFromConfig()
    local seeded = { points = {}, vehicles = {} }
    for region, list in pairs(Config.Points) do
        for _, p in ipairs(list) do
            seeded.points[#seeded.points + 1] = { region = region, x = p.x, y = p.y, z = p.z, w = p.w, enabled = true }
        end
    end
    table.sort(seeded.points, function(a, b)
        if a.region ~= b.region then return a.region < b.region end
        return (a.x + a.y) < (b.x + b.y)
    end)
    for _, v in ipairs(Config.RentalVehicles) do
        seeded.vehicles[#seeded.vehicles + 1] = {
            id = v.id, model = v.model, label = v.label, class = v.class or 'standard', requiredLevel = v.requiredLevel or 1,
            rentalFee = v.rentalFee or 0, image = v.image or '', description = v.description or '', enabled = v.enabled ~= false,
            appearance = sanitizeAppearance(v.appearance) or nil,
        }
    end
    local D = Config.Depot
    local spawns = {}
    for _, p in ipairs(D.spawnPoints) do spawns[#spawns + 1] = { x = p.x, y = p.y, z = p.z, w = p.w } end
    local levels = {}
    for _, l in ipairs(ServerConfig.Progression.Levels) do levels[#levels + 1] = { level = l.level, min = l.min, label = l.label } end
    local pick = function(source, group)
        local out = {}
        for field in pairs(NUMERIC[group]) do out[field] = source[field] end
        return out
    end
    seeded.settings = {
        levels = levels,
        depot = {
            ped = { x = D.coords.x, y = D.coords.y, z = D.coords.z, w = D.coords.w }, pedModel = D.pedModel,
            interactDistance = D.interactDistance, returnRadius = D.returnRadius, spawnPoints = spawns,
            blip = { sprite = D.blip.sprite, color = D.blip.color, scale = D.blip.scale, label = D.blip.label },
        },
        meter = pick(Config.Meter, 'meter'),
        dispatch = pick(Config.Dispatch, 'dispatch'),
        payout = pick(Config.Payout, 'payout'),
    }
    return seeded
end

local function writeSetting(key, value)
    return exec('INSERT INTO taxijob_settings (`key`, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { key, json.encode(value) })
end

local function writeVehicle(v, sort)
    return exec('INSERT INTO taxijob_vehicles (id, sort, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE sort = VALUES(sort), data = VALUES(data)',
        { v.id, sort, json.encode(v) })
end

local function load()
    local ok, rows = exec('SELECT `key`, data FROM taxijob_settings')
    if not ok then return false end
    if #rows == 0 then
        local seeded = seedFromConfig()
        for _, p in ipairs(seeded.points) do
            exec('INSERT INTO taxijob_points (data) VALUES (?)', { json.encode(p) })
        end
        for i, v in ipairs(seeded.vehicles) do writeVehicle(v, i) end
        for key, value in pairs(seeded.settings) do writeSetting(key, value) end
        log('catálogo: banco preenchido com o config.lua (%d pontos, %d carros)', #seeded.points, #seeded.vehicles)
        ok, rows = exec('SELECT `key`, data FROM taxijob_settings')
        if not ok then return false end
    end

    local fallback = seedFromConfig().settings
    settings = {}
    for _, row in ipairs(rows) do settings[row.key] = json.decode(row.data) end
    for key, value in pairs(fallback) do
        if settings[key] == nil then settings[key] = value end
    end

    local okP, pointRows = exec('SELECT id, data FROM taxijob_points ORDER BY id')
    if not okP then return false end
    points = {}
    for _, row in ipairs(pointRows) do
        local p = json.decode(row.data) or {}
        p.id = row.id
        points[row.id] = p
    end

    local okV, vehicleRows = exec('SELECT id, data FROM taxijob_vehicles ORDER BY sort, id')
    if not okV then return false end
    vehicles = {}
    for _, row in ipairs(vehicleRows) do vehicles[#vehicles + 1] = json.decode(row.data) end
    return true
end

MySQL.ready(function()
    for _, stmt in ipairs(SCHEMA) do
        if not exec(stmt) then return end
    end
    if not load() then return end
    apply()
    Catalog.ready = true
    log('catálogo: %d pontos, %d carros, %d níveis', #Config.PointList, #vehicles, #settings.levels)
end)

-- ───────────────────────── leitura para o editor ─────────────────────────

function Catalog.adminView()
    local list = {}
    for _, p in pairs(points) do list[#list + 1] = p end
    table.sort(list, function(a, b) return a.id < b.id end)
    local classes = {}
    for key, class in pairs(Config.VehicleClasses) do classes[#classes + 1] = { key = key, label = class.label or key } end
    table.sort(classes, function(a, b) return a.key < b.key end)
    return {
        regions = Catalog.REGIONS,
        classes = classes,
        points = list,
        vehicles = vehicles,
        levels = settings.levels,
        depot = settings.depot,
        settings = { meter = settings.meter, dispatch = settings.dispatch, payout = settings.payout },
    }
end

function Catalog.point(id) return points[id] end
function Catalog.depot() return settings.depot end

-- ───────────────────────── gravação ─────────────────────────

---@return integer? id
---@return string? code
function Catalog.savePoint(id, data)
    if type(data) ~= 'table' then return nil, 'invalid_payload' end
    if id and not points[id] then return nil, 'unknown_point' end
    if not REGION[data.region] then return nil, 'invalid_region' end
    local p = point4(data)
    if not p then return nil, 'invalid_point' end
    local record = { region = data.region, x = p.x, y = p.y, z = p.z, w = p.w, enabled = data.enabled ~= false }
    if id then
        if not exec('UPDATE taxijob_points SET data = ? WHERE id = ?', { json.encode(record), id }) then return nil, 'storage_failed' end
    else
        local ok, newId = pcall(MySQL.insert.await, 'INSERT INTO taxijob_points (data) VALUES (?)', { json.encode(record) })
        if not ok or not newId then return nil, 'storage_failed' end
        id = newId
    end
    record.id = id
    points[id] = record
    apply()
    return id
end

function Catalog.deletePoint(id)
    if not points[id] then return false, 'unknown_point' end
    if not exec('DELETE FROM taxijob_points WHERE id = ?', { id }) then return false, 'storage_failed' end
    points[id] = nil
    apply()
    return true
end


---@return string? id
---@return string? code
function Catalog.saveVehicle(isNew, data)
    if type(data) ~= 'table' then return nil, 'invalid_payload' end
    local id = type(data.id) == 'string' and data.id:lower() or nil
    if not id or not id:match('^[a-z0-9_]+$') or #id > 24 then return nil, 'invalid_id' end
    local index
    for i, v in ipairs(vehicles) do if v.id == id then index = i end end
    if isNew and index then return nil, 'vehicle_exists' end
    if not isNew and not index then return nil, 'unknown_vehicle' end
    local model = type(data.model) == 'string' and data.model:lower() or nil
    if not model or not model:match('^[a-z0-9_]+$') or #model > 32 then return nil, 'invalid_model' end
    local label = text(data.label, 32)
    if not label then return nil, 'invalid_label' end
    if type(data.class) ~= 'string' or not Config.VehicleClasses[data.class] then return nil, 'invalid_class' end
    local level = math.tointeger(data.requiredLevel)
    if not level or level < 1 or level > #settings.levels then return nil, 'invalid_level' end
    local fee = math.tointeger(data.rentalFee)
    if not fee or fee < 0 or fee > 100000 then return nil, 'invalid_fee' end
    local image = data.image == '' and '' or text(data.image, 96)
    if image == nil or (image ~= '' and not image:match('^img/[%w_%-%./]+%.[%a]+$')) then return nil, 'invalid_image' end
    local description = data.description == '' and '' or text(data.description, 160)
    if description == nil then return nil, 'invalid_description' end
    local appearance = sanitizeAppearance(data.appearance)
    if appearance == false then return nil, 'invalid_appearance' end

    local record = {
        id = id, model = model, label = label, class = data.class, requiredLevel = level, rentalFee = fee,
        image = image, description = description, enabled = data.enabled ~= false, appearance = appearance,
    }
    local sort = index or (#vehicles + 1)
    if not writeVehicle(record, sort) then return nil, 'storage_failed' end
    vehicles[sort] = record
    apply()
    return id
end

function Catalog.deleteVehicle(id)
    for i, v in ipairs(vehicles) do
        if v.id == id then
            if #vehicles == 1 then return false, 'last_vehicle' end
            if not exec('DELETE FROM taxijob_vehicles WHERE id = ?', { id }) then return false, 'storage_failed' end
            table.remove(vehicles, i)
            for sort, other in ipairs(vehicles) do writeVehicle(other, sort) end
            apply()
            return true
        end
    end
    return false, 'unknown_vehicle'
end

---Sobe (-1) ou desce (+1) o carro na lista da central.
function Catalog.moveVehicle(id, delta)
    for i, v in ipairs(vehicles) do
        if v.id == id then
            local j = i + delta
            if j < 1 or j > #vehicles then return true end
            vehicles[i], vehicles[j] = vehicles[j], vehicles[i]
            writeVehicle(vehicles[i], i)
            writeVehicle(vehicles[j], j)
            apply()
            return true
        end
    end
    return false, 'unknown_vehicle'
end

function Catalog.saveLevels(list)
    if type(list) ~= 'table' or #list < 1 or #list > 30 then return false, 'invalid_levels' end
    local levels = {}
    for i, l in ipairs(list) do
        local min, label = math.tointeger(type(l) == 'table' and l.min), text(type(l) == 'table' and l.label, 32)
        if not min or min < 0 or min > 100000000 or not label then return false, 'invalid_levels' end
        levels[i] = { level = i, min = min, label = label }
    end
    if levels[1].min ~= 0 then return false, 'first_level_zero' end
    for i = 2, #levels do
        if levels[i].min <= levels[i - 1].min then return false, 'levels_order' end
    end
    for _, v in ipairs(vehicles) do
        if v.requiredLevel > #levels then return false, 'vehicle_level_missing' end
    end
    if not writeSetting('levels', levels) then return false, 'storage_failed' end
    settings.levels = levels
    apply()
    return true
end

function Catalog.saveDepot(data)
    if type(data) ~= 'table' then return false, 'invalid_payload' end
    local ped = point4(data.ped)
    local pedModel = type(data.pedModel) == 'string' and data.pedModel:lower() or nil
    if not ped or not pedModel or not pedModel:match('^[a-z0-9_]+$') or #pedModel > 32 then return false, 'invalid_depot' end
    if not inRange(data.interactDistance, 2, 50) or not inRange(data.returnRadius, 5, 150) then return false, 'invalid_depot' end
    if type(data.spawnPoints) ~= 'table' or #data.spawnPoints < 1 or #data.spawnPoints > 12 then return false, 'invalid_spawns' end
    local spawns = {}
    for i, p in ipairs(data.spawnPoints) do
        spawns[i] = point4(p)
        if not spawns[i] then return false, 'invalid_spawns' end
    end
    local blip = type(data.blip) == 'table' and data.blip or {}
    local sprite, color = math.tointeger(blip.sprite), math.tointeger(blip.color)
    local label = text(blip.label, 48)
    if not sprite or sprite < 0 or sprite > 900 or not color or color < 0 or color > 85 or not inRange(blip.scale, 0.3, 2.0) or not label then
        return false, 'invalid_blip'
    end
    local depot = {
        ped = ped, pedModel = pedModel, interactDistance = data.interactDistance + 0.0, returnRadius = data.returnRadius + 0.0,
        spawnPoints = spawns, blip = { sprite = sprite, color = color, scale = blip.scale + 0.0, label = label },
    }
    if not writeSetting('depot', depot) then return false, 'storage_failed' end
    settings.depot = depot
    apply()
    return true
end

function Catalog.saveSettings(data)
    if type(data) ~= 'table' then return false, 'invalid_payload' end
    local values = {}
    for group, fields in pairs(NUMERIC) do
        local source = type(data[group]) == 'table' and data[group] or {}
        values[group] = {}
        for field, range in pairs(fields) do
            local value = source[field]
            if not inRange(value, range[1], range[2]) then return false, 'invalid_' .. group end
            values[group][field] = value
        end
    end
    local d = values.dispatch
    if d.MaxDelay < d.MinDelay then return false, 'invalid_dispatch' end
    if not (d.MinPickupDistance <= d.IdealPickupDistance and d.IdealPickupDistance <= d.MaxPickupDistance) then return false, 'invalid_dispatch' end
    if d.MaxTripDistance <= d.MinTripDistance then return false, 'invalid_dispatch' end
    for group, value in pairs(values) do
        if not writeSetting(group, value) then return false, 'storage_failed' end
    end
    for group, value in pairs(values) do settings[group] = value end
    apply()
    return true
end
