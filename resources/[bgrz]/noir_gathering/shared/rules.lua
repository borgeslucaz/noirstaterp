---Regras puras da rota: validação do que o admin salva, a visão pública que vai para
---os clientes e a escolha do próximo ponto. Nada aqui toca native, evento ou export,
---para poder ser testado em Lua puro e lido pelos dois lados.

local Rules = {}

local MODES = { shift = true, free = true, haul = true }

---@param value any
---@return boolean
function Rules.isFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@return boolean
function Rules.isInteger(value)
    return Rules.isFinite(value) and value % 1 == 0
end

---@param value any
---@param min number
---@param max number
---@return boolean
local function intBetween(value, min, max)
    return Rules.isInteger(value) and value >= min and value <= max
end

---Nome de item, job, gang ou model: o que o provider aceita como chave.
---@param value any
---@param maxLength? integer
---@return boolean
function Rules.isName(value, maxLength)
    return type(value) == 'string' and #value > 0 and #value <= (maxLength or 64)
        and value:match('^[%w_%-]+$') ~= nil
end

local function round(value)
    return math.floor(value * 1000 + 0.5) / 1000
end

---Aceita vector3, `{ x, y, z }` ou `{ [1], [2], [3] }`; devolve tabela simples, que é o
---que sobrevive a json e a GlobalState.
---@param value any
---@return { x: number, y: number, z: number }?
function Rules.normalizeCoords(value)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x, y, z = value.x, value.y, value.z
    if x == nil and kind == 'table' then x, y, z = value[1], value[2], value[3] end
    if not Rules.isFinite(x) or not Rules.isFinite(y) or not Rules.isFinite(z) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return { x = round(x), y = round(y), z = round(z) }
end

---Posição com direção: a do NPC, do veículo, da pilha e do ponto de entrega.
---@param value any
---@return { x: number, y: number, z: number, w: number }?
function Rules.normalizePlacement(value)
    local coords = Rules.normalizeCoords(value)
    if not coords then return nil end
    local w = value.w
    if w == nil and type(value) == 'table' then w = value[4] end
    if w == nil then w = 0 end
    if not Rules.isFinite(w) then return nil end
    coords.w = round(w % 360)
    return coords
end

local function count(map)
    local total = 0
    for _ in pairs(map) do total = total + 1 end
    return total
end

---@param value any
---@param limit integer
---@return { min: integer, max: integer }?
local function normalizeRange(value, limit)
    if type(value) ~= 'table' then return nil end
    local min, max = value.min, value.max
    if not intBetween(min, 0, limit) or not intBetween(max, 0, limit) then return nil end
    if min > max then min, max = max, min end
    return { min = min, max = max }
end

---@param value any
---@return number?
local function normalizeChance(value)
    if not Rules.isFinite(value) or value < 0 or value > 100 then return nil end
    return value
end

---@param input any
---@param limits table
---@param isKnownItem fun(name: string): boolean
---@return table? item
---@return string? errorCode
local function normalizeItem(input, limits, isKnownItem)
    if type(input) ~= 'table' then return nil, 'invalid_item' end

    local item = {}

    if input.label ~= nil and input.label ~= '' then
        if type(input.label) ~= 'string' or #input.label > limits.nameLength then return nil, 'invalid_label' end
        item.label = input.label
    end

    local amount = normalizeRange({ min = input.min, max = input.max }, limits.amount)
    if not amount or amount.max < 1 then return nil, 'invalid_amount' end
    item.min, item.max = amount.min, amount.max

    local time = input.time == nil and limits.collectTime.default or input.time
    if not intBetween(time, limits.collectTime.min, limits.collectTime.max) then return nil, 'invalid_time' end
    item.time = time

    if input.tool ~= nil then
        local tool = input.tool
        if type(tool) ~= 'table' or not Rules.isName(tool.name) or not isKnownItem(tool.name)
            or not intBetween(tool.cost or 0, 0, 100) then
            return nil, 'invalid_tool'
        end
        item.tool = { name = tool.name, cost = tool.cost or 0 }
    end

    if input.stress ~= nil then
        local stress = normalizeRange(input.stress, limits.stress)
        if not stress then return nil, 'invalid_stress' end
        if stress.max > 0 then item.stress = stress end
    end

    item.random = input.random == true
    item.unlimited = input.unlimited == true

    if input.anim ~= nil then
        local anim = input.anim
        if type(anim) ~= 'table' or type(anim.dict) ~= 'string' or #anim.dict == 0 or #anim.dict > 128
            or type(anim.clip) ~= 'string' or #anim.clip == 0 or #anim.clip > 128
            or not intBetween(anim.flag or 1, 0, 65535) then
            return nil, 'invalid_anim'
        end
        item.anim = { dict = anim.dict, clip = anim.clip, flag = anim.flag or 1 }
    end

    if input.police ~= nil then
        local chance = type(input.police) == 'table' and normalizeChance(input.police.chance) or nil
        if not chance then return nil, 'invalid_police' end
        item.police = { chance = chance }
    end

    item.extras = {}
    if input.extras ~= nil then
        if type(input.extras) ~= 'table' or count(input.extras) > limits.extrasPerItem then
            return nil, 'invalid_extras'
        end
        for name, range in pairs(input.extras) do
            if not Rules.isName(name) or not isKnownItem(name) then return nil, 'invalid_extras' end
            local extra = normalizeRange(range, limits.amount)
            if not extra or extra.max < 1 then return nil, 'invalid_extras' end
            item.extras[name] = extra
        end
    end

    item.points = {}
    if input.points ~= nil then
        if type(input.points) ~= 'table' or #input.points > limits.pointsPerItem then
            return nil, 'invalid_points'
        end
        for index = 1, #input.points do
            local point = Rules.normalizeCoords(input.points[index])
            if not point then return nil, 'invalid_points' end
            item.points[index] = point
        end
    end

    return item
