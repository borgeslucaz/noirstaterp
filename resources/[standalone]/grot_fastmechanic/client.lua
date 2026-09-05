local menuOpen = false
local currentVehicle = nil
local vehicleMods = {}
local vehicleHandling = {}
local defaultWheelOffsets = {}
local defaultWheelRotations = {}
local appliedHandlingVars = {}
local inCameraMode = false
function IsPlayerInVehicle()
    local ped = PlayerPedId()
    return IsPedInAnyVehicle(ped, false)
end
function GetVehicleMods(vehicle)
    local mods = {}
    mods.performance = {}
    for _, perf in ipairs(Config.Performance) do
        if perf.modType == 18 then
            mods.performance[perf.id] = IsToggleModOn(vehicle, perf.modType)
        else
            mods.performance[perf.id] = GetVehicleMod(vehicle, perf.modType)
        end
    end
    mods.visual = {}
    for _, vis in ipairs(Config.Visual) do
        mods.visual[vis.id] = GetVehicleMod(vehicle, vis.modType)
    end
    local color1, color2 = GetVehicleColours(vehicle)
    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    mods.colors = {
        primary = color1, 
        secondary = color2,
        pearlescent = pearl,
        wheel = wheelColor,
        dashboard = GetVehicleDashboardColour(vehicle),
        interior = GetVehicleInteriorColour(vehicle)
    }
    local tsr, tsg, tsb = GetVehicleTyreSmokeColor(vehicle)
    mods.tyresmoke = {
        enabled = IsToggleModOn(vehicle, 20),
        color = {r = tsr, g = tsg, b = tsb}
    }
    mods.neons = {
        left = IsVehicleNeonLightEnabled(vehicle, 0),
        right = IsVehicleNeonLightEnabled(vehicle, 1),
        front = IsVehicleNeonLightEnabled(vehicle, 2),
        back = IsVehicleNeonLightEnabled(vehicle, 3)
    }
    local nr, ng, nb = GetVehicleNeonLightsColour(vehicle)
    mods.neons.color = {r = nr, g = ng, b = nb}
    mods.xenon = {
        enabled = IsToggleModOn(vehicle, 22),
        color = GetVehicleXenonLightsColour(vehicle)
    }
    mods.windowTint = GetVehicleWindowTint(vehicle)
    mods.wheels = {
        type = GetVehicleWheelType(vehicle),
        variation = GetVehicleMod(vehicle, 23)
    }
    mods.extras = {}
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            mods.extras[i] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end
    return mods
end
function ApplyVehicleMods(vehicle, mods)
    if mods.performance then
        for id, value in pairs(mods.performance) do
            for _, perf in ipairs(Config.Performance) do
                if perf.id == id then
                    if perf.modType == 18 then
                        ToggleVehicleMod(vehicle, perf.modType, value)
                    else
                        SetVehicleMod(vehicle, perf.modType, value, false)
                    end
                    break
                end
            end
        end
    end
    if mods.visual then
        for id, value in pairs(mods.visual) do
            for _, vis in ipairs(Config.Visual) do
                if vis.id == id then
                    SetVehicleMod(vehicle, vis.modType, value, false)
                    break
                end
            end
        end
    end
    if mods.colors then
        SetVehicleColours(vehicle, mods.colors.primary or 0, mods.colors.secondary or 0)
    end
    if mods.wheels then
        if mods.wheels.type then
            SetVehicleWheelType(vehicle, mods.wheels.type)
        end
        if mods.wheels.variation then
            SetVehicleMod(vehicle, 23, mods.wheels.variation, false)
        end
    end
    if mods.extras then
        for extraId, enabled in pairs(mods.extras) do
            SetVehicleExtra(vehicle, tonumber(extraId), not enabled)
        end
    end
end
function GetVehicleHandling(vehicle)
    if appliedHandlingVars[vehicle] then
        return appliedHandlingVars[vehicle]
    end

    local handling = {}
    for _, h in ipairs(Config.Handling) do
        handling[h.id] = h.default
    end
    return handling
