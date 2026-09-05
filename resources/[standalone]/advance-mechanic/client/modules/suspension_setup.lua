local SuspensionSetup = {}

---@type table
local defaultValues = {
    frontHeight = 0.0,
    rearHeight = 0.0,
    stiffness = 50,
    frontCamber = 0.0,
    rearCamber = 0.0,
    frontToe = 0.0,
    rearToe = 0.0
}

local baseHandling = {}

---@param value any
---@param fallback number
---@return number
local function numberOr(value, fallback)
    local numeric = tonumber(value)
    if not numeric or numeric ~= numeric or numeric == math.huge or numeric == -math.huge then
        return fallback
    end
    return numeric
end

---@param data table|nil
---@return table
local function normalizeData(data)
    data = type(data) == 'table' and data or {}
    return {
        frontHeight = numberOr(data.frontHeight or data.front_height, defaultValues.frontHeight),
        rearHeight = numberOr(data.rearHeight or data.rear_height, defaultValues.rearHeight),
        stiffness = numberOr(data.stiffness, defaultValues.stiffness),
        frontCamber = numberOr(data.frontCamber or data.front_camber, defaultValues.frontCamber),
        rearCamber = numberOr(data.rearCamber or data.rear_camber, defaultValues.rearCamber),
        frontToe = numberOr(data.frontToe or data.front_toe, defaultValues.frontToe),
        rearToe = numberOr(data.rearToe or data.rear_toe, defaultValues.rearToe)
    }
end

---@param vehicle number
---@return table
local function getBaseHandling(vehicle)
    local cached = baseHandling[vehicle]
    local model = GetEntityModel(vehicle)
    if cached and cached.model == model then return cached end

    cached = {
        model = model,
        suspensionRaise = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionRaise'),
        suspensionForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce'),
        suspensionCompDamp = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionCompDamp'),
        suspensionReboundDamp = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionReboundDamp'),
        tractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax'),
        steeringLock = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock'),
        wheelOffsets = {
            GetVehicleWheelXOffset(vehicle, 0),
            GetVehicleWheelXOffset(vehicle, 1),
            GetVehicleWheelXOffset(vehicle, 2),
            GetVehicleWheelXOffset(vehicle, 3)
        }
    }
    baseHandling[vehicle] = cached
    return cached
end

---@param vehicle number
---@param data table
local function applyVisuals(vehicle, data)
    if not DoesEntityExist(vehicle) then return end

    local base = getBaseHandling(vehicle)

    local camberToOffset = 0.003
    SetVehicleWheelXOffset(vehicle, 0, base.wheelOffsets[1] - (data.frontCamber or 0) * camberToOffset)
    SetVehicleWheelXOffset(vehicle, 1, base.wheelOffsets[2] + (data.frontCamber or 0) * camberToOffset)
    SetVehicleWheelXOffset(vehicle, 2, base.wheelOffsets[3] - (data.rearCamber or 0) * camberToOffset)
    SetVehicleWheelXOffset(vehicle, 3, base.wheelOffsets[4] + (data.rearCamber or 0) * camberToOffset)

    local heightValue = ((data.frontHeight or 0) + (data.rearHeight or 0)) / 2
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionRaise', base.suspensionRaise + heightValue)
end

---@param vehicle number
---@param data table
local function applyHandling(vehicle, data)
    if not DoesEntityExist(vehicle) then return end

    local base = getBaseHandling(vehicle)
    local stiffnessFactor = 0.5 + ((data.stiffness or 50) / 100.0)

    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce', base.suspensionForce * stiffnessFactor)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionCompDamp', base.suspensionCompDamp * stiffnessFactor)
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionReboundDamp', base.suspensionReboundDamp * stiffnessFactor)

    local maxCamber = math.max(math.abs(data.frontCamber or 0), math.abs(data.rearCamber or 0))
    local tractionFactor = 1.0
    if maxCamber > 8 then
        local gripLoss = ((maxCamber - 8) / 7.0) * 0.2
        tractionFactor = 1.0 - gripLoss
    end
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', base.tractionCurveMax * tractionFactor)

    local avgToe = ((data.frontToe or 0) + (data.rearToe or 0)) / 2
    local toeFactor = 1.0
    if math.abs(avgToe) > 0.5 then
        toeFactor = 1.0 + (avgToe * 0.02)
    end
    SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', base.steeringLock * toeFactor)
end

---@param vehicle number
---@param data table
function SuspensionSetup.Apply(vehicle, data)
    data = normalizeData(data)
    applyVisuals(vehicle, data)
    applyHandling(vehicle, data)
end

