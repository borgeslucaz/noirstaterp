---Contas da planta, sem native nenhum: o servidor aplica, os testes conferem.

local Rules = {}

---@param value number
---@param min number
---@param max number
---@return number
function Rules.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

---Índice do estágio para um crescimento: o último cujo `from` já foi alcançado.
---@param stages { from: number }[]
---@param growth number
---@return integer
function Rules.stageFor(stages, growth)
    local stage = 1
    for index = 1, #stages do
        if growth >= stages[index].from then stage = index end
    end
    return stage
end

---Um ciclo de crescimento. A planta perde água, fertilizante e saúde; só cresce se nenhum
---dos três chegou a zero. Planta pronta para de mudar.
---@param plant { growth: number, health: number, water: number, fertilizer: number }
---@param growth { loseWater: number, loseFertilizer: number, loseHealth: number, gain: number }
---@param harvestAt number
---@return boolean changed
function Rules.tick(plant, growth, harvestAt)
    if plant.growth >= harvestAt then return false end

    plant.water = Rules.clamp(plant.water - growth.loseWater, 0, 100)
    plant.fertilizer = Rules.clamp(plant.fertilizer - growth.loseFertilizer, 0, 100)
    plant.health = Rules.clamp(plant.health - growth.loseHealth, 0, 100)

    if plant.water > 0 and plant.fertilizer > 0 and plant.health > 0 then
        plant.growth = Rules.clamp(plant.growth + growth.gain, 0, harvestAt)
    end
    return true
end

---Quantidade colhida: linear na saúde, arredondada para baixo.
---@param range { min: integer, max: integer }
---@param health number
---@return integer
function Rules.reward(range, health)
    local share = Rules.clamp(health, 0, 100) / 100
    return range.min + math.floor((range.max - range.min) * share)
end

---@param point { x: number, y: number, z: number }
---@param zones { coords: { x: number, y: number, z: number }, radius: number }[]
---@return boolean
function Rules.inBlacklist(point, zones)
    for index = 1, #zones do
        local zone = zones[index]
        local dx, dy, dz = point.x - zone.coords.x, point.y - zone.coords.y, point.z - zone.coords.z
        if math.sqrt(dx * dx + dy * dy + dz * dz) < zone.radius then return true end
    end
    return false
end

---Coordenada vinda do client: três números finitos e um heading finito.
---@param value any
---@return boolean
function Rules.isPlacement(value)
    if type(value) ~= 'table' then return false end
    for _, key in ipairs({ 'x', 'y', 'z', 'w' }) do
        local n = value[key]
        if type(n) ~= 'number' or n ~= n or n == math.huge or n == -math.huge then return false end
    end
    return true
end

return Rules
