---Regras puras do catálogo: validação do que o editor manda, contas de distância e tempo,
---nível pelo XP e sorteio de ponto na área de espera. Sem native: roda no servidor, no
---client e nos testes (`lua5.4 tests/unit/rules_spec.lua`).

local Rules = {}

Rules.LIMITS = {
    name = 48,
    code = 6,
    title = 32,
    label = 32,
    routeId = 32,
    model = 32,
    stopsPerRoute = 40,
    vehiclesPerRoute = 12,
    levels = 30,
    groups = 16,
    passengerModels = 12,
    peakWindows = 6,
    money = 100000,
    xp = 100000,
    capacity = 60,
    level = 99,
    world = 20000.0,
    zoneSide = 40.0,
    zoneHeight = 10.0,
}

-- Primitivas --------------------------------------------------------------------------

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@return number?
local function number(value, min, max)
    if not isFiniteNumber(value) then return nil end
    if value < min or value > max then return nil end
    return value
end

---@return integer?
local function integer(value, min, max)
    local n = number(value, min, max)
    if not n then return nil end
    return math.floor(n)
end

---Algum campo da lista ficou nil (fora da faixa)? `pairs` pula nil, por isso a lista.
local function missing(tbl, keys)
    for _, key in ipairs(keys) do
        if tbl[key] == nil then return true end
    end
    return false
end

local function round(value, places)
    local factor = 10 ^ (places or 2)
    return math.floor(value * factor + 0.5) / factor
end

---Texto limpo: sem caractere de controle nem marcação, cortado no limite.
---@return string?
local function text(value, maxLength)
    if type(value) ~= 'string' then return nil end
    local cleaned = value:gsub('[%c<>]', ''):match('^%s*(.-)%s*$')
    if cleaned == '' or #cleaned > maxLength then return nil end
    return cleaned
end

---@return string?
local function modelName(value)
    if type(value) ~= 'string' or #value < 2 or #value > Rules.LIMITS.model then return nil end
    local lowered = value:lower()
    if not lowered:match('^[%w_]+$') then return nil end
    return lowered
end

---{x, y, z, w} dentro do mundo. `w` é o heading, normalizado para 0–360.
---@return { x: number, y: number, z: number, w: number }?
function Rules.point(value, withHeading)
    if type(value) ~= 'table' then return nil end
    local limit = Rules.LIMITS.world
    local x, y, z = number(value.x, -limit, limit), number(value.y, -limit, limit), number(value.z, -500.0, 3000.0)
    if not x or not y or not z then return nil end
    local result = { x = round(x), y = round(y), z = round(z) }
    if withHeading then
        local w = number(value.w, -3600.0, 3600.0)
        if not w then return nil end
        result.w = round(w % 360.0)
    end
    return result
end

---Área de espera dos passageiros: caixa girada no plano (centro, comprimento no eixo do
---heading, largura, altura).
---@return table?
function Rules.zone(value)
    if type(value) ~= 'table' then return nil end
    local center = Rules.point(value)
    local length = number(value.length, 0.5, Rules.LIMITS.zoneSide)
    local width = number(value.width, 0.5, Rules.LIMITS.zoneSide)
    local height = number(value.height, 0.5, Rules.LIMITS.zoneHeight)
    local rotation = number(value.rotation, -3600.0, 3600.0)
    if not center or not length or not width or not height or not rotation then return nil end
    center.length, center.width, center.height = round(length), round(width), round(height)
    center.rotation = round(rotation % 360.0)
    return center
end

-- Entidades do editor -----------------------------------------------------------------

---@return table? stop
---@return string? code
function Rules.normalizeStop(input)
    if type(input) ~= 'table' then return nil, 'invalid_payload' end
    local name = text(input.name, Rules.LIMITS.name)
    if not name then return nil, 'invalid_name' end
    local dock = Rules.point(input.dock, true)
    if not dock then return nil, 'invalid_dock' end
    local zone = nil
    if input.zone ~= nil then
        zone = Rules.zone(input.zone)
        if not zone then return nil, 'invalid_zone' end
    end
    return { name = name, dock = dock, zone = zone, enabled = input.enabled ~= false }
end

