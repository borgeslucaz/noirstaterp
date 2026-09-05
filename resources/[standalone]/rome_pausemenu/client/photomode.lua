Photomode = {}
Photomode.active = false
Photomode.cam = nil
Photomode.angle = 0.0
Photomode.targetAngle = 0.0
Photomode.distance = 0.0
Photomode.height = 0.0
Photomode.filterIndex = 0
Photomode.blurEnabled = false
Photomode.animFrom = 0.0
Photomode.animTo = 0.0
Photomode.animStart = 0
Photomode.animating = false

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function getFilterName(index)
    if index <= 0 then
        return Locales[Config.Locale].none
    end
    return Config.CameraFilters[index] or Locales[Config.Locale].none
end

local function sendBlurState()
    SendNUIMessage({
        action = 'updateBlur',
        data = { enabled = Photomode.blurEnabled },
    })
end

local function getFocusDistance()
    if not Photomode.cam then return Photomode.distance end

    local ped = PlayerPedId()
    local camCoords = GetCamCoord(Photomode.cam)
    local pedCoords = GetEntityCoords(ped)

    return #(camCoords - vector3(pedCoords.x, pedCoords.y, pedCoords.z + 0.5))
end

local function disableBlur()
    if not Photomode.cam then return end

    SetCamUseShallowDofMode(Photomode.cam, false)
    SetCamDofStrength(Photomode.cam, 0.0)
    SetCamDofFocalLengthMultiplier(Photomode.cam, 1.0)
    SetCamNearDof(Photomode.cam, 0.0)
    SetCamFarDof(Photomode.cam, 0.0)
end

local function maintainBlur()
    if not Photomode.cam or not Photomode.blurEnabled then return end

    local focusDist = getFocusDistance()
    local padding = Config.BlurFocusPadding

    SetCamUseShallowDofMode(Photomode.cam, true)
    SetCamNearDof(Photomode.cam, math.max(0.05, focusDist - padding))
    SetCamFarDof(Photomode.cam, focusDist + padding)
    SetCamDofStrength(Photomode.cam, Config.BlurStrength)
    SetCamDofFocalLengthMultiplier(Photomode.cam, Config.BlurFocalMultiplier)
end

local function applyBlur()
    if not Photomode.cam then return end

    if Photomode.blurEnabled then
        maintainBlur()
    else
        disableBlur()
    end

    sendBlurState()
end

local function applyFilter()
    if Photomode.filterIndex <= 0 then
        ClearTimecycleModifier()
    else
        local name = Config.CameraFilters[Photomode.filterIndex]
        if name then
            SetTimecycleModifier(name)
            SetTimecycleModifierStrength(1.0)
        end
    end

    SendNUIMessage({
        action = 'updateFilter',
        data = {
            index = Photomode.filterIndex,
            name = getFilterName(Photomode.filterIndex),
            total = #Config.CameraFilters,
        },
    })
end

local function updateCamera()
    if not Photomode.cam then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local rad = math.rad(Photomode.angle)
    local x = coords.x + math.cos(rad) * Photomode.distance
    local y = coords.y + math.sin(rad) * Photomode.distance
    local z = coords.z + Photomode.height

    SetCamCoord(Photomode.cam, x, y, z)
    PointCamAtEntity(Photomode.cam, ped, 0.0, 0.0, 0.25, true)
end

local function easeOutCubic(t)
    return 1.0 - ((1.0 - t) ^ 3)
end

local function getPauseCameraParams(ped)
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false),
            Config.PauseCameraVehicleDistance,
            Config.PauseCameraVehicleHeight,
            Config.PauseCameraVehicleFov or Config.PauseCameraFov
    end

    return ped, Config.PauseCameraDistance, Config.PauseCameraHeight, Config.PauseCameraFov
end

local function initCameraFromPed()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local entity, distance, height, fov = getPauseCameraParams(ped)
    local offset = GetOffsetFromEntityInWorldCoords(entity, 0.0, distance, height)
    local dx = offset.x - pedCoords.x
    local dy = offset.y - pedCoords.y

    Photomode.angle = math.deg(math.atan(dy, dx))
    Photomode.targetAngle = Photomode.angle
    Photomode.distance = math.sqrt(dx * dx + dy * dy)
    Photomode.height = offset.z - pedCoords.z

    Photomode.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(Photomode.cam, fov)
    SetCamCoord(Photomode.cam, offset.x, offset.y, offset.z)
    PointCamAtEntity(Photomode.cam, ped, 0.0, 0.0, 0.25, true)
    RenderScriptCams(true, true, 600, true, false)
end

local function invokePhotomodeEnter()
    if Config.HideRadarOnPhotomode then
        DisplayRadar(false)
    end

    if Config.OnPhotomodeEnter then
        Config.OnPhotomodeEnter()
    end
end