end
function ApplyVehicleHandling(vehicle, handling)
    if not DoesEntityExist(vehicle) then return end
    appliedHandlingVars[vehicle] = handling
    for id, value in pairs(handling) do
        if id == 'speed' then
            ModifyVehicleTopSpeed(vehicle, value)
        elseif id == 'acceleration' then
            SetVehicleEnginePowerMultiplier(vehicle, value)
        elseif id == 'braking' then
            SetVehicleBrakeLights(vehicle, false)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce', value)
        elseif id == 'traction' then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', value)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveLateral', value * 22.5)
        elseif id == 'suspension' then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionRaise', value)
        elseif id == 'downforce' then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fDownforceModifier', value)
        elseif id == 'camber' then
            if defaultWheelRotations[vehicle] then
                for i = 0, GetVehicleNumberOfWheels(vehicle) - 1 do
                    local isLeft = defaultWheelOffsets[vehicle][i] < 0.0
                    local rotVal = isLeft and value or -value
                    SetVehicleWheelYRotation(vehicle, i, defaultWheelRotations[vehicle][i] + rotVal)
                end
            end
        elseif id == 'trackWidth' then
            if defaultWheelOffsets[vehicle] then
                for i = 0, GetVehicleNumberOfWheels(vehicle) - 1 do
                    local isLeft = defaultWheelOffsets[vehicle][i] < 0.0
                    local widthVal = isLeft and -value or value
                    SetVehicleWheelXOffset(vehicle, i, defaultWheelOffsets[vehicle][i] + widthVal)
                end
            end
        end
    end
end
function GetAvailableMods(vehicle)
    local available = {}
    available.performance = {}
    for _, perf in ipairs(Config.Performance) do
        if perf.modType == 18 then
            available.performance[perf.id] = {
                label = perf.label,
                modType = perf.modType,
                options = {
                    {value = false, label = 'Desativado'},
                    {value = true, label = 'Ativado'}
                }
            }
        else
            local options = {}
            table.insert(options, {value = -1, label = 'Original'})
            local maxMod = GetNumVehicleMods(vehicle, perf.modType)
            local levels = perf.levels or 4
            if maxMod and maxMod > 0 then
                levels = math.max(maxMod, levels)
            end
            for i = 0, levels - 1 do
                table.insert(options, {value = i, label = 'Nível ' .. (i + 1)})
            end
            available.performance[perf.id] = {
                label = perf.label,
                modType = perf.modType,
                options = options
            }
        end
    end
    available.visual = {}
    for _, vis in ipairs(Config.Visual) do
        local maxMod = GetNumVehicleMods(vehicle, vis.modType)
        if maxMod and maxMod > 0 then
            local options = {}
            table.insert(options, {value = -1, label = 'Original'})
            for i = 0, maxMod - 1 do
                local label = GetModTextLabel(vehicle, vis.modType, i)
                if label and label ~= "NULL" and label ~= "" then
                    local translatedLabel = GetLabelText(label)
                    if translatedLabel and translatedLabel ~= "NULL" and translatedLabel ~= label then
                        table.insert(options, {value = i, label = translatedLabel})
                    else
                        table.insert(options, {value = i, label = 'Opção ' .. (i + 1)})
                    end
                else
                    table.insert(options, {value = i, label = 'Opção ' .. (i + 1)})
                end
            end
            available.visual[vis.id] = {
                label = vis.label,
                modType = vis.modType,
                options = options
            }
        end
    end
    available.colors = Config.Colors
    available.wheels = {
        types = Config.Wheels,
        maxVariation = GetNumVehicleMods(vehicle, 23)
    }
    available.windowTints = Config.WindowTints
    available.xenonColors = Config.XenonColors
    available.extras = {}
    for i = 0, 20 do
        if DoesExtraExist(vehicle, i) then
            table.insert(available.extras, {
                id = i,
                label = 'Extra ' .. i,
                enabled = IsVehicleExtraTurnedOn(vehicle, i)
            })
        end
    end
    return available
end
function OpenMechanic()
    if menuOpen then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        if GetResourceState('grot_notify') == 'started' then
            exports['grot_notify']:Notify('error', 'Você não está em um veículo!', 3000)
        end
        return
    end
    SetVehicleModKit(vehicle, 0)
    currentVehicle = vehicle
    defaultWheelOffsets[vehicle] = defaultWheelOffsets[vehicle] or {}
    defaultWheelRotations[vehicle] = defaultWheelRotations[vehicle] or {}
    for i = 0, GetVehicleNumberOfWheels(vehicle) - 1 do
        defaultWheelOffsets[vehicle][i] = defaultWheelOffsets[vehicle][i] or GetVehicleWheelXOffset(vehicle, i)
        defaultWheelRotations[vehicle][i] = defaultWheelRotations[vehicle][i] or GetVehicleWheelYRotation(vehicle, i)
    end
    menuOpen = true
    vehicleMods = GetVehicleMods(vehicle)
    vehicleHandling = GetVehicleHandling(vehicle)
    local availableMods = GetAvailableMods(vehicle)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        mods = GetVehicleMods(vehicle),
        available = GetAvailableMods(vehicle),
        handling = GetVehicleHandling(vehicle),
        handlingConfig = Config.Handling,
        locales = Locales[Config.Locale] or Locales['en']
    })
