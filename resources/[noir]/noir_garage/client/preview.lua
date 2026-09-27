---Previa 3D do carro na tela da garagem (do rhd_garage). O carro da previa e so local (nao vai para
---a rede) e o jogador fica numa sessao solo enquanto olha.
GaragePreview = {}

local previewVehicle

local function deletePreviewVehicle()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        SetEntityAsMissionEntity(previewVehicle, true, true)
        DeleteEntity(previewVehicle)
    end
    previewVehicle = nil
end

---@param modelName string
---@param props table
---@param coords vector4
---@return boolean
function GaragePreview.show(modelName, props, coords)
    deletePreviewVehicle()

    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return false end
    if not pcall(lib.requestModel, model, 10000) then return false end

    NetworkStartSoloTutorialSession()
    SetPlayerInvincible(cache.playerId, true)
    SetEntityVisible(cache.ped, false, false)

    previewVehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if previewVehicle == 0 then
        previewVehicle = nil
        GaragePreview.hide()
        return false
    end

    SetEntityInvincible(previewVehicle, true)
    SetVehicleOnGroundProperly(previewVehicle)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    lib.setVehicleProperties(previewVehicle, props)

    GarageCam.create(previewVehicle, {
        radius = 6.0,
        minRadius = 3.0,
        maxRadius = 12.0,
    })
    SetNuiFocusKeepInput(true)
    return true
end

function GaragePreview.hide()
    GarageCam.destroy()
    deletePreviewVehicle()
    SetNuiFocusKeepInput(false)
    NetworkEndTutorialSession()
    SetPlayerInvincible(cache.playerId, false)
    SetEntityVisible(cache.ped, true, false)
end

---@return boolean
function GaragePreview.isActive()
    return previewVehicle ~= nil
end

---@return table?
function GaragePreview.getStats()
    Wait(500)
    local vehicle = previewVehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local fInitialDriveMaxFlatVel = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveMaxFlatVel')
    local fInitialDriveForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fInitialDriveForce')
    local fBrakeForce = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fBrakeForce')
    local fTractionCurveMax = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMax')
    local fTractionCurveMin = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fTractionCurveMin')
    local fSteeringLock = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fSteeringLock')

    local maxSpeedKMH = (fInitialDriveMaxFlatVel * 0.75) * 3.6

    local stats = {
        speed = math.floor((maxSpeedKMH / 530.0) * 100),
        acceleration = math.floor((fInitialDriveForce / 1.3) * 100),
        braking = math.floor((fBrakeForce / 2.0) * 100),
        handling = math.floor(((fSteeringLock / 42.0) * 0.7 + ((fTractionCurveMax + fTractionCurveMin) / 5.5) * 0.3) * 100),
        traction = math.floor((fTractionCurveMax / 3.0) * 100),
    }

    for k, v in pairs(stats) do
        stats[k] = math.min(100, math.max(0, v))
    end

    return stats
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not GaragePreview.isActive() then return end
    GaragePreview.hide()
end)
