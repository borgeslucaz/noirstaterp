local config = require 'config.client'

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

---Garagem aberta na tela. O servidor revalida garagem, guiche e dono em todo pedido.
---@type {name: string, garage: GarageConfig, accessPoint: integer, vehicles: table<integer, table>}?
local current

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'), 'error')
        return
    end
    spawnLock = true

    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'), 'error')
            return
        end

        local netId = lib.callback.await('noir_garage:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
        if not netId then return end

        local veh = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetToVeh(netId)
            end
        end)

        if veh == 0 then
            exports.qbx_core:Notify(locale('error.spawn_failed'), 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    assert(success, result)
end

local function closeGarage()
    if GaragePreview.isActive() then GaragePreview.hide() end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'setVisible', data = { visible = false } })
    current = nil
end

---@param garageName string
---@param garage GarageConfig
---@param accessPoint integer
local function openGarageMenu(garageName, garage, accessPoint)
    local garageInfo, vehicles = lib.callback.await('noir_garage:server:getGarageVehicles', false, garageName, accessPoint)
    if not garageInfo then return end

    if not vehicles or #vehicles == 0 then
        exports.qbx_core:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    local byId, uiVehicles = {}, {}
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        byId[vehicle.id] = vehicle
        uiVehicles[i] = {
            id = vehicle.id,
            icon = vehicle.icon,
            name = vehicle.name,
            modelLabel = vehicle.modelLabel,
            plate = vehicle.plate,
            state = vehicle.state,
            depotPrice = vehicle.depotPrice,
            canTakeOut = vehicle.canTakeOut,
            notice = vehicle.notice,
            isOwner = vehicle.isOwner,
            canManageKeys = vehicle.canManageKeys,
            canTransfer = vehicle.canTransfer,
            canRename = vehicle.canRename,
            vehicle_status = {
                body = math.floor((vehicle.props.bodyHealth or 1000) / 10),
                engine = math.floor((vehicle.props.engineHealth or 1000) / 10),
                fuel = math.floor(vehicle.props.fuelLevel or 100),
            },
        }
    end

    current = { name = garageName, garage = garage, accessPoint = accessPoint, vehicles = byId }

    SendNUIMessage({
        action = 'setVisible',
        data = {
            visible = true,
            vehicles = uiVehicles,
            garage = garageInfo,
        }
    })
    SetNuiFocus(true, true)