---@return table? vehicle
---@return string? code
function Rules.normalizeVehicle(input)
    if type(input) ~= 'table' then return nil, 'invalid_payload' end
    local model = modelName(input.model)
    if not model then return nil, 'invalid_model' end
    local label = text(input.label, Rules.LIMITS.label)
    if not label then return nil, 'invalid_name' end
    local capacity = integer(input.capacity, 1, Rules.LIMITS.capacity)
    if not capacity then return nil, 'invalid_capacity' end
    local minLevel = integer(input.minLevel, 1, Rules.LIMITS.level)
    if not minLevel then return nil, 'invalid_level' end
    local doors = {}
    if type(input.doors) == 'table' then
        for _, door in ipairs(input.doors) do
            local index = integer(door, 0, 7)
            if not index then return nil, 'invalid_doors' end
            doors[#doors + 1] = index
            if #doors > 8 then return nil, 'invalid_doors' end
        end
    end
    return { model = model, label = label, capacity = capacity, doors = doors, minLevel = minLevel, enabled = input.enabled ~= false }
end

---Grupos com cargo mínimo: { police = 0 }. Vazio = qualquer jogador.
---@return table<string, integer>?
local function groups(value)
    if value == nil then return {} end
    if type(value) ~= 'table' then return nil end
    local result, count = {}, 0
    for name, grade in pairs(value) do
        local key = type(name) == 'string' and name:lower() or nil
        local minGrade = integer(grade, 0, 20)
        if not key or not key:match('^[%w_]+$') or #key > 32 or not minGrade then return nil end
        result[key] = minGrade
        count = count + 1
        if count > Rules.LIMITS.groups then return nil end
    end
    return result
end

---@param input table
---@param known { stops: table<integer, table>, vehicles: table<string, table> }
---@return table? route
---@return string? code
function Rules.normalizeRoute(input, known)
    if type(input) ~= 'table' then return nil, 'invalid_payload' end
    local code = text(input.code, Rules.LIMITS.code)
    if not code or not code:match('^[%w]+$') then return nil, 'invalid_code' end
    local name = text(input.name, Rules.LIMITS.name)
    if not name then return nil, 'invalid_name' end
    local minLevel = integer(input.minLevel, 1, Rules.LIMITS.level)
    if not minLevel then return nil, 'invalid_level' end
    local basePay = integer(input.basePay, 0, Rules.LIMITS.money)
    local baseXp = integer(input.baseXp, 0, Rules.LIMITS.xp)
    if not basePay or not baseXp then return nil, 'invalid_reward' end

    if type(input.stops) ~= 'table' or #input.stops < 2 or #input.stops > Rules.LIMITS.stopsPerRoute then
        return nil, 'invalid_stops'
    end
    local stops = {}
    for index, id in ipairs(input.stops) do
        local stopId = integer(id, 1, 2 ^ 31)
        if not stopId or not known.stops[stopId] then return nil, 'unknown_stop' end
        if index > 1 and stops[index - 1] == stopId then return nil, 'repeated_stop' end
        stops[index] = stopId
    end

    if type(input.vehicles) ~= 'table' or #input.vehicles < 1 or #input.vehicles > Rules.LIMITS.vehiclesPerRoute then
        return nil, 'invalid_vehicles'
    end
    local vehicles, seen = {}, {}
    for _, model in ipairs(input.vehicles) do
        local name = modelName(model)
        if not name or not known.vehicles[name] then return nil, 'unknown_vehicle' end
        if not seen[name] then
            seen[name] = true
            vehicles[#vehicles + 1] = name
        end
    end

    local access = groups(type(input.access) == 'table' and input.access.groups or nil)
    if not access then return nil, 'invalid_access' end

    return {
        code = code:upper(),
        name = name,
        minLevel = minLevel,
        basePay = basePay,
        baseXp = baseXp,
        stops = stops,
        vehicles = vehicles,
        access = { groups = access },
        enabled = input.enabled ~= false,
    }
end

---Chave da linha criada no editor: minúsculas, dígitos e _.
---@return string?
function Rules.routeId(value)
    if type(value) ~= 'string' then return nil end
    local id = value:lower():gsub('[^%w_]', '_'):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '')
    if id == '' or #id > Rules.LIMITS.routeId then return nil end
    return id
end

---Níveis em ordem: o 1º começa em 0 e o XP cresce estritamente.
---@return table[]? levels
---@return string? code
function Rules.normalizeLevels(input)
    if type(input) ~= 'table' or #input < 1 or #input > Rules.LIMITS.levels then return nil, 'invalid_levels' end
    local levels = {}
    for index, entry in ipairs(input) do
        if type(entry) ~= 'table' then return nil, 'invalid_levels' end
        local xp = integer(entry.xp, 0, 10000000)
        local title = text(entry.title, Rules.LIMITS.title)
        if not xp or not title then return nil, 'invalid_levels' end
        if index == 1 and xp ~= 0 then return nil, 'first_level_xp' end
        if index > 1 and xp <= levels[index - 1].xp then return nil, 'levels_order' end
        levels[index] = { level = index, xp = xp, title = title }
    end
    return levels
end

---Ajustes gerais. Cada bloco tem faixa própria; o que não vier fica com o valor atual.
---@param input table
---@param current table ajustes atuais (base para o que não mudou)
---@return table? settings
---@return string? code
function Rules.normalizeSettings(input, current)
    if type(input) ~= 'table' or type(current) ~= 'table' then return nil, 'invalid_payload' end
    local result = {}

    local depotIn = type(input.depot) == 'table' and input.depot or current.depot
    local ped = Rules.point(depotIn.ped, true)
    local spawn = Rules.point(depotIn.spawn, true)
    local radius = number(depotIn.radius, 5.0, 100.0)
    local pedModel = modelName(depotIn.pedModel)
    if not ped or not spawn or not radius or not pedModel then return nil, 'invalid_depot' end
    local blipIn = type(depotIn.blip) == 'table' and depotIn.blip or {}
    local blip = {
        enabled = blipIn.enabled ~= false,
        sprite = integer(blipIn.sprite, 0, 900) or 513,
        color = integer(blipIn.color, 0, 85) or 15,
        scale = number(blipIn.scale, 0.3, 2.0) or 0.7,
        label = text(blipIn.label, Rules.LIMITS.name) or 'Central de Transporte',
    }
    result.depot = { ped = ped, pedModel = pedModel, spawn = spawn, radius = radius, blip = blip }

    local stopIn = type(input.stop) == 'table' and input.stop or current.stop
    result.stop = {
        radius = number(stopIn.radius, 3.0, 25.0),
        maxDockSpeedKmh = number(stopIn.maxDockSpeedKmh, 1.0, 30.0),
        maxDoorSpeedKmh = number(stopIn.maxDoorSpeedKmh, 1.0, 30.0),
        serviceTimeoutMs = integer(stopIn.serviceTimeoutMs, 5000, 120000),
        pedExitTimeoutMs = integer(stopIn.pedExitTimeoutMs, 1000, 60000),
        pedEnterTimeoutMs = integer(stopIn.pedEnterTimeoutMs, 1000, 60000),
    }
    if missing(result.stop, { 'radius', 'maxDockSpeedKmh', 'maxDoorSpeedKmh', 'serviceTimeoutMs', 'pedExitTimeoutMs', 'pedEnterTimeoutMs' }) then
        return nil, 'invalid_stop_settings'
    end

    local passengerIn = type(input.passenger) == 'table' and input.passenger or current.passenger
    local minDemand = integer(passengerIn.minDemand, 0, 20)
    local maxDemand = integer(passengerIn.maxDemand, 0, 20)
    if not minDemand or not maxDemand or maxDemand < minDemand then return nil, 'invalid_demand' end
    local models = {}
    if type(passengerIn.models) == 'table' then
        for _, model in ipairs(passengerIn.models) do
            local name = modelName(model)
            if not name then return nil, 'invalid_model' end
            models[#models + 1] = name
            if #models > Rules.LIMITS.passengerModels then return nil, 'invalid_model' end
        end
    end
    if #models == 0 then return nil, 'invalid_model' end
    result.passenger = {
        spawnDistance = number(passengerIn.spawnDistance, 30.0, 400.0),
        minDemand = minDemand,
        maxDemand = maxDemand,
        exitDespawnMs = integer(passengerIn.exitDespawnMs, 1000, 120000),
        models = models,
    }
    if missing(result.passenger, { 'spawnDistance', 'exitDespawnMs' }) then return nil, 'invalid_passenger_settings' end

    local payoutIn = type(input.payout) == 'table' and input.payout or current.payout
    result.payout = {
        perPassenger = integer(payoutIn.perPassenger, 0, 1000),
        passengerCap = number(payoutIn.passengerCap, 0.0, 2.0),
        scoreCap = number(payoutIn.scoreCap, 0.0, 2.0),
        xpPerPassenger = integer(payoutIn.xpPerPassenger, 0, 1000),
        xpCap = number(payoutIn.xpCap, 0.0, 2.0),
    }
    if missing(result.payout, { 'perPassenger', 'passengerCap', 'scoreCap', 'xpPerPassenger', 'xpCap' }) then
        return nil, 'invalid_payout'
    end

    local timingIn = type(input.timing) == 'table' and input.timing or current.timing
    result.timing = {
        secondsPerKm = number(timingIn.secondsPerKm, 20.0, 600.0),
        secondsPerStop = number(timingIn.secondsPerStop, 0.0, 300.0),
        tolerance = number(timingIn.tolerance, 1.0, 3.0),
        minFraction = number(timingIn.minFraction, 0.0, 0.9),
        -- Linha sem traçado pela estrada: linha reta × fator. Ajuste gravado antes do fator ganha 1,3.
        roadFactor = number(timingIn.roadFactor == nil and Rules.ROAD_FACTOR or timingIn.roadFactor, 1.0, 2.5),
    }
    if missing(result.timing, { 'secondsPerKm', 'secondsPerStop', 'tolerance', 'minFraction', 'roadFactor' }) then return nil, 'invalid_timing' end

    local peakIn = type(input.peak) == 'table' and input.peak or current.peak
    local windows = {}
    if type(peakIn.windows) == 'table' then
        for _, window in ipairs(peakIn.windows) do
            local from = type(window) == 'table' and integer(window.from, 0, 23)
            local to = type(window) == 'table' and integer(window.to, 1, 24)
            if not from or not to or to <= from then return nil, 'invalid_peak' end
            windows[#windows + 1] = { from = from, to = to }
            if #windows > Rules.LIMITS.peakWindows then return nil, 'invalid_peak' end
        end
    end
    local multiplier = number(peakIn.demandMultiplier, 1.0, 4.0)
    if not multiplier then return nil, 'invalid_peak' end
    result.peak = { enabled = peakIn.enabled == true, windows = windows, demandMultiplier = multiplier }

    local failureIn = type(input.vehicleFailure) == 'table' and input.vehicleFailure or current.vehicleFailure
    local engine = number(failureIn.engineHealth, -4000.0, 1000.0)
    if not engine then return nil, 'invalid_payload' end
    result.vehicleFailure = { engineHealth = engine }

    return result
end

-- Contas ------------------------------------------------------------------------------

local function planar(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
Rules.planar = planar

---Distância em linha reta do trajeto: saída do ônibus → paradas em ordem → atendente.
---@param route table
---@param stops table<integer, table>
---@param depot table
---@return number meters
function Rules.routeDistance(route, stops, depot)
    local total, previous = 0.0, depot.spawn
    for _, id in ipairs(route.stops) do
        local stop = stops[id]
        if stop then
            total = total + planar(previous, stop.dock)
            previous = stop.dock
        end
    end
    return total + planar(previous, depot.ped)
end

-- Média estrada/linha reta dos traçados das 10 linhas (2026-09-30: de 1,13 a 1,55).
Rules.ROAD_FACTOR = 1.3

---Distância pela estrada: a do traçado gravado (/onibusrota) ou, sem ele, a linha reta × fator.
---@param straightMeters number
---@param roadMeters? number traçado em dia com as paradas da linha
---@return number meters
function Rules.roadDistance(straightMeters, roadMeters, timing)
    if roadMeters and roadMeters > 0 then return roadMeters end
    return straightMeters * (timing.roadFactor or Rules.ROAD_FACTOR)
end

---Tempo esperado de uma volta (distância pela estrada), na mesma conta usada para calibrar o
---pagamento.
---@return number seconds
function Rules.expectedSeconds(distanceMeters, stopCount, timing)
    return distanceMeters / 1000 * timing.secondsPerKm + stopCount * timing.secondsPerStop
end

---Pontualidade: 100 até o esperado × tolerância; cai em linha reta até 60 no dobro do
---esperado e fica em 60 daí em diante.
---@return number score
function Rules.punctuality(durationSeconds, expectedSeconds, timing)
    if expectedSeconds <= 0 then return 100 end
    local limit = expectedSeconds * timing.tolerance
    if durationSeconds <= limit then return 100 end
    local worst = expectedSeconds * 2
    if worst <= limit then return 60 end
    local ratio = math.min(1, (durationSeconds - limit) / (worst - limit))
    return round(100 - 40 * ratio)
end

---@param levels table[] em ordem de XP
---@return integer level
---@return table entry
function Rules.levelFor(levels, xp)
    local current = levels[1]
    for index = 1, #levels do
        if xp >= levels[index].xp then current = levels[index] else break end
    end
    return current.level, current
end

---Pagamento e XP de uma volta. `quality` multiplica só o XP.
---@return integer pay
---@return integer xp
function Rules.reward(route, payout, finalScore, passengers)
    local quality = finalScore >= 95 and 1.15 or finalScore >= 90 and 1.10 or finalScore >= 80 and 1.0
        or finalScore >= 70 and 0.95 or finalScore >= 60 and 0.85 or 0.75
    local xp = math.floor(route.baseXp * quality + math.min(route.baseXp * payout.xpCap, passengers * payout.xpPerPassenger))
    local pay = math.floor(route.basePay
        + math.min(route.basePay * payout.passengerCap, passengers * payout.perPassenger)
        + math.min(route.basePay * payout.scoreCap, route.basePay * math.max(0, finalScore - 80) / 100))
    return pay, xp
end

---O que cada nível libera, montado das linhas e dos veículos (sem texto solto para
---ficar desatualizado).
---@return table<integer, string[]>
function Rules.unlocksByLevel(routes, vehicles)
    local result = {}
    local function add(level, label)
        result[level] = result[level] or {}
        table.insert(result[level], label)
    end
    local routeList = {}
    for _, route in pairs(routes) do if route.enabled then routeList[#routeList + 1] = route end end
    table.sort(routeList, function(a, b) return a.code < b.code end)
    for _, route in ipairs(routeList) do
        -- "Linha A07 · Aeroporto" vira "A07 Aeroporto"; nome sem "·" entra inteiro.
        add(route.minLevel, route.code .. ' ' .. (route.name:match('·%s*(.+)$') or route.name))
    end
    local vehicleList = {}
    for _, vehicle in pairs(vehicles) do if vehicle.enabled then vehicleList[#vehicleList + 1] = vehicle end end
    table.sort(vehicleList, function(a, b) return a.label < b.label end)
    for _, vehicle in ipairs(vehicleList) do add(vehicle.minLevel, vehicle.label) end
    return result
end

---Ponto sorteado dentro da área (caixa girada). `random` devolve [0, 1).
---@return { x: number, y: number, z: number }
function Rules.randomPointInZone(zone, random)
    local u = (random() - 0.5) * zone.length
    local v = (random() - 0.5) * zone.width
    local angle = math.rad(zone.rotation)
    -- GTA: heading 0 aponta para +Y; o comprimento segue o heading, a largura o lado.
    local forwardX, forwardY = -math.sin(angle), math.cos(angle)
    local rightX, rightY = math.cos(angle), math.sin(angle)
    return { x = zone.x + forwardX * u + rightX * v, y = zone.y + forwardY * u + rightY * v, z = zone.z }
end

---@return boolean
function Rules.pointInZone(zone, point)
    local angle = math.rad(zone.rotation)
    local dx, dy = point.x - zone.x, point.y - zone.y
    local u = dx * -math.sin(angle) + dy * math.cos(angle)
    local v = dx * math.cos(angle) + dy * math.sin(angle)
    return math.abs(u) <= zone.length / 2 and math.abs(v) <= zone.width / 2
        and math.abs(point.z - zone.z) <= zone.height / 2
end

return Rules