end

local function acceptAny() return true end

---O que o servidor conhece e a rota pode citar. Função sozinha é o catálogo de itens;
---o que faltar aceita qualquer nome — é o caso do boot, que não pode derrubar uma rota
---porque um item ou um desbloqueio saiu depois.
---@param catalog table|function|nil
local function catalogOf(catalog)
    if type(catalog) == 'function' then catalog = { item = catalog } end
    catalog = catalog or {}
    return {
        item = catalog.item or acceptAny,
        category = catalog.category or acceptAny,
        unlock = catalog.unlock or acceptAny,
        prop = catalog.prop or acceptAny,
        reputationCap = catalog.reputationCap,
    }
end

---@param value any
---@param range { min: number, max: number, default: number }
---@return number?
local function normalizeRadius(value, range)
    if value == nil then return range.default end
    if not Rules.isFinite(value) or value < range.min or value > range.max then return nil end
    return math.floor(value + 0.5)
end

---Desbloqueio ou nível de reputação que a GANG de quem vai jogar precisa ter.
local function normalizeRequirement(input, known)
    if input == nil then return nil end
    if type(input) ~= 'table' then return nil, 'invalid_requirement' end
    local requirement = {}
    if input.unlock ~= nil and input.unlock ~= '' then
        if not Rules.isName(input.unlock) or not known.unlock(input.unlock) then return nil, 'invalid_requirement' end
        requirement.unlock = input.unlock
    end
    if input.category ~= nil and input.category ~= '' then
        if not Rules.isName(input.category) or not known.category(input.category)
            or not intBetween(input.level, 1, 20) then
            return nil, 'invalid_requirement'
        end
        requirement.category, requirement.level = input.category, input.level
    end
    if next(requirement) == nil then return nil end
    return requirement
end

---Rota de carga: pilha de caixas, quantas caixas, ponto de entrega e o que ela paga.
local function normalizeHaul(input, limits, known)
    if type(input) ~= 'table' then input = {} end
    local haul = {}

    if input.stack ~= nil then
        haul.stack = Rules.normalizePlacement(input.stack)
        if not haul.stack then return nil, 'invalid_stack' end
    end
    haul.prop = input.prop == nil and limits.haul.defaultProp or input.prop
    if not Rules.isName(haul.prop) or not known.prop(haul.prop) then return nil, 'invalid_stack' end

    haul.count = input.count == nil and 1 or input.count
    if not intBetween(haul.count, 1, limits.haul.boxes) then return nil, 'invalid_count' end

    if input.dropoff ~= nil then
        haul.dropoff = Rules.normalizePlacement(input.dropoff)
        if not haul.dropoff then return nil, 'invalid_dropoff' end
    end

    haul.cooldown = input.cooldown == nil and 0 or input.cooldown
    if not intBetween(haul.cooldown, 0, limits.haul.cooldownMinutes) then return nil, 'invalid_cooldown' end

    haul.rewards = {}
    if input.rewards ~= nil then
        if type(input.rewards) ~= 'table' or count(input.rewards) > limits.haul.rewardItems then
            return nil, 'invalid_rewards'
        end
        for name, range in pairs(input.rewards) do
            if not Rules.isName(name) or not known.item(name) then return nil, 'invalid_rewards' end
            local amount = normalizeRange(range, limits.amount)
            if not amount or amount.max < 1 then return nil, 'invalid_rewards' end
            haul.rewards[name] = amount
        end
    end

    if input.category ~= nil and input.category ~= '' then
        if not Rules.isName(input.category) or not known.category(input.category) then
            return nil, 'invalid_category'
        end
        haul.category = input.category
    end

    haul.reputation = input.reputation == nil and 0 or input.reputation
    local cap = known.reputationCap or limits.haul.reputation
    if not Rules.isFinite(haul.reputation) or haul.reputation < 0 or haul.reputation > cap then
        return nil, 'invalid_reputation'
    end
    if haul.reputation > 0 and not haul.category then return nil, 'invalid_reputation' end

    local scout = type(input.scout) == 'table' and input.scout or {}
    local chance = scout.chance == nil and 0 or normalizeChance(scout.chance)
    local radius = normalizeRadius(scout.radius, limits.alertRadius)
    if not chance or not radius then return nil, 'invalid_scout' end
    haul.scout = { enabled = scout.enabled == true, chance = chance, radius = radius }
    if haul.scout.enabled and not haul.category then return nil, 'invalid_scout' end

    return haul