end

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('noir_garage:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        local parked = lib.callback.await('noir_garage:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        if parked then
            exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
        end
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    -- Grupo (job ou gang) so o servidor confere: a gang vem do noir_gangs, que o PlayerData daqui nao ve.
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

-- Zonas e blips de cada garagem, para o editor (/garagem) trocar ou apagar uma garagem sem restart.
---@type table<string, {zones: table[], blips: integer[], removed: boolean}>
local garageHandles = {}

---@param name string
local function removeGarage(name)
    local handles = garageHandles[name]
    if not handles then return end
    handles.removed = true
    for i = 1, #handles.zones do handles.zones[i]:remove() end
    for i = 1, #handles.blips do RemoveBlip(handles.blips[i]) end
    garageHandles[name] = nil
    lib.hideTextUI()
end

---Atendente do balcao: PED local, parado, criado so quando o jogador chega perto. No Enhanced um
---modelo que nao existe derruba o cliente, entao o modelo e conferido antes de qualquer request.
---@param accessPoint AccessPoint
---@param onSpawn? fun(ped: integer)
---@return { remove: fun() }
local function createAttendant(accessPoint, onSpawn)
    local ped, token = nil, 0
    local attendant = {}

    function attendant.spawn()
        local cfg = accessPoint.ped
        if ped or not cfg or type(cfg.model) ~= 'string' then return end
        token = token + 1
        local myToken = token
        CreateThread(function()
            local model = joaat(cfg.model)
            if not IsModelInCdimage(model) or not IsModelAPed(model) then
                lib.print.warn(('noir_garage: modelo de atendente inexistente: %s'):format(cfg.model))
                return
            end
            if not pcall(lib.requestModel, model, 5000) or myToken ~= token then return end
            -- Posicao propria (gizmo do editor) ou a do balcao; direcao dela mais o giro escolhido.
            local c = cfg.position or accessPoint.coords
            local heading = ((c.w or 0) + (tonumber(cfg.rotation) or 0)) % 360
            local created = CreatePed(4, model, c.x, c.y, c.z - 1.0, heading, false, false)
            SetModelAsNoLongerNeeded(model)
            if created == 0 then return end
            if myToken ~= token then
                DeleteEntity(created)
                return
            end
            ped = created
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedCanRagdoll(ped, false)
            if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end
            if onSpawn then onSpawn(ped) end
        end)
    end

    function attendant.remove()
        token = token + 1
        if not ped then return end
        exports.bgrz_core:RemoveLocalEntityTarget(ped)
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
        ped = nil
    end

    return attendant
end

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
local function createZones(garageName, garage, accessPoint, accessPointIndex)
    local handles = garageHandles[garageName]
    CreateThread(function()
        if handles.removed then return end
        accessPoint.dropPoint = accessPoint.dropPoint or accessPoint.spawn
        local drawRadius = accessPoint.drawRadius or 60
        local dropDrawRadius = accessPoint.dropDrawRadius or 60
        -- Com atendente, o jogador para ao lado dele (nao em cima): o raio do balcao cresce um pouco.
        local useRadius = accessPoint.useRadius or (accessPoint.ped and 1.6 or 1)
        local dropUseRadius = accessPoint.dropUseRadius or 1.5
        -- ox_target: a pe, o balcao abre pelo alvo (no atendente ou numa esfera); guardar continua no E.
        local useTarget = accessPoint.interaction == 'target'
        local targetZone = ('%s_%d'):format(garageName, accessPointIndex)
        local dropZone, coordsZone

        local function openFromTarget()
            if current or cache.vehicle or not checkCanAccess(garage) then return end
            openGarageMenu(garageName, garage, accessPointIndex)
        end
        local targetOptions = {
            {
                name = 'open',
                icon = garage.type == GarageType.DEPOT and 'fa-solid fa-car-burst' or 'fa-solid fa-warehouse',
                label = garage.type == GarageType.DEPOT and locale('info.target_impound') or locale('info.target_garage'),
                distance = 2.5,
                canInteract = function() return not cache.vehicle and not current end,
                onSelect = openFromTarget,
            },
        }

        local attendant = createAttendant(accessPoint, useTarget and function(ped)
            exports.bgrz_core:AddLocalEntityTarget(ped, targetOptions)
        end or nil)
        if useTarget and not accessPoint.ped then
            exports.bgrz_core:AddSphereZoneTarget({
                name = targetZone,
                coords = accessPoint.coords.xyz,
                radius = math.max(useRadius, 1.0),
                options = targetOptions,
            })
        end

        handles.zones[#handles.zones + 1] = {
            remove = function()
                if dropZone then dropZone:remove() dropZone = nil end
                if coordsZone then coordsZone:remove() coordsZone = nil end
                attendant.remove()
                if useTarget and not accessPoint.ped then exports.bgrz_core:RemoveZoneTarget(targetZone) end
            end,
        }
        local function createDropZone()
            if dropZone then return end
            dropZone = lib.zones.sphere({
                coords = accessPoint.dropPoint,
                radius = dropUseRadius,
                onEnter = function()
                    if not cache.vehicle then return end
                    lib.showTextUI(locale('info.park_e'))
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if not cache.vehicle then return end
                    if IsControlJustReleased(0, 38) then
                        if not checkCanAccess(garage) then return end
                        parkVehicle(cache.vehicle, garageName)
                    end
                end,
                debug = config.debugPoly
            })
        end

        local function createCoordsZone()
            if coordsZone then return end
            coordsZone = lib.zones.sphere({
                coords = accessPoint.coords,
                radius = useRadius,
                onEnter = function()
                    if accessPoint.dropPoint and cache.vehicle then return end
                    if useTarget and not cache.vehicle then return end
                    lib.showTextUI((garage.type == GarageType.DEPOT and locale('info.impound_e')) or (cache.vehicle and locale('info.park_e')) or locale('info.car_e'))
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if accessPoint.dropPoint and cache.vehicle then return end
                    if useTarget and not cache.vehicle then return end
                    if current then return end
                    if IsControlJustReleased(0, 38) then
                        if not checkCanAccess(garage) then return end
                        if cache.vehicle and garage.type ~= GarageType.DEPOT then
                            parkVehicle(cache.vehicle, garageName)
                        elseif not cache.vehicle then
                            openGarageMenu(garageName, garage, accessPointIndex)
                        end
                    end
                end,
                debug = config.debugPoly
            })
        end

        handles.zones[#handles.zones + 1] = lib.zones.sphere({
            coords = accessPoint.coords,
            radius = drawRadius,
            onEnter = function()
                createCoordsZone()
                attendant.spawn()
            end,
            onExit = function()
                if coordsZone then
                    coordsZone:remove()
                    coordsZone = nil
                end
                attendant.remove()
            end,
            inside = function()
                -- O atendente ou o alvo ja mostram onde e o balcao: o marcador so fica no modo E sem PED.
                if accessPoint.ped or useTarget then return end
                config.drawGarageMarker(accessPoint.coords.xyz, useRadius)
            end,
            debug = config.debugPoly,
        })

        if accessPoint.dropPoint and garage.type ~= GarageType.DEPOT then
            handles.zones[#handles.zones + 1] = lib.zones.sphere({
                coords = accessPoint.dropPoint,
                radius = dropDrawRadius,
                onEnter = function()
                    createDropZone()
                end,
                onExit = function()
                    if dropZone then
                        dropZone:remove()
                        dropZone = nil
                    end
                end,
                inside = function()
                    config.drawDropOffMarker(accessPoint.dropPoint, dropUseRadius)
                end,
                debug = config.debugPoly,
            })
        end
    end)
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
---@return integer blip
local function createBlips(garageInfo, accessPoint)
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function createGarage(name, garage)
    removeGarage(name)
    local handles = { zones = {}, blips = {}, removed = false }
    garageHandles[name] = handles
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]

        if accessPoint.blip then
            handles.blips[#handles.blips + 1] = createBlips(garage, accessPoint)
        end

        createZones(name, garage, accessPoint, i)
    end
end

local function createGarages()
    local garages = lib.callback.await('noir_garage:server:getGarages')
    for name, garage in pairs(garages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('noir_garage:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

RegisterNetEvent('noir_garage:client:garageRemoved', function(name)
    removeGarage(name)
end)

CreateThread(function()
    createGarages()
end)

-- NUI (interface do rhd_garage). Os callbacks so mandam o id do carro; garagem e guiche vem de `current`.

---@param data table
---@return table? vehicle
local function getSelected(data)
    return current and type(data) == 'table' and current.vehicles[tonumber(data.vehicleId)]
end

RegisterNUICallback('exit', function(_, cb)
    closeGarage()
    cb(1)
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    cb(1)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.canTakeOut or not current then return end
    local garageName, accessPoint = current.name, current.accessPoint
    closeGarage()
    takeOutOfGarage(vehicle.id, garageName, accessPoint)
end)

RegisterNUICallback('getVehicleLogs', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.isOwner or not current then return cb({}) end
    cb(lib.callback.await('noir_garage:server:getVehicleLogs', false, vehicle.id, current.name, current.accessPoint) or {})
end)

RegisterNUICallback('updateVehicleName', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.canRename or not current then return cb(false) end
    local nickname = lib.callback.await('noir_garage:server:renameVehicle', false, vehicle.id, current.name, current.accessPoint, data.newName)
    if nickname then vehicle.name = nickname end
    cb(nickname or false)
end)

RegisterNUICallback('getGarageList', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.canTransfer or not current then return cb({}) end
    cb(lib.callback.await('noir_garage:server:getTransferTargets', false, vehicle.id, current.name, current.accessPoint) or {})
end)

RegisterNUICallback('updateGarageName', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.canTransfer or not current then return cb(false) end
    local success = lib.callback.await('noir_garage:server:transferVehicle', false, vehicle.id, current.name, current.accessPoint, data.garage)
    if success then current.vehicles[vehicle.id] = nil end
    cb(success == true)
end)

RegisterNUICallback('keyCopy', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.canManageKeys or not current then return cb(false) end
    cb(lib.callback.await('noir_garage:server:buyKeyCopy', false, vehicle.id, current.name, current.accessPoint) == true)
end)

RegisterNUICallback('lockChange', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not vehicle.canManageKeys or not current then return cb(false) end
    cb(lib.callback.await('noir_garage:server:changeLock', false, vehicle.id, current.name, current.accessPoint) == true)
end)

RegisterNUICallback('showVehiclePreview', function(data, cb)
    local vehicle = getSelected(data)
    if not vehicle or not current then return cb(false) end
    local accessPoint = current.garage.accessPoints[current.accessPoint]
    local coords = accessPoint.spawn or accessPoint.coords
    cb(GaragePreview.show(vehicle.modelName, vehicle.props, coords))
end)

RegisterNUICallback('hideVehiclePreview', function(_, cb)
    if GaragePreview.isActive() then GaragePreview.hide() end
    cb(1)
end)

RegisterNUICallback('getVehicleStats', function(_, cb)
    cb(GaragePreview.getStats())
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not current then return end
    SetNuiFocus(false, false)
end)
