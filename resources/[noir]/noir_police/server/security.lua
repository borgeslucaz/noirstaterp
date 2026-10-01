---Validações comuns do servidor: jogador válido, distância, papel e frequência.
---Nada aqui confia em state bag: o papel vem do bridge no momento da ação.

local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Integrations = require 'server.integrations'

local Security = {}

local nextAllowedAt = {}

---@param source any
---@return integer? source válido com ped no mundo
function Security.player(source)
    source = tonumber(source)
    if not source or source <= 0 or source % 1 ~= 0 then return nil end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return source
end

---@param source integer
---@return vector3?
function Security.coords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

---@param source integer
---@param target vector3
---@param maximum number
---@return boolean
function Security.near(source, target, maximum)
    local coords = Security.coords(source)
    return coords ~= nil and target ~= nil and #(coords - target) <= maximum
end

---@param a integer
---@param b integer
---@param maximum number
---@return boolean
function Security.playersNear(a, b, maximum)
    local ca, cb = Security.coords(a), Security.coords(b)
    return ca ~= nil and cb ~= nil and #(ca - cb) <= maximum
end

---@param source integer
---@return boolean
function Security.inVehicle(source)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
end

---@param source integer
---@param action string
---@return boolean allowed
function Security.rateLimit(source, action)
    local interval = ServerConfig.rateLimit[action] or ServerConfig.rateLimit.default
    local now = GetGameTimer()
    local byAction = nextAllowedAt[source]
    if not byAction then
        byAction = {}
        nextAllowedAt[source] = byAction
    end
    if (byAction[action] or 0) > now then return false end
    byAction[action] = now + interval
    return true
end

---Policial em serviço com grade para a ação. Devolve o job normalizado.
---@param source integer
---@param action? string
---@return table? job
function Security.police(source, action)
    local job = Integrations.getJob(source)
    if not Departments.can(job, action) then return nil end
    return job
end

---Policial ou EMS em serviço.
---@param source integer
---@return table? job
function Security.emergency(source)
    local job = Integrations.getJob(source)
    if Departments.isOnDutyPolice(job) or Departments.isOnDutyEms(job) then return job end
    return nil
end

AddEventHandler('playerDropped', function()
    nextAllowedAt[source] = nil
end)

return Security