end

---Valida e normaliza a rota que o admin mandou. Tudo que não está no formato vira
---recusa com código, e não "melhor esforço": o que é salvo é exatamente o que roda.
---@param input any
---@param limits table `config.shared.limits`
---@param catalog table|fun(name: string): boolean catálogo (ver `catalogOf`) ou só o de itens
---@return table? route
---@return string? errorCode
function Rules.normalizeRoute(input, limits, catalog)
    if type(input) ~= 'table' then return nil, 'invalid_route' end
    local known = catalogOf(catalog)
    local isKnownItem = known.item

    local route = {}

    local name = type(input.name) == 'string' and input.name:match('^%s*(.-)%s*$') or nil
    if not name or #name == 0 or #name > limits.nameLength then return nil, 'invalid_name' end
    route.name = name

    route.mode = input.mode == nil and 'shift' or input.mode
    if not MODES[route.mode] then return nil, 'invalid_mode' end
    route.afk = route.mode == 'free' and input.afk == true

    if input.start ~= nil then
        route.start = Rules.normalizePlacement(input.start)
        if not route.start then return nil, 'invalid_start' end
    end

    if input.npc ~= nil then
        local npc = input.npc
        if type(npc) ~= 'table' or not Rules.isName(npc.model) then return nil, 'invalid_npc' end
        if npc.scenario ~= nil and npc.scenario ~= '' and not Rules.isName(npc.scenario) then
            return nil, 'invalid_npc'
        end
        route.npc = { model = npc.model:lower(), scenario = npc.scenario ~= '' and npc.scenario or nil }
    end

    route.groups = {}
    if input.groups ~= nil then
        if type(input.groups) ~= 'table' or count(input.groups) > limits.groupsPerRoute then
            return nil, 'invalid_groups'
        end
        for group, grade in pairs(input.groups) do
            if not Rules.isName(group, 32) or not intBetween(grade, 0, 99) then return nil, 'invalid_groups' end
            route.groups[group] = grade
        end
    end

    if input.vehicle ~= nil and input.vehicle ~= '' then
        if not Rules.isName(input.vehicle, 32) then return nil, 'invalid_vehicle' end
        route.vehicle = input.vehicle:lower()
    end
    -- Na rota de carga, com posição, a rota entrega o veículo ali; sem, o jogador traz um
    -- do model. Turno e coleta livre só conferem que ele veio de veículo.
    if input.vehicleSpawn ~= nil and route.vehicle and route.mode == 'haul' then
        route.vehicleSpawn = Rules.normalizePlacement(input.vehicleSpawn)
        if not route.vehicleSpawn then return nil, 'invalid_vehicle' end
    end

    local requirement, requirementErr = normalizeRequirement(input.requirement, known)
    if requirementErr then return nil, requirementErr end
    route.requirement = requirement

    local police = type(input.police) == 'table' and input.police or {}
    local chance = police.chance == nil and 0 or normalizeChance(police.chance)
    local radius = normalizeRadius(police.radius, limits.alertRadius)
    if not chance or not radius then return nil, 'invalid_police' end
    route.police = { enabled = police.enabled == true, chance = chance, radius = radius }

    if route.mode == 'haul' then
        local haul, haulErr = normalizeHaul(input.haul, limits, known)
        if not haul then return nil, haulErr end
        route.haul = haul
    end

    route.items = {}
    if input.items ~= nil then
        if type(input.items) ~= 'table' or count(input.items) > limits.itemsPerRoute then
            return nil, 'invalid_items'
        end
        for itemName, itemInput in pairs(input.items) do
            if not Rules.isName(itemName) or not isKnownItem(itemName) then return nil, 'invalid_item' end
            local item, err = normalizeItem(itemInput, limits, isKnownItem)
            if not item then return nil, err end
            route.items[itemName] = item
        end
    end

    return route
