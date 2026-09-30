---Único ponto do servidor que conhece outro resource pelo nome. Tudo do Qbox e do
---inventário passa pelo `bgrz_core` (§2.1); com a ponte fora do ar, a ação é recusada.

local Rules = require 'shared.rules'

local CORE = 'bgrz_core'
-- Skill de cultivo. Dependência leve: sem o noir_skills a colheita segue neutra e sem XP.
local SKILLS = 'noir_skills'

local Integrations = {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@param source number
---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end

---@param source number
---@return string? citizenId
function Integrations.citizenId(source)
    if not coreReady() then return nil end
    return exports[CORE]:GetCitizenId(source)
end

---@param source number
---@param jobs table<string, boolean>
---@param requireDuty boolean
---@return boolean
function Integrations.hasAnyJob(source, jobs, requireDuty)
    if not coreReady() then return false end
    for name in pairs(jobs) do
        if exports[CORE]:HasJob(source, name, requireDuty) then return true end
    end
    return false
end

---@param source number
---@param item string
---@return integer
function Integrations.count(source, item)
    if not coreReady() then return 0 end
    return tonumber(exports[CORE]:GetItemCount(source, item)) or 0
end

---@param source number
---@param item string
---@param amount integer
---@return boolean
function Integrations.canCarry(source, item, amount)
    if not coreReady() then return false end
    return exports[CORE]:CanCarryItem(source, item, amount) == true
end

---Validade de cada item em minutos (false = sem validade), lida uma vez da ponte.
---O `items.lua` do inventário continua sendo o único lugar onde ela é definida.
local degradeOf = {}

---Metadata com a validade arredondada para a hora cheia: o que sai no mesmo lote empilha.
---@param item string
---@return table?
local function expiryMetadata(item)
    local degrade = degradeOf[item]
    if degrade == nil then
        local minutes, err = exports[CORE]:GetItemDegrade(item)
        if err then return nil end -- não cacheia falha: tenta de novo na próxima
        degrade = minutes or false
        degradeOf[item] = degrade
    end
    if not degrade then return nil end
    return { durability = Rules.expiry(os.time(), degrade, 3600), degrade = degrade }
end

---@param source number
---@param item string
---@param amount integer
---@param grade? string grau do bud ou do saquinho, gravado no metadata
---@return boolean ok
---@return string? errorCode
function Integrations.addItem(source, item, amount, grade)
    if not coreReady() then return false, 'provider_unavailable' end
    local metadata = expiryMetadata(item)
    if grade then
        metadata = metadata or {}
        metadata.grade = grade
    end
    return exports[CORE]:AddItem(source, item, amount, metadata)
end

---Slots do item com quantidade e metadata; vazio se a ponte falhar.
---@param source number
---@param item string
---@return { slot: integer, count: integer, metadata: table }[]
function Integrations.slots(source, item)
    if not coreReady() then return {} end
    local slots = exports[CORE]:GetItemSlots(source, item)
    return type(slots) == 'table' and slots or {}
end

---Tira do inventário o que `Rules.pickSlots` escolheu. Se um slot falhar, devolve os que
---já saíram, com o mesmo grau (a validade recomeça: é o caso raro de o slot mudar entre a
---leitura e a remoção).
---@param source number
---@param item string
---@param plan { slot: integer, count: integer, grade: string }[]
---@return boolean ok
function Integrations.removePlan(source, item, plan)
    if not coreReady() then return false end
    for index = 1, #plan do
        local step = plan[index]
        if not exports[CORE]:RemoveItemFromSlot(source, item, step.count, step.slot) then
            for undo = 1, index - 1 do
                Integrations.addItem(source, item, plan[undo].count, plan[undo].grade)
            end
            return false
        end
    end
    return true
end

---@param source number
---@param item string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function Integrations.removeItem(source, item, amount)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:RemoveItem(source, item, amount)
end

---O holder tem o item com pelo menos `cost` de durabilidade?
---@param source number
---@param item string
---@param cost number
---@return boolean ok
---@return string? errorCode `not_enough_items` | `low_durability` | ...
function Integrations.hasDurability(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:HasItemDurability(source, item, cost)
end

---@param source number
---@param item string
---@param cost number
---@return boolean ok
---@return string? errorCode
function Integrations.useDurability(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    local ok, err = exports[CORE]:ConsumeItemDurability(source, item, cost)
    return ok == true, err
end

---Nível da skill, ou nil com o noir_skills fora do ar.
---@param source number
---@param skill string
---@return integer?
function Integrations.skillLevel(source, skill)
    if GetResourceState(SKILLS) ~= 'started' then return nil end
    local ok, level = pcall(function() return exports[SKILLS]:GetLevel(source, skill) end)
    return ok and tonumber(level) or nil
end

---@param source number
---@param skill string
---@param xp integer
function Integrations.addSkillXp(source, skill, xp)
    if xp <= 0 or GetResourceState(SKILLS) ~= 'started' then return end
    pcall(function() exports[SKILLS]:AddXp(source, skill, xp) end)
end

return Integrations
