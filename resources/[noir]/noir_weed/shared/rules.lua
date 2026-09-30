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

---Índice do estágio para um crescimento: o último limiar já alcançado.
---@param stageAt number[] crescimento (%) em que cada estágio começa
---@param growth number
---@return integer
function Rules.stageFor(stageAt, growth)
    local stage = 1
    for index = 1, #stageAt do
        if growth >= stageAt[index] then stage = index end
    end
    return stage
end

---Um ciclo de crescimento. A planta perde água, fertilizante e saúde; só cresce se nenhum
---dos três chegou a zero. Cada ciclo soma o cuidado (média dos três) em `careSum`, que dá
---o grau na colheita. Planta pronta para de mudar.
---@param plant { growth: number, health: number, water: number, fertilizer: number, careSum: number?, careTicks: integer? }
---@param growth { loseWater: number, loseFertilizer: number, loseHealth: number, gain: number }
---@param harvestAt number
---@return boolean changed
function Rules.tick(plant, growth, harvestAt)
    if plant.growth >= harvestAt then return false end

    plant.water = Rules.clamp(plant.water - growth.loseWater, 0, 100)
    plant.fertilizer = Rules.clamp(plant.fertilizer - growth.loseFertilizer, 0, 100)
    plant.health = Rules.clamp(plant.health - growth.loseHealth, 0, 100)

    plant.careSum = (plant.careSum or 0) + (plant.water + plant.fertilizer + plant.health) / 3
    plant.careTicks = (plant.careTicks or 0) + 1

    if plant.water > 0 and plant.fertilizer > 0 and plant.health > 0 then
        plant.growth = Rules.clamp(plant.growth + growth.gain, 0, harvestAt)
    end
    return true
end

---Cuidado médio da planta até agora (0 a 100). Sem ciclo nenhum ainda, 0.
---@param plant { careSum: number?, careTicks: integer? }
---@return number
function Rules.careAverage(plant)
    local ticks = plant.careTicks or 0
    if ticks <= 0 then return 0 end
    return Rules.clamp((plant.careSum or 0) / ticks, 0, 100)
end

---Faixa em que o nível cai: a última cujo `level` já foi alcançado. Nível abaixo da
---primeira faixa, ou nenhum, devolve nil.
---@param bands { level: integer }[] em ordem crescente de nível
---@param level? integer
---@return table?
function Rules.levelBand(bands, level)
    if type(level) ~= 'number' then return nil end
    local found
    for index = 1, #bands do
        if level >= bands[index].level then found = bands[index] end
    end
    return found
end

---Vantagem de nível ligada?
---@param perk? { level: integer }
---@param level? integer
---@return boolean
function Rules.perkActive(perk, level)
    return perk ~= nil and type(level) == 'number' and level >= perk.level
end

---Taxas do ciclo com as vantagens do nível: perde menos água e fertilizante, cresce mais
---rápido. Devolve uma cópia; `growth` fica como está.
---@param growth { loseWater: number, loseFertilizer: number, loseHealth: number, gain: number }
---@param level? integer
---@param perks { thirst: { level: integer, factor: number }?, fastGrowth: { level: integer, factor: number }? }
---@return table
function Rules.growthFor(growth, level, perks)
    local rates = {}
    for key, value in pairs(growth) do rates[key] = value end
    if Rules.perkActive(perks.thirst, level) then
        rates.loseWater = rates.loseWater * perks.thirst.factor
        rates.loseFertilizer = rates.loseFertilizer * perks.thirst.factor
    end
    if Rules.perkActive(perks.fastGrowth, level) then
        rates.gain = rates.gain * perks.fastGrowth.factor
    end
    return rates
end

-- Grau ----------------------------------------------------------------------------------

---Posição do grau na ordem (1 = pior), ou nil se não for um grau.
---@param order string[]
---@param grade any
---@return integer?
function Rules.gradeRank(order, grade)
    for index = 1, #order do
        if order[index] == grade then return index end
    end
    return nil
end