---@param vehicle number
function SuspensionSetup.Open(vehicle)
    if not Config.Suspension.enabled then return end
    if not DoesEntityExist(vehicle) then return end

    if Config.Suspension.requireLift then
        local vehicleState = Entity(vehicle).state
        if not vehicleState or not vehicleState.onLift then
            lib.notify({ title = locale('suspension_requires_lift'), type = 'error' })
            return
        end
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local currentData = lib.callback.await('mechanic:server:getSuspensionData', false, plate)

    local values = normalizeData(currentData)

    local ranges = Config.Suspension.ranges

    local options = {
        {
            title = locale('suspension_setup'),
            icon = 'fas fa-sliders-h',
            onSelect = function()
                local input = lib.inputDialog(locale('suspension_setup'), {
                    { type = 'slider', label = locale('suspension_front_height'), default = math.floor((values.frontHeight + 0.1) * 500), min = 0, max = 100, step = 1 },
                    { type = 'slider', label = locale('suspension_rear_height'), default = math.floor((values.rearHeight + 0.1) * 500), min = 0, max = 100, step = 1 },
                    { type = 'slider', label = locale('suspension_stiffness'), default = values.stiffness, min = ranges.stiffness.min, max = ranges.stiffness.max, step = 1 },
                    { type = 'slider', label = locale('suspension_front_camber'), default = math.floor(values.frontCamber + 15), min = 0, max = 30, step = 1 },
                    { type = 'slider', label = locale('suspension_rear_camber'), default = math.floor(values.rearCamber + 15), min = 0, max = 30, step = 1 },
                    { type = 'slider', label = locale('suspension_front_toe'), default = math.floor(values.frontToe + 5), min = 0, max = 10, step = 1 },
                    { type = 'slider', label = locale('suspension_rear_toe'), default = math.floor(values.rearToe + 5), min = 0, max = 10, step = 1 }
                })

                if not input then
                    lib.notify({ title = locale('suspension_cancelled'), type = 'info' })
                    return
                end

                local newData = {
                    frontHeight = (input[1] / 500) - 0.1,
                    rearHeight = (input[2] / 500) - 0.1,
                    stiffness = input[3],
                    frontCamber = input[4] - 15.0,
                    rearCamber = input[5] - 15.0,
                    frontToe = input[6] - 5.0,
                    rearToe = input[7] - 5.0
                }

                SuspensionSetup.Apply(vehicle, newData)

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local success = lib.callback.await('mechanic:server:applySuspension', false, netId, newData)

                if success then
                    lib.notify({ title = locale('suspension_applied'), type = 'success' })
                else
                    SuspensionSetup.Apply(vehicle, values)
                end
            end
        },
        {
            title = locale('suspension_load_preset'),
            icon = 'fas fa-download',
            onSelect = function()
                SuspensionSetup.LoadPresetMenu(vehicle)
            end
        },
        {
            title = locale('suspension_save_preset'),
            icon = 'fas fa-save',
            onSelect = function()
                SuspensionSetup.SavePresetMenu(vehicle, plate)
            end
        }
    }

    lib.registerContext({
        id = 'suspension_setup_menu',
        title = locale('suspension_setup'),
        options = options
    })

    lib.showContext('suspension_setup_menu')
end

function SuspensionSetup.LoadPresetMenu(vehicle)
    local shopId = lib.callback.await('mechanic:server:getPlayerShop', false)
    if not shopId then
        lib.notify({ title = locale('not_employed_at_shop'), type = 'error' })
        return
    end

    local presets = lib.callback.await('mechanic:server:getSuspensionPresets', false, shopId)
    if not presets or #presets == 0 then
        lib.notify({ title = locale('suspension_no_presets'), type = 'info' })
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local originalData = normalizeData(lib.callback.await('mechanic:server:getSuspensionData', false, plate))

    local options = {}
    for _, preset in ipairs(presets) do
        options[#options + 1] = {
            title = preset.name,
            icon = 'fas fa-cog',
            onSelect = function()
                SuspensionSetup.Apply(vehicle, preset.data)

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local success = lib.callback.await('mechanic:server:applySuspension', false, netId, preset.data)

                if success then
                    lib.notify({ title = locale('suspension_preset_loaded'), type = 'success' })
                else
                    SuspensionSetup.Apply(vehicle, originalData)
                end
            end
        }
    end

    lib.registerContext({
        id = 'suspension_presets_menu',
        title = locale('suspension_load_preset'),
        menu = 'suspension_setup_menu',
        options = options
    })

    lib.showContext('suspension_presets_menu')
end

function SuspensionSetup.SavePresetMenu(vehicle, plate)
    local shopId = lib.callback.await('mechanic:server:getPlayerShop', false)
    if not shopId then
        lib.notify({ title = locale('not_employed_at_shop'), type = 'error' })
        return
    end

    local input = lib.inputDialog(locale('suspension_save_preset'), {
        { type = 'input', label = locale('suspension_preset_name'), required = true, max = 50 }
    })

    if not input or not input[1] then return end

    local currentData = lib.callback.await('mechanic:server:getSuspensionData', false, plate)
    if not currentData then
        lib.notify({ title = locale('suspension_cancelled'), type = 'error' })
        return
    end

    local data = normalizeData(currentData)

    local success = lib.callback.await('mechanic:server:saveSuspensionPreset', false, shopId, input[1], data)

    if success then
        lib.notify({ title = locale('suspension_preset_saved'), type = 'success' })
    end
end

AddStateBagChangeHandler('suspensionData', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SuspensionSetup.Apply(entity, value)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for vehicle, base in pairs(baseHandling) do
        if DoesEntityExist(vehicle) then
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionRaise', base.suspensionRaise)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionForce', base.suspensionForce)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionCompDamp', base.suspensionCompDamp)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSuspensionReboundDamp', base.suspensionReboundDamp)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax', base.tractionCurveMax)
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock', base.steeringLock)
            for wheel = 0, 3 do
                SetVehicleWheelXOffset(vehicle, wheel, base.wheelOffsets[wheel + 1])
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(600000)
        for vehicle in pairs(baseHandling) do
            if not DoesEntityExist(vehicle) then baseHandling[vehicle] = nil end
        end
    end
end)

return SuspensionSetup
