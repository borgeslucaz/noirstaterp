---Único ponto do servidor que conhece outro resource pelo nome. Personagem, dinheiro,
---grupo e veículo passam pelo `bgrz_core` (§2.1).

local CORE = 'bgrz_core'

local Integrations = {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@return { citizenId: string, name: { full: string } }?
function Integrations.character(source)
    if not coreReady() then return nil end
    return exports[CORE]:GetCharacter(source)
end

---@param groups table<string, integer> vazio = qualquer jogador
---@return boolean
function Integrations.hasGroupAccess(source, groups)
    if next(groups) == nil then return true end
    if not coreReady() then return false end
    return exports[CORE]:HasGroupAccess(source, groups) == true
end

---@return integer? netId
function Integrations.spawnVehicle(source, model, coords, plate)
    if not coreReady() then return nil end
    return exports[CORE]:SpawnVehicle(source, model, coords, true, plate)
end

---@return boolean
function Integrations.addMoney(source, amount, reason)
    if not coreReady() then return false end
    return exports[CORE]:AddMoney(source, 'cash', amount, reason) ~= false
end

function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end

return Integrations
