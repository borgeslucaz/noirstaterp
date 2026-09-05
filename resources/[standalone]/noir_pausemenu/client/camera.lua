PauseCam = {}
PauseCam.active = false
PauseCam.cam = nil
PauseCam.orbitMode = false
PauseCam.angle = 0.0
PauseCam.distance = 0.0
PauseCam.height = 0.0

local function getPauseCameraParams(ped)
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false),
            Config.PauseCameraVehicleDistance,
            Config.PauseCameraVehicleHeight,
            Config.PauseCameraVehicleFov or Config.PauseCameraFov
    end

    return ped, Config.PauseCameraDistance, Config.PauseCameraHeight, Config.PauseCameraFov
end

local function getCamPosition(ped)
    local entity, distance, height = getPauseCameraParams(ped)
    local offset = GetOffsetFromEntityInWorldCoords(entity, 0.0, distance, height)
    return offset.x, offset.y, offset.z
end

local function getFocusDistance()
    if not PauseCam.cam then return Config.PauseCameraDistance end

    local ped = PlayerPedId()
    local camCoords = GetCamCoord(PauseCam.cam)
    local pedCoords = GetEntityCoords(ped)

    return #(camCoords - vector3(pedCoords.x, pedCoords.y, pedCoords.z + 0.5))
end

local function disableBlur()
    if not PauseCam.cam then return end

    SetCamUseShallowDofMode(PauseCam.cam, false)
    SetCamDofStrength(PauseCam.cam, 0.0)
    SetCamDofFocalLengthMultiplier(PauseCam.cam, 1.0)
    SetCamNearDof(PauseCam.cam, 0.0)
    SetCamFarDof(PauseCam.cam, 0.0)
end

local function maintainBlur()
    if not PauseCam.cam or not Config.PauseMenuBlur then return end

    local focusDist = getFocusDistance()
    local padding = Config.BlurFocusPadding

    SetCamUseShallowDofMode(PauseCam.cam, true)
    SetCamNearDof(PauseCam.cam, math.max(0.05, focusDist - padding))
    SetCamFarDof(PauseCam.cam, focusDist + padding)
    SetCamDofStrength(PauseCam.cam, Config.BlurStrength)
    SetCamDofFocalLengthMultiplier(PauseCam.cam, Config.BlurFocalMultiplier)
end

local function updateOrbitCamera()
    if not PauseCam.cam then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local rad = math.rad(PauseCam.angle)
    local x = coords.x + math.cos(rad) * PauseCam.distance
    local y = coords.y + math.sin(rad) * PauseCam.distance
    local z = coords.z + PauseCam.height

    SetCamCoord(PauseCam.cam, x, y, z)
    PointCamAtEntity(PauseCam.cam, ped, 0.0, 0.0, 0.25, true)
end

function PauseCam.Start()
    if PauseCam.active or Photomode.active then return end

    local ped = PlayerPedId()
    PauseCam.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    PauseCam.orbitMode = false

    local _, _, _, fov = getPauseCameraParams(ped)
    local x, y, z = getCamPosition(ped)
    SetCamCoord(PauseCam.cam, x, y, z)
    PointCamAtEntity(PauseCam.cam, ped, 0.0, 0.0, 0.25, true)
    SetCamFov(PauseCam.cam, fov)
    SetCamActive(PauseCam.cam, true)
    RenderScriptCams(true, true, Config.PauseCameraTransitionMs, true, false)

    PauseCam.active = true
    maintainBlur()

    CreateThread(function()
        while PauseCam.active and not Photomode.active do
            if PauseCam.cam then
                if PauseCam.orbitMode then
                    updateOrbitCamera()
                else
                    local currentPed = PlayerPedId()
                    local px, py, pz = getCamPosition(currentPed)
                    SetCamCoord(PauseCam.cam, px, py, pz)
                    PointCamAtEntity(PauseCam.cam, currentPed, 0.0, 0.0, 0.25, true)
                end

                maintainBlur()
            end
            Wait(Config.PauseCameraRefreshMs or 200)
        end
    end)
end

function PauseCam.StartFromPhotomode(cam, angle, distance, height)
    if PauseCam.active or not cam then return end

    PauseCam.cam = cam
    PauseCam.active = true
    PauseCam.orbitMode = true
    PauseCam.angle = angle
    PauseCam.distance = distance
    PauseCam.height = height

    SetCamFov(PauseCam.cam, Config.PauseCameraFov)
    SetCamActive(PauseCam.cam, true)
    updateOrbitCamera()
    maintainBlur()

    CreateThread(function()
        while PauseCam.active and not Photomode.active do
            if PauseCam.cam and PauseCam.orbitMode then
                updateOrbitCamera()
                maintainBlur()
            end
            Wait(Config.PauseCameraRefreshMs or 200)
        end
    end)
end

function PauseCam.Stop(transitionMs)
    if not PauseCam.active and not PauseCam.cam then return end

    PauseCam.active = false
    PauseCam.orbitMode = false
    local ms = transitionMs or Config.PauseCameraTransitionMs

    if PauseCam.cam then
        disableBlur()
    end

    RenderScriptCams(false, true, ms, true, false)

    if PauseCam.cam then
        DestroyCam(PauseCam.cam, false)
        PauseCam.cam = nil
    end
end

function PauseCam.HandoffToPhotomode()
    if not PauseCam.cam then
        return nil, nil, nil, nil
    end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local camCoords = GetCamCoord(PauseCam.cam)
    local dx = camCoords.x - pedCoords.x
    local dy = camCoords.y - pedCoords.y
    local angle = math.deg(math.atan(dy, dx))
    local distance = math.sqrt(dx * dx + dy * dy)
    local height = camCoords.z - pedCoords.z

    local cam = PauseCam.cam
    PauseCam.active = false
    PauseCam.orbitMode = false
    PauseCam.cam = nil

    return cam, angle, distance, height
end