---Grau pelo cuidado: a última faixa cujo `care` foi alcançado.
---@param bands { care: number, grade: string }[] em ordem crescente de cuidado
---@param care number
---@return string
function Rules.gradeFor(bands, care)
    local grade = bands[1].grade
    for index = 1, #bands do
        if care >= bands[index].care then grade = bands[index].grade end
    end
    return grade
end

---O pior dos dois graus (o teto do nível corta o grau do cuidado).
---@param order string[]
---@param a string
---@param b string
---@return string
function Rules.minGrade(order, a, b)
    return (Rules.gradeRank(order, a) or 0) <= (Rules.gradeRank(order, b) or 0) and a or b
end

---Grau do slot: o do metadata, ou o padrão para item sem grau.
---@param grades { order: string[], default: string }
---@param metadata? table
---@return string
function Rules.slotGrade(grades, metadata)
    local grade = type(metadata) == 'table' and metadata.grade or nil
    if Rules.gradeRank(grades.order, grade) then return grade end
    return grades.default
end

---Quantidade de cada grau nos slots.
---@param grades { order: string[], default: string }
---@param slots { count: integer, metadata: table? }[]
---@return table<string, integer>
function Rules.gradeCounts(grades, slots)
    local counts = {}
    for index = 1, #slots do
        local grade = Rules.slotGrade(grades, slots[index].metadata)
        counts[grade] = (counts[grade] or 0) + slots[index].count
    end
    return counts
end

---De quais slots tirar `amount` unidades do grau pedido: vence antes, sai antes. Sem
---`grade`, tira do pior grau para o melhor (o baseado não liga para grau, e o melhor fica
---para vender). Sem unidades suficientes, nil.
---@param grades { order: string[], default: string }
---@param slots { slot: integer, count: integer, metadata: table? }[]
---@param amount integer
---@param grade? string
---@return { slot: integer, count: integer, grade: string }[]?
function Rules.pickSlots(grades, slots, amount, grade)
    local candidates = {}
    for index = 1, #slots do
        local entry = slots[index]
        local slotGrade = Rules.slotGrade(grades, entry.metadata)
        if not grade or slotGrade == grade then
            local expiry = type(entry.metadata) == 'table' and tonumber(entry.metadata.durability) or math.huge
            candidates[#candidates + 1] = {
                slot = entry.slot, count = entry.count, grade = slotGrade,
                rank = Rules.gradeRank(grades.order, slotGrade), expiry = expiry,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.expiry ~= b.expiry then return a.expiry < b.expiry end
        return a.slot < b.slot
    end)

    local plan, left = {}, amount
    for index = 1, #candidates do
        if left <= 0 then break end
        local take = math.min(left, candidates[index].count)
        plan[#plan + 1] = { slot = candidates[index].slot, count = take, grade = candidates[index].grade }
        left = left - take
    end
    if left > 0 then return nil end
    return plan
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

---Quantidade ajustada por percentual, arredondada, nunca abaixo de 1.
---@param amount integer
---@param percent number
---@return integer
function Rules.applyPercent(amount, percent)
    return math.max(1, math.floor(amount * (100 + percent) / 100 + 0.5))
end

---Instante de validade arredondado para baixo no múltiplo de `bucket` segundos. Itens
---criados no mesmo intervalo saem com a mesma validade e empilham no inventário.
---@param now integer os.time()
---@param degradeMinutes number
---@param bucket integer segundos
---@return integer
function Rules.expiry(now, degradeMinutes, bucket)
    local exact = now + math.floor(degradeMinutes * 60)
    return exact - exact % bucket
end

---Quantas vezes dá para fazer uma receita com o que o jogador tem.
---@param ingredients table<string, integer>
---@param count fun(item: string): integer
---@return integer
function Rules.maxBatch(ingredients, count)
    local best
    for item, amount in pairs(ingredients) do
        local times = math.floor(count(item) / amount)
        if not best or times < best then best = times end
    end
    return best or 0
end

---Ingredientes ou saídas de uma receita multiplicados por `times`.
---@param items table<string, integer>
---@param times integer
---@return table<string, integer>
function Rules.scale(items, times)
    local scaled = {}
    for item, amount in pairs(items) do scaled[item] = amount * times end
    return scaled
end

return Rules
