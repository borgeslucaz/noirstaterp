---Único ponto do cliente que conhece outro resource pelo nome.
---
---  * notificação: `bgrz_core` (§2.1);
---  * target: `ox_target` DIRETO, a exceção do §2.5 — declarado em dependencies{} e chamado só
---    daqui, com as options no namespace `noir_missions:*`;
---  * pílulas de tecla e fala de ped: `noir_lib` (opcional: sem ele, a dica some e a fala vira
---    notificação);
---  * minigame: `noir_minigames` (opcional: sem ele, a interação passa sem minigame).
local Integrations = {}

local CORE = 'bgrz_core'
local TARGET = 'ox_target'
local LIB = 'noir_lib'
local MINIGAMES = 'noir_minigames'

---@param resource string
---@return boolean
local function started(resource)
    return GetResourceState(resource) == 'started'
end

---@param message string
---@param kind? 'inform'|'success'|'warning'|'error'
function Integrations.notify(message, kind)
    if started(CORE) then
        local ok = pcall(function() exports[CORE]:Notify(message, kind or 'inform') end)
        if ok then return end
    end
    lib.notify({ description = message, type = kind == 'warning' and 'warning' or kind or 'inform' })
end

---@return boolean
function Integrations.isLoggedIn()
    if not started(CORE) then return false end
    local ok, logged = pcall(function() return exports[CORE]:IsLoggedIn() end)
    return ok and logged == true
end

-- Target --------------------------------------------------------------------------------

---@param netId integer
---@param options table[]
function Integrations.addEntityTarget(netId, options)
    if not started(TARGET) then return end
    exports[TARGET]:addEntity(netId, options)
end

---@param netId integer
---@param names string[]
function Integrations.removeEntityTarget(netId, names)
    if not started(TARGET) then return end
    exports[TARGET]:removeEntity(netId, names)
end

---@param entity integer
---@param options table[]
function Integrations.addLocalEntityTarget(entity, options)
    if not started(TARGET) then return end
    exports[TARGET]:addLocalEntity(entity, options)
end

---@param entity integer
---@param names string[]
function Integrations.removeLocalEntityTarget(entity, names)
    if not started(TARGET) then return end
    exports[TARGET]:removeLocalEntity(entity, names)
end

---@param data table { coords, radius, options }
---@return integer? zoneId
function Integrations.addSphereZone(data)
    if not started(TARGET) then return nil end
    return exports[TARGET]:addSphereZone(data)
end

---@param zoneId integer?
function Integrations.removeZone(zoneId)
    if not zoneId or not started(TARGET) then return end
    exports[TARGET]:removeZone(zoneId)
end

---@param options table[]
function Integrations.addGlobalVehicle(options)
    if not started(TARGET) then return end
    exports[TARGET]:addGlobalVehicle(options)
end

---@param names string[]
function Integrations.removeGlobalVehicle(names)
    if not started(TARGET) then return end
    exports[TARGET]:removeGlobalVehicle(names)
end

-- noir_lib --------------------------------------------------------------------------------

---@param keys { key: string, label: string }[]
---@param position? string
function Integrations.showKeys(keys, position)
    if not started(LIB) then return end
    pcall(function() exports[LIB]:ShowKeyHints({ position = position or 'baixo', keys = keys }) end)
end

function Integrations.hideKeys()
    if not started(LIB) then return end
    pcall(function() exports[LIB]:HideKeyHints() end)
end

---@param ped integer
---@param texts string[]
---@param tone? 'neutral'|'alert'
function Integrations.pedSay(ped, texts, tone)
    if started(LIB) then
        local ok = pcall(function() exports[LIB]:PedSay(ped, texts, { tone = tone or 'neutral' }) end)
        if ok then return end
    end
    Integrations.notify(texts[math.random(1, #texts)], tone == 'alert' and 'warning' or 'inform')
end

-- noir_minigames --------------------------------------------------------------------------

---@param id string
---@param difficulty integer
---@return boolean passed
function Integrations.playMinigame(id, difficulty)
    if not started(MINIGAMES) then
        lib.print.warn(('[noir_missions] noir_minigames parado; %s passa sem minigame'):format(id))
        return true
    end
    local ok, passed = pcall(function() return exports[MINIGAMES]:Play(id, difficulty) end)
    return ok and passed == true
end

---@return { id: string, label: string, available: boolean }[]
function Integrations.minigameList()
    if not started(MINIGAMES) then return {} end
    local ok, list = pcall(function() return exports[MINIGAMES]:List() end)
    return ok and type(list) == 'table' and list or {}
end

return Integrations
