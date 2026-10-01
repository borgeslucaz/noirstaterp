---Serviço, contagem de policiais e posição de colegas (blips).

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Layout = require 'server.layout'

local Duty = {}

---Policiais em serviço, total ou de um departamento.
---@param department? string
---@return integer
function Duty.copCount(department)
    local count = 0
    for _, src in ipairs(Integrations.onDutyByType(Config.policeJobType)) do
        local job = Integrations.getJob(src)
        if Departments.isOnDutyPolice(job) and (not department or job.name == department) then
            count = count + 1
        end
    end
    return count
end

---O evento `police:SetCopCount` segue sendo emitido só enquanto qbx_drugs e
---qbx_bankrobbery ouvirem por ele. Crimes novos usam o export `GetCopCount`.
local function broadcastCount()
    TriggerClientEvent('police:SetCopCount', -1, Duty.copCount())
end

local function isStationPoint(src, job)
    for _, station in ipairs(Layout.stations()) do
        if Departments.stationServes(station, job.name) then
            for _, point in ipairs(station.duty or {}) do
                if Security.near(src, point, ServerConfig.distance.station) then return true end
            end
        end
    end
    return false
end

lib.callback.register('noir_police:server:toggleDuty', function(src)
    if not Security.rateLimit(src, 'duty') then return { ok = false, code = 'rate_limited' } end
    local job = Integrations.getJob(src)
    if not Departments.isPolice(job) then return { ok = false, code = 'not_police' } end
    if not isStationPoint(src, job) then return { ok = false, code = 'too_far' } end

    local target = not job.onDuty
    local ok, err = Integrations.setDuty(src, target)
    if not ok then return { ok = false, code = err or 'failed' } end
    Integrations.log(src, 'duty', ('%s %s serviço (%s)'):format(Integrations.getName(src),
        target and 'entrou em' or 'saiu de', job.name))
    return { ok = true, onDuty = target }
end)

AddEventHandler('bgrz_core:server:dutyUpdated', function() SetTimeout(250, broadcastCount) end)
AddEventHandler('bgrz_core:server:jobUpdated', function() SetTimeout(250, broadcastCount) end)
AddEventHandler('bgrz_core:server:playerLoaded', function(src)
    SetTimeout(1000, function()
        if src then TriggerClientEvent('police:SetCopCount', src, Duty.copCount()) end
    end)
end)
AddEventHandler('playerDropped', function() SetTimeout(500, broadcastCount) end)

-- Blips de colegas -----------------------------------------------------------------
-- Polícia e EMS em serviço veem uns aos outros. A posição vem do servidor, então
-- funciona fora do alcance de rede.

CreateThread(function()
    while true do
        local recipients, units = {}, {}
        local sources = Integrations.onDutyByType(Config.policeJobType)
        for _, src in ipairs(Integrations.onDutyByType(Config.emsJobType)) do sources[#sources + 1] = src end

        for _, src in ipairs(sources) do
            local job = Integrations.getJob(src)
            local coords = Security.coords(src)
            if job and job.onDuty and coords then
                recipients[#recipients + 1] = src
                local department = Departments.get(job.name)
                units[#units + 1] = {
                    id = src,
                    x = coords.x, y = coords.y, z = coords.z,
                    heading = GetEntityHeading(GetPlayerPed(src)),
                    job = job.name,
                    color = department and department.blipColor or 1,
                    label = ('%s %s'):format(Integrations.getMetadata(src, 'callsign') or '', Integrations.getName(src)),
                    inVehicle = Security.inVehicle(src),
                }
            end
        end

        for _, src in ipairs(recipients) do
            TriggerClientEvent('noir_police:client:units', src, units)
        end
        Wait(#recipients > 0 and ServerConfig.blipIntervalMs or ServerConfig.blipIntervalMs * 3)
    end
end)

AddEventHandler('bgrz_core:server:dutyUpdated', function(src, onDuty)
    if not onDuty and src then TriggerClientEvent('noir_police:client:units', src, {}) end
end)

exports('GetCopCount', Duty.copCount)

return Duty
