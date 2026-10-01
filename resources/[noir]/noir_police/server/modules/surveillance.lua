---Vigilância: radar de velocidade, ANPR e placas marcadas, câmeras de segurança,
---tornozeleira e holofote do helicóptero.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Departments = require 'shared.departments'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Layout = require 'server.layout'
local Storage = require 'server.storage'
local Fleet = require 'server.modules.fleet'
local State = require 'server.state'

local Surveillance = {}

local flaggedPlates = {}
local radarCooldown = {}
local camerasOffline = {}

local function fail(code) return { ok = false, code = code } end

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = plate:upper():gsub('^%s+', ''):gsub('%s+$', '')
    if #plate < 2 or #plate > 8 or not plate:match('^[%w ]+$') then return nil end
    return plate
end

CreateThread(function()
    while not Storage.isReady() do Wait(500) end
    flaggedPlates = Storage.loadFlaggedPlates()
end)

-- Radar e ANPR ---------------------------------------------------------------------

RegisterNetEvent('noir_police:server:radar', function(index)
    local src = source
    if not Security.rateLimit(src, 'radar') then return end
    local radar = Config.radars.enabled and Layout.radars()[tonumber(index) or 0]
    if not radar then return end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if not Security.near(src, radar.coords.xyz, 35.0) then return end
    if Fleet.department(vehicle) then return end

    local key = ('%s:%s'):format(src, index)
    if (radarCooldown[key] or 0) > os.time() then return end
    radarCooldown[key] = os.time() + ServerConfig.radar.cooldownSeconds

    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    local coords = GetEntityCoords(vehicle)

    -- ANPR: placa marcada avisa a polícia, com ou sem excesso.
    local flagged = plate and flaggedPlates[plate]
    if flagged then
        Integrations.dispatch({
            code = '10-28',
            title = locale('dispatch.anpr_title'),
            message = locale('dispatch.anpr_message', plate, flagged.reason),
            coords = coords,
            jobs = Departments.jobNames(),
            priority = 2,
        })
    end

    -- Velocidade medida no servidor, não no cliente.
    local velocity = GetEntityVelocity(vehicle)
    local speed = #velocity * (Config.radars.useMph and 2.236936 or 3.6)
    local over = math.floor(speed - radar.speedLimit)
    if over <= 0 or over > ServerConfig.radar.maxOver then return end
    local fine = Utils.radarFine(ServerConfig.radar.fines, over)
    if not fine then return end

    local department = Departments.get(ServerConfig.radar.account)
    local invoiceId = Integrations.createInvoice({
        recipientSource = src,
        issuerAccount = ServerConfig.radar.account,
        issuerLabel = department and department.label or nil,
        kind = 'fine',
        title = locale('fine.radar_title'),
        description = locale('fine.radar_description', math.floor(speed), Config.radars.useMph and 'mph' or 'km/h',
            radar.speedLimit, plate or '?'),
        amount = fine,
        dueDays = ServerConfig.fines.dueDays,
        silent = true,
    })
    if invoiceId then
        Integrations.notify(src, locale('info.radar_fine', fine, math.floor(speed), radar.speedLimit), 'warning')
        Integrations.log(src, 'radar', ('%s: %d acima em %s, multa $%d'):format(plate or '?', over, index, fine))
    end
end)

lib.addCommand('flagplate', {
    help = locale('command.flagplate'),
    params = {
        { name = 'plate', type = 'string', help = locale('command.plate_param') },
        { name = 'reason', type = 'longString', help = locale('command.reason_param') },
    },
}, function(src, args)
    if not Security.police(src, 'flagPlate') then return Integrations.notify(src, locale('error.not_police'), 'error') end
    local plate = normalizePlate(args.plate)
    local reason = Utils.cleanText(args.reason, 200, 3)
    if not plate or not reason then return Integrations.notify(src, locale('error.invalid_input'), 'error') end
    local cid = Integrations.getCitizenId(src)
    Storage.flagPlate(plate, reason, cid)
    flaggedPlates[plate] = { plate = plate, reason = reason, officer_cid = cid }
    Integrations.notify(src, locale('success.plate_flagged', plate), 'success')
    Integrations.log(src, 'flagplate', ('%s marcou %s: %s'):format(Integrations.getName(src), plate, reason))
end)

lib.addCommand('unflagplate', {
    help = locale('command.unflagplate'),
    params = { { name = 'plate', type = 'string', help = locale('command.plate_param') } },
}, function(src, args)
    if not Security.police(src, 'flagPlate') then return Integrations.notify(src, locale('error.not_police'), 'error') end
    local plate = normalizePlate(args.plate)
    if not plate or not flaggedPlates[plate] then return Integrations.notify(src, locale('error.plate_not_flagged'), 'error') end
    Storage.unflagPlate(plate)
    flaggedPlates[plate] = nil
    Integrations.notify(src, locale('success.plate_unflagged', plate), 'success')
end)

