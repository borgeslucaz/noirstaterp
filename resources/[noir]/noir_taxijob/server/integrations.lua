---Único ponto do servidor que conhece outro resource pelo nome. Personagem, dinheiro,
---notificação e veículo passam pelo `bgrz_core` (§2.1).

local CORE = 'bgrz_core'

Integrations = {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@return table?
function Integrations.character(source)
    if not coreReady() then return nil end
    return exports[CORE]:GetCharacter(source)
end

---@return boolean
function Integrations.addMoney(source, account, amount, reason)
    if not coreReady() then return false end
    return exports[CORE]:AddMoney(source, account, amount, reason) ~= false
end

---@return boolean
function Integrations.removeMoney(source, account, amount, reason)
    if not coreReady() then return false end
    return exports[CORE]:RemoveMoney(source, account, amount, reason) == true
end

---@return integer? netId
function Integrations.spawnVehicle(source, model, coords, warp, plate)
    if not coreReady() then return nil end
    return exports[CORE]:SpawnVehicle(source, model, coords, warp, plate)
end

function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end