end
exports('OpenMenu', OpenMechanic)
RegisterCommand(Config.OpenCommand, function()
    OpenMechanic()
end, false)

function CloseMechanic()
    menuOpen = false
    currentVehicle = nil
    SendNUIMessage({
        action = 'close'
    })
    Citizen.CreateThread(function()
        Citizen.Wait(100)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end)
end
RegisterNUICallback('close', function(data, cb)
    CloseMechanic()
    cb('ok')
end)
RegisterNUICallback('toggleCameraMode', function(data, cb)
    local enableCamera = data.enableCamera
    if enableCamera then
        inCameraMode = true
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    else
        inCameraMode = false
        SetNuiFocusKeepInput(false)
        SetNuiFocus(true, true)
    end
    cb('ok')
end)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if inCameraMode then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
        else
            Citizen.Wait(200)
        end
    end
end)
RegisterNUICallback('applyMod', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        cb('error')
        return
    end
    local category = data.category
    local modId = data.modId
    local value = data.value
    if category == 'performance' then
        vehicleMods.performance[modId] = value
    elseif category == 'visual' then
        vehicleMods.visual[modId] = value
    elseif category == 'colors' then
        if data.type == 'primary' then
            vehicleMods.colors.primary = value
        elseif data.type == 'secondary' then
            vehicleMods.colors.secondary = value
        elseif data.type == 'pearlescent' then
            vehicleMods.colors.pearlescent = value
        elseif data.type == 'wheel' then
            vehicleMods.colors.wheel = value
        elseif data.type == 'dashboard' then
            vehicleMods.colors.dashboard = value
            SetVehicleDashboardColour(currentVehicle, value)
            return cb('ok')
        elseif data.type == 'interior' then
            vehicleMods.colors.interior = value
            SetVehicleInteriorColour(currentVehicle, value)
            return cb('ok')
        end
        SetVehicleColours(currentVehicle, vehicleMods.colors.primary, vehicleMods.colors.secondary)
        SetVehicleExtraColours(currentVehicle, vehicleMods.colors.pearlescent, vehicleMods.colors.wheel)
        return cb('ok')
    elseif category == 'wheels' then
        if not vehicleMods.wheels then
            vehicleMods.wheels = {}
        end
        if data.type == 'wheelType' then
            vehicleMods.wheels.type = value
        else
            vehicleMods.wheels.variation = value
        end
    elseif category == 'extras' then
        vehicleMods.extras[modId] = value
    elseif category == 'neons' then
        if modId == 'color' then
            vehicleMods.neons.color = value
            SetVehicleNeonLightsColour(currentVehicle, value.r, value.g, value.b)
        else
            vehicleMods.neons[modId] = value
            local idx = (modId == 'left') and 0 or (modId == 'right') and 1 or (modId == 'front') and 2 or 3
            SetVehicleNeonLightEnabled(currentVehicle, idx, value)
        end
        return cb('ok')
    elseif category == 'xenon' then
        if modId == 'enabled' then
            vehicleMods.xenon.enabled = value
            ToggleVehicleMod(currentVehicle, 22, value)
        elseif modId == 'color' then
            vehicleMods.xenon.color = value
            SetVehicleXenonLightsColour(currentVehicle, value)
        end
        return cb('ok')
    elseif category == 'windowtint' then
        vehicleMods.windowTint = value
        SetVehicleWindowTint(currentVehicle, value)
        return cb('ok')
    elseif category == 'tyresmoke' then
        if modId == 'color' then
            vehicleMods.tyresmoke.color = value
            SetVehicleTyreSmokeColor(currentVehicle, value.r, value.g, value.b)
        else
            vehicleMods.tyresmoke.enabled = value
            ToggleVehicleMod(currentVehicle, 20, value)
        end
        return cb('ok')
    end
    ApplyVehicleMods(currentVehicle, vehicleMods)
    cb('ok')
end)
RegisterNUICallback('getWheelVariations', function(data, cb)
    if not currentVehicle then
        cb({max = -1})
        return
    end
    local oldType = vehicleMods.wheels.type
    SetVehicleWheelType(currentVehicle, data.wheelType)
    local max = GetNumVehicleMods(currentVehicle, 23)
    SetVehicleWheelType(currentVehicle, oldType)
    cb({max = max})
end)
RegisterNUICallback('toggleDoor', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        return cb('error')
    end
    local doorId = tonumber(data.doorId)
    local isDoorOpen = GetVehicleDoorAngleRatio(currentVehicle, doorId) > 0.1
    if isDoorOpen then
        SetVehicleDoorShut(currentVehicle, doorId, false)
    else
        SetVehicleDoorOpen(currentVehicle, doorId, false, false)
    end
    cb('ok')
end)
RegisterNUICallback('applyHandling', function(data, cb)
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        cb('error')
        return
    end
    local handlingId = data.handlingId
    local value = data.value
    vehicleHandling[handlingId] = value
    ApplyVehicleHandling(currentVehicle, vehicleHandling)
    cb('ok')
end)
RegisterNUICallback('resetVehicle', function(data, cb)
    cb('ok')
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        return
    end
    Citizen.CreateThread(function()
        SetVehicleModKit(currentVehicle, 0)
        for _, perf in ipairs(Config.Performance) do
            if perf.modType == 18 then
                ToggleVehicleMod(currentVehicle, perf.modType, false)
            else
                RemoveVehicleMod(currentVehicle, perf.modType)
            end
        end
        for _, vis in ipairs(Config.Visual) do
            RemoveVehicleMod(currentVehicle, vis.modType)
        end
        for i = 0, 20 do
            if DoesExtraExist(currentVehicle, i) then
                SetVehicleExtra(currentVehicle, i, false)
            end
        end
        vehicleHandling = GetVehicleHandling(currentVehicle)
        ApplyVehicleHandling(currentVehicle, vehicleHandling)
        vehicleMods = GetVehicleMods(currentVehicle)
        SendNUIMessage({
            action = 'refreshData',
            mods = vehicleMods,
            handling = vehicleHandling
        })
    end)
end)
RegisterNUICallback('washVehicle', function(data, cb)
    cb('ok')
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        return
    end
    SetVehicleDirtLevel(currentVehicle, 0.0)
    Citizen.CreateThread(function()
        WashDecalsFromVehicle(currentVehicle, 1.0)
    end)
end)
RegisterNUICallback('repairVehicle', function(data, cb)
    cb('ok')
    if not currentVehicle or not DoesEntityExist(currentVehicle) then
        return
    end
    Citizen.CreateThread(function()
        SetVehicleFixed(currentVehicle)
        SetVehicleDeformationFixed(currentVehicle)
        SetVehicleUndriveable(currentVehicle, false)
        SetVehicleEngineHealth(currentVehicle, 1000.0)
        SetVehiclePetrolTankHealth(currentVehicle, 1000.0)
        SetVehicleBodyHealth(currentVehicle, 1000.0)
    end)
end)
Citizen.CreateThread(function()
    if Config.EnableMechanicLocations then
        for _, loc in ipairs(Config.MechanicLocations) do
            if loc.enabled ~= false and loc.blipEnabled then
                local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
                SetBlipSprite(blip, loc.blipSprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, loc.blipScale)
                SetBlipColour(blip, loc.blipColor)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(loc.blipName)
                EndTextCommandSetBlipName(blip)
            end
        end
    end
end)
Citizen.CreateThread(function()
    while true do
        local wait = 500
        if Config.EnableMechanicLocations then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local pCoords = GetEntityCoords(ped)
                for _, loc in ipairs(Config.MechanicLocations) do
                    if loc.enabled ~= false then
                        local dist = #(pCoords - loc.coords)
                        if dist < 20.0 then
                            wait = 0
                            DrawMarker(loc.markerType, loc.coords.x, loc.coords.y, loc.coords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, loc.markerSize.x, loc.markerSize.y, loc.markerSize.z, loc.markerColor.r, loc.markerColor.g, loc.markerColor.b, loc.markerColor.a, false, true, 2, false, nil, nil, false)
                            if dist < Config.InteractionDistance then
                                if not menuOpen then
                                    BeginTextCommandDisplayHelp('STRING')
                                    AddTextComponentSubstringPlayerName('Pressione ~b~E~w~ para abrir a oficina mecânica')
                                    EndTextCommandDisplayHelp(0, false, true, -1)
                                    if IsControlJustReleased(0, Config.MechanicKey) then
                                        OpenMechanic()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        Citizen.Wait(wait)
    end
end)
Citizen.CreateThread(function()
    while true do
        if menuOpen then
            Citizen.Wait(0)
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Pressione ~b~ESC~w~ para fechar')
            EndTextCommandDisplayHelp(0, false, true, -1)
        else
            Citizen.Wait(500)
        end
    end
end)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        if menuOpen then
            if not IsPlayerInVehicle() or currentVehicle ~= GetVehiclePedIsIn(PlayerPedId(), false) then
                CloseMechanic()
            end
        end
    end
end)