lib.addCommand('plateinfo', {
    help = locale('command.plateinfo'),
    params = { { name = 'plate', type = 'string', help = locale('command.plate_param') } },
}, function(src, args)
    if not Security.police(src) then return Integrations.notify(src, locale('error.not_police'), 'error') end
    local plate = normalizePlate(args.plate)
    local entry = plate and flaggedPlates[plate]
    if entry then
        Integrations.notify(src, locale('info.plate_flagged', plate, entry.reason), 'warning')
    else
        Integrations.notify(src, locale('info.plate_clean', plate or '?'), 'inform')
    end
end)

---@param plate string
---@return boolean
function Surveillance.isPlateFlagged(plate)
    plate = normalizePlate(plate)
    return plate ~= nil and flaggedPlates[plate] ~= nil
end

exports('IsPlateFlagged', Surveillance.isPlateFlagged)

-- Câmeras de segurança ---------------------------------------------------------------

local function nearCameraDesk(src, job)
    for _, station in ipairs(Layout.stations()) do
        if station.cameras and Departments.stationServes(station, job.name)
            and Security.near(src, station.cameras.coords, station.cameras.radius + 2.0) then
            return true
        end
    end
    return false
end

lib.callback.register('noir_police:server:cameraAccess', function(src)
    local job = Security.police(src, 'cameras')
    if not job then return fail('not_police') end
    if not nearCameraDesk(src, job) then return fail('too_far') end
    local offline = {}
    for index in pairs(camerasOffline) do offline[#offline + 1] = index end
    return { ok = true, offline = offline }
end)

---@param indexes integer|integer[]
---@param online boolean
function Surveillance.setCameraOnline(indexes, online)
    if type(indexes) ~= 'table' then indexes = { indexes } end
    for _, index in ipairs(indexes) do
        index = tonumber(index)
        if index and Layout.cameras()[index] then camerasOffline[index] = not online or nil end
    end
end

function Surveillance.setAllCamerasOnline(online)
    for index in ipairs(Layout.cameras()) do camerasOffline[index] = not online or nil end
end

exports('SetCameraOnline', Surveillance.setCameraOnline)
exports('SetAllCamerasOnline', Surveillance.setAllCamerasOnline)

-- Tornozeleira ---------------------------------------------------------------------

lib.callback.register('noir_police:server:anklet', function(src, targetId)
    if not Security.rateLimit(src, 'anklet') then return fail('rate_limited') end
    if not Security.police(src, 'anklet') then return fail('not_police') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end
    if not State.isCuffed(target) then return fail('not_restrained') end

    local enabled = Integrations.getMetadata(target, 'tracker') ~= true
    Integrations.setMetadata(target, 'tracker', enabled)
    TriggerClientEvent('noir_police:client:anklet', target, enabled)
    Integrations.log(src, 'anklet', ('%s %s tornozeleira em %s'):format(Integrations.getName(src),
        enabled and 'colocou' or 'tirou', Integrations.getName(target)))
    return { ok = true, enabled = enabled, citizenId = Integrations.getCitizenId(target) }
end)

lib.addCommand('ankletlocation', {
    help = locale('command.ankletlocation'),
    params = { { name = 'citizenid', type = 'string', help = locale('command.citizenid_param') } },
}, function(src, args)
    if not Security.police(src, 'anklet') then return Integrations.notify(src, locale('error.not_police'), 'error') end
    if not Security.rateLimit(src, 'anklet') then return end
    local target = type(args.citizenid) == 'string' and Integrations.getSourceByCitizenId(args.citizenid:upper())
    if not target then return Integrations.notify(src, locale('error.target_offline'), 'error') end
    if Integrations.getMetadata(target, 'tracker') ~= true then
        return Integrations.notify(src, locale('error.no_anklet'), 'error')
    end
    local coords = Security.coords(target)
    if not coords then return end
    TriggerClientEvent('noir_police:client:ankletPing', src, { x = coords.x, y = coords.y, z = coords.z },
        ServerConfig.anklet.pingSeconds)
end)

-- Holofote do helicóptero -----------------------------------------------------------

local heliModels = {}
for _, model in ipairs(Config.heli.models) do heliModels[model] = true end

RegisterNetEvent('noir_police:server:heliSpotlight', function(state)
    local src = source
    if not Security.rateLimit(src, 'default') then return end
    if not Security.police(src) then return end
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if vehicle == 0 or not heliModels[GetEntityModel(vehicle)] then return end
    TriggerClientEvent('noir_police:client:heliSpotlight', -1, NetworkGetNetworkIdFromEntity(vehicle), state == true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for key in pairs(radarCooldown) do
        if key:find(('^%s:'):format(src)) then radarCooldown[key] = nil end
    end
end)

return Surveillance
