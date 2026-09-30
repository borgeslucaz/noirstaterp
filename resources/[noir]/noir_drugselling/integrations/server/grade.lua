-- Grau da droga, gravado pelo noir_weed no metadata do saquinho (`grade`: C, B, A, S).
-- A venda sai de um slot só, o do melhor grau (empate: o que vence antes), e o grau
-- multiplica o preço. Os slots passam pelo bgrz_core, porque o RemoveItem do inventário
-- só casa metadata idêntico e a validade muda de lote para lote. Sem o bgrz_core de pé, a
-- venda segue como antes: qualquer slot, preço cheio.

NoirDrugGrade = {}

local CORE = 'bgrz_core'

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

local function multiplierOf(grade)
    local cfg = Config.Grades
    return cfg.multiplier[grade] or cfg.multiplier[cfg.default] or 1.0
end

---Slot de onde a próxima venda sai. `graded` diz se o item tem grau de verdade (droga
---sem grau conta como o padrão, sem aparecer no rótulo).
---@param source number
---@param item string
---@return { slot: integer, count: integer, grade: string, graded: boolean }?
function NoirDrugGrade.pick(source, item)
    if not coreReady() then return nil end
    local ok, slots = pcall(function() return exports[CORE]:GetItemSlots(source, item) end)
    if not ok or type(slots) ~= 'table' then return nil end

    local best, bestValue, bestExpiry
    for _, entry in ipairs(slots) do
        local metadata = entry.metadata or {}
        local graded = Config.Grades.multiplier[metadata.grade] ~= nil
        local grade = graded and metadata.grade or Config.Grades.default
        local value = multiplierOf(grade)
        local expiry = tonumber(metadata.durability) or math.huge
        if not best or value > bestValue or (value == bestValue and expiry < bestExpiry) then
            best = { slot = entry.slot, count = entry.count, grade = grade, graded = graded }
            bestValue, bestExpiry = value, expiry
        end
    end
    return best
end

---@param lot? { grade: string }
---@return number
function NoirDrugGrade.multiplier(lot)
    return multiplierOf(lot and lot.grade or Config.Grades.default)
end

---@param source number
---@param item string
---@param amount integer
---@param lot { slot: integer }
---@return boolean
function NoirDrugGrade.remove(source, item, amount, lot)
    if not coreReady() then return false end
    local ok, removed = pcall(function() return exports[CORE]:RemoveItemFromSlot(source, item, amount, lot.slot) end)
    return ok and removed == true
end

---Devolve a droga com o grau que ela tinha (o ped roubado que foi recuperado).
---@param source number
---@param item string
---@param amount integer
---@param grade string
---@return boolean
function NoirDrugGrade.give(source, item, amount, grade)
    if not coreReady() then return false end
    local ok, added = pcall(function() return exports[CORE]:AddItem(source, item, amount, { grade = grade }) end)
    return ok and added == true
end