end

---Uma rota só roda com o que ela precisa: turno exige ponto de início.
---@param route table
---@return boolean
function Rules.isPlayable(route)
    if route.mode == 'haul' then
        local haul = route.haul
        return route.start ~= nil and route.vehicle ~= nil and haul ~= nil
            and haul.stack ~= nil and haul.dropoff ~= nil
    end
    if route.mode == 'shift' and not route.start then return false end
    for _, item in pairs(route.items) do
        if #item.points > 0 then return true end
    end
    return false
end

---O que os clientes recebem pelo GlobalState. Recompensa, chance de alerta, extras,
---stress e ferramenta ficam só no servidor (§19.1): o client só precisa saber onde
---desenhar alvo, quanto dura a barra e qual animação tocar.
---@param id integer
---@param route table
---@return table
function Rules.publicView(id, route)
    local items = {}
    for itemName, item in pairs(route.items) do
        items[itemName] = {
            label = item.label,
            time = item.time,
            anim = item.anim,
            points = item.points,
            tool = item.tool and item.tool.name or nil,
        }
    end

    local groups = {}
    for group, grade in pairs(route.groups) do groups[group] = grade end

    local haul = nil
    if route.haul then
        haul = { stack = route.haul.stack, prop = route.haul.prop, count = route.haul.count,
            dropoff = route.haul.dropoff }
    end

    return {
        id = id,
        name = route.name,
        mode = route.mode,
        afk = route.afk,
        start = route.start,
        npc = route.npc,
        groups = groups,
        vehicle = route.vehicle,
        items = route.mode == 'haul' and {} or items,
        haul = haul,
    }
end

---Rota sem grupo é pública.
---@param groups table<string, integer>
---@return boolean
function Rules.isPublic(groups)
    return next(groups) == nil
end

---Próximo ponto do turno, ou nil quando o turno acabou.
---
---Sem `unlimited`, o turno tem tantas coletas quantos pontos houver, na ordem ou
---sorteado. Com `unlimited`, a sequência volta ao primeiro. O sorteio nunca repete o
---ponto que acabou de ser coletado, quando há mais de um.
---@param item { points: table, random: boolean, unlimited: boolean }
---@param last integer? índice do último ponto coletado
---@param collected integer quantas coletas o turno já teve
---@param rng? fun(min: integer, max: integer): integer
---@return integer?
function Rules.nextPoint(item, last, collected, rng)
    rng = rng or math.random
    local total = #item.points
    if total == 0 then return nil end
    if not item.unlimited and collected >= total then return nil end

    if item.random then
        if total == 1 then return 1 end
        if not last then return rng(1, total) end
        local index = rng(1, total - 1)
        if index >= last then index = index + 1 end
        return index
    end

    local index = (last or 0) + 1
    if index > total then index = 1 end
    return index
end

---@param range { min: integer, max: integer }
---@param rng? fun(min: integer, max: integer): integer
---@return integer
function Rules.roll(range, rng)
    rng = rng or math.random
    if range.min >= range.max then return range.max end
    return rng(range.min, range.max)
end

---@param percent number 0 a 100
---@param rng? fun(): number
---@return boolean
function Rules.chance(percent, rng)
    rng = rng or math.random
    if not Rules.isFinite(percent) or percent <= 0 then return false end
    if percent >= 100 then return true end
    return rng() * 100 < percent
end

---Centro do alerta: um ponto sorteado dentro de 60% do raio, para o círculo cobrir o
---lugar sem apontar para ele.
---@param coords { x: number, y: number, z: number }
---@param radius number
---@param rng? fun(): number
---@return { x: number, y: number, z: number }
function Rules.blurCoords(coords, radius, rng)
    rng = rng or math.random
    local angle = rng() * 2 * math.pi
    local distance = math.sqrt(rng()) * radius * 0.6
    return { x = coords.x + math.cos(angle) * distance, y = coords.y + math.sin(angle) * distance, z = coords.z }
end

---Chance de alerta de uma coleta: a do item, se tiver; senão a da rota, se ligada.
---@param route table
---@param item table
---@return number
function Rules.alertChance(route, item)
    if item.police then return item.police.chance end
    if route.police.enabled then return route.police.chance end
    return 0
end

return Rules