local function invokePhotomodeExit()
    if Config.OnPhotomodeExit then
        Config.OnPhotomodeExit()
    end

    if Config.HideRadarOnPhotomode and not PauseMenu.open and not PauseMenu.photomodeReturn then
        DisplayRadar(true)
    end
end

function Photomode.Start()
    if Photomode.active then return end

    Photomode.active = true
    Photomode.filterIndex = 0
    Photomode.blurEnabled = Config.PhotomodeBlur
    Photomode.animating = false

    local handoffCam, handoffAngle, handoffDistance, handoffHeight = PauseCam.HandoffToPhotomode()

    if handoffCam then
        Photomode.cam = handoffCam
        Photomode.angle = handoffAngle
        Photomode.targetAngle = handoffAngle
        Photomode.distance = handoffDistance
        Photomode.height = handoffHeight
    else
        initCameraFromPed()
    end

    applyBlur()
    applyFilter()
    invokePhotomodeEnter()

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'route', data = 'photomode' })

    CreateThread(function()
        while Photomode.active do
            if Photomode.animating then
                local elapsed = GetGameTimer() - Photomode.animStart
                local duration = Config.CameraRotateDurationMs
                local progress = math.min(1.0, elapsed / duration)
                local eased = easeOutCubic(progress)

                Photomode.angle = Photomode.animFrom + (Photomode.animTo - Photomode.animFrom) * eased

                if progress >= 1.0 then
                    Photomode.angle = Photomode.animTo
                    Photomode.targetAngle = Photomode.animTo
                    Photomode.animating = false
                end
            end

            updateCamera()

            if Photomode.blurEnabled then
                maintainBlur()
            else
                disableBlur()
            end

            Wait(0)
        end
    end)
end

local function releaseCamera(keepRendered)
    if not Photomode.cam then return nil end

    disableBlur()

    local cam = Photomode.cam
    Photomode.cam = nil

    if not keepRendered then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(cam, false)
        cam = nil
    end

    return cam
end

function Photomode.Stop()
    if not Photomode.active then return end

    Photomode.active = false
    Photomode.animating = false

    ClearTimecycleModifier()
    releaseCamera(false)
    invokePhotomodeExit()
end

function Photomode.Rotate(direction)
    local step = Config.RotateStep
    local newTarget = Photomode.targetAngle + (direction == 'left' and -step or step)

    Photomode.animFrom = Photomode.angle
    Photomode.animTo = newTarget
    Photomode.targetAngle = newTarget
    Photomode.animStart = GetGameTimer()
    Photomode.animating = true
end

function Photomode.ApplyDrag(deltaX, deltaY)
    if not Photomode.active then return end

    Photomode.animating = false
    Photomode.angle = Photomode.angle + (deltaX * Config.PhotomodeDragSensitivity)
    Photomode.targetAngle = Photomode.angle
    Photomode.height = clamp(
        Photomode.height - (deltaY * Config.PhotomodeHeightSensitivity),
        Config.PhotomodeMinHeight,
        Config.PhotomodeMaxHeight
    )
end

function Photomode.ApplyZoom(delta)
    if not Photomode.active then return end

    Photomode.distance = clamp(
        Photomode.distance - (delta * Config.PhotomodeZoomSpeed),
        Config.PhotomodeMinDistance,
        Config.PhotomodeMaxDistance
    )
end

function Photomode.ToggleBlur()
    Photomode.blurEnabled = not Photomode.blurEnabled
    applyBlur()
end

function Photomode.CycleFilter(direction)
    local total = #Config.CameraFilters
    if total == 0 then return end

    if direction == 'prev' then
        Photomode.filterIndex = Photomode.filterIndex - 1
        if Photomode.filterIndex < 0 then
            Photomode.filterIndex = total
        end
    else
        Photomode.filterIndex = Photomode.filterIndex + 1
        if Photomode.filterIndex > total then
            Photomode.filterIndex = 0
        end
    end

    applyFilter()
end

function Photomode.SetFilterIndex(index)
    local total = #Config.CameraFilters
    local value = math.floor(tonumber(index) or 0)

    if value <= 0 then
        Photomode.filterIndex = 0
    elseif value > total then
        Photomode.filterIndex = total
    else
        Photomode.filterIndex = value
    end

    applyFilter()
end

function Photomode.ExitToPauseMenu()
    if not Photomode.active then return end

    PauseMenu.photomodeReturn = true

    local angle = Photomode.angle
    local distance = Photomode.distance
    local height = Photomode.height

    Photomode.active = false
    Photomode.animating = false

    ClearTimecycleModifier()

    local cam = releaseCamera(true)
    invokePhotomodeExit()

    PauseMenu.OpenFromPhotomode(cam, angle, distance, height)
end

exports('IsPhotomodeActive', function()
    return Photomode.active
end)
