---Vigilância (cliente): radar, câmeras de segurança, tornozeleira e helicóptero.

local Config = require 'config.shared'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Layout = require 'client.layout'

local zones = {}
local function fail(result) Integrations.notify(Util.errorText(result and result.code), 'error') end

-- Radar ----------------------------------------------------------------------------
-- O cliente só avisa que passou pelo radar dirigindo. Velocidade e multa são
-- calculadas no servidor.

local radarPoints = {}

local function buildRadars()
    for _, point in ipairs(radarPoints) do point:remove() end
    radarPoints = {}
    if not Config.radars.enabled then return end
    for index, radar in ipairs(Layout.radars()) do
        local point = lib.points.new({ coords = radar.coords.xyz, distance = 25.0 })
        function point:onEnter()
            if cache.vehicle and cache.seat == -1 and GetVehicleClass(cache.vehicle) ~= 18 then
                TriggerServerEvent('noir_police:server:radar', index)
            end
        end
        radarPoints[#radarPoints + 1] = point
    end
end

buildRadars()

-- Câmeras de segurança -------------------------------------------------------------

local camera = { handle = 0, index = 0, offline = {} }

local function cameraText(index)
    local entry = Layout.cameras()[index]
    local status = camera.offline[index] and locale('camera.offline') or locale('camera.online')
    return ('%s  \n%02d:%02d · %s  \n%s'):format(entry.label, GetClockHours(), GetClockMinutes(), status,
        locale('camera.controls'))
end

local function closeCamera()
    if camera.handle ~= 0 then DestroyCam(camera.handle, false) end
    camera.handle, camera.index = 0, 0
    RenderScriptCams(false, false, 0, true, true)
    ClearTimecycleModifier()
    ClearFocus()
    FreezeEntityPosition(cache.ped, false)
    lib.hideTextUI()
end

local function showCamera(index)
    local entry = Layout.cameras()[index]
    if not entry then return end
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    if camera.handle ~= 0 then DestroyCam(camera.handle, false) end
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, entry.coords.x, entry.coords.y, entry.coords.z)
    SetCamRot(cam, entry.r.x, entry.r.y, entry.r.z, 2)
    SetFocusArea(entry.coords.x, entry.coords.y, entry.coords.z, 0.0, 0.0, 0.0)
    RenderScriptCams(true, false, 0, true, true)
    camera.handle, camera.index = cam, index
    FreezeEntityPosition(cache.ped, true)
    SetTimecycleModifier(camera.offline[index] and 'Broken_camera_fuzz' or 'scanline_cam_cheap')
    SetTimecycleModifierStrength(1.0)
    lib.showTextUI(cameraText(index), { position = 'top-center' })
    DoScreenFadeIn(250)

    CreateThread(function()
        while camera.index == index do
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                DoScreenFadeOut(250)
                while not IsScreenFadedOut() do Wait(0) end
                closeCamera()
                DoScreenFadeIn(250)
                break
            end
            if IsControlJustPressed(0, 175) then showCamera(index % #Layout.cameras() + 1) break end
            if IsControlJustPressed(0, 174) then showCamera((index - 2) % #Layout.cameras() + 1) break end
            if entry.canRotate then
                local rot = GetCamRot(cam, 2)
                if IsControlPressed(0, 32) and rot.x <= 0.0 then SetCamRot(cam, rot.x + 0.7, 0.0, rot.z, 2) end
                if IsControlPressed(0, 33) and rot.x >= -50.0 then SetCamRot(cam, rot.x - 0.7, 0.0, rot.z, 2) end
                if IsControlPressed(0, 34) then SetCamRot(cam, rot.x, 0.0, rot.z + 0.7, 2) end
                if IsControlPressed(0, 35) then SetCamRot(cam, rot.x, 0.0, rot.z - 0.7, 2) end
            end
            Wait(0)
        end
    end)
end

local function openCameras()
    local result = lib.callback.await('noir_police:server:cameraAccess', false)
    if not result or not result.ok then return fail(result) end
    camera.offline = {}
    for _, index in ipairs(result.offline or {}) do camera.offline[index] = true end
    local options = {}
    for index, entry in ipairs(Layout.cameras()) do
        options[#options + 1] = {
            title = entry.label,
            description = camera.offline[index] and locale('camera.offline') or nil,
            icon = 'fa-solid fa-video',
            onSelect = function() showCamera(index) end,
        }
    end
    lib.registerContext({ id = 'noir_police_cameras', title = locale('camera.title'), options = options })
    lib.showContext('noir_police_cameras')
end

local function buildDesks()
    for _, zone in ipairs(zones) do Integrations.removeZone(zone) end
    zones = {}
    for _, station in ipairs(Layout.stations()) do
        if station.cameras then
            zones[#zones + 1] = Integrations.addSphereZone({
                coords = station.cameras.coords,
                radius = station.cameras.radius,
                options = {
                    {
                        name = ('noir_police:cameras:%s'):format(station.id),
                        icon = 'fa-solid fa-video',
                        label = locale('target.cameras'),
                        canInteract = function()
                            local job = Integrations.getJob()
                            return Departments.can(job, 'cameras') and Departments.stationServes(station, job.name)
                        end,
                        onSelect = openCameras,
                    },
                },
            })
        end
    end
end

buildDesks()
AddEventHandler('noir_police:client:layoutChanged', function(kind)
    if kind == 'stations' then buildDesks() end
    if kind == 'radars' then buildRadars() end
end)

-- Tornozeleira ---------------------------------------------------------------------

RegisterNetEvent('noir_police:client:anklet', function(enabled)
    if source ~= 65535 then return end
    local ped = cache.ped
    if enabled then
        SetPedComponentVariation(ped, 7, 13, 0, 0)
    else
        Integrations.reloadSavedAppearance()
    end
end)

RegisterNetEvent('noir_police:client:ankletPing', function(coords, seconds)
    if source ~= 65535 or type(coords) ~= 'table' then return end
    PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 458)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('info.anklet_location'))
    EndTextCommandSetBlipName(blip)
    Integrations.notify(locale('info.anklet_location'), 'inform')
    SetTimeout((tonumber(seconds) or 60) * 1000, function() RemoveBlip(blip) end)
end)

-- Helicóptero: câmera e holofote ----------------------------------------------------

local heliModels = {}
for _, model in ipairs(Config.heli.models) do heliModels[model] = true end

local FOV_MAX, FOV_MIN, ZOOM_SPEED, TURN_SPEED = 80.0, 10.0, 2.0, 3.0
local heliCam, spotlight = false, false
local fov = (FOV_MAX + FOV_MIN) * 0.5
local vision = 0

local function cycleVision()
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    vision = (vision + 1) % 3
    SetNightvision(vision == 1)
    SetSeethrough(vision == 2)
end

local function vehicleInView(cam)
    local coords = GetCamCoord(cam)
    local rot = GetCamRot(cam, 2)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local direction = vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
    local target = coords + direction * 400.0
    local ray = StartShapeTestLosProbe(coords.x, coords.y, coords.z, target.x, target.y, target.z, 10, cache.vehicle, 0)
    local status, _, _, _, entity = GetShapeTestResult(ray)
    while status == 1 do
        Wait(0)
        status, _, _, _, entity = GetShapeTestResult(ray)
    end
    return entity and entity > 0 and IsEntityAVehicle(entity) and entity or nil
end

local function vehicleInfo(vehicle)
    local coords = GetEntityCoords(vehicle)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    return locale('heli.info', GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))),
        GetVehicleNumberPlateText(vehicle), math.ceil(GetEntitySpeed(vehicle) * 3.6), street)
end

local function runHeliCam()
    heliCam = true
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    SetTimecycleModifier('heliGunCam')
    SetTimecycleModifierStrength(0.3)
    local loaded, scaleform = pcall(lib.requestScaleformMovie, 'HELI_CAM', 3000)
    if not loaded then scaleform = nil end
    local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToEntity(cam, cache.vehicle, 0.0, 0.0, -1.5, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(cache.vehicle), 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)
    local locked, lastInfo = nil, 0
    -- O E que abriu a câmera ainda conta como "apertado" neste frame.
    Wait(0)

    while heliCam and cache.vehicle and not IsEntityDead(cache.ped) and GetEntityHeightAboveGround(cache.vehicle) > 1.5 do
        if IsControlJustPressed(0, Config.heli.cameraControl) then break end
        if IsControlJustPressed(0, 25) then cycleVision() end

        local zoom = (1.0 / (FOV_MAX - FOV_MIN)) * (fov - FOV_MIN)
        if locked and DoesEntityExist(locked) then
            PointCamAtEntity(cam, locked, 0.0, 0.0, 0.0, true)
            if GetGameTimer() - lastInfo > 500 then
                lastInfo = GetGameTimer()
                lib.showTextUI(vehicleInfo(locked), { position = 'top-center' })
            end
            if IsControlJustPressed(0, 22) then
                locked = nil
                StopCamPointing(cam)
                lib.hideTextUI()
            end
        else
            locked = nil
            local x, y = GetDisabledControlNormal(0, 220), GetDisabledControlNormal(0, 221)
            if x ~= 0.0 or y ~= 0.0 then
                local rot = GetCamRot(cam, 2)
                local factor = zoom + 0.1
                SetCamRot(cam, math.max(math.min(20.0, rot.x - y * TURN_SPEED * factor), -89.5), 0.0,
                    rot.z - x * TURN_SPEED * factor, 2)
            end
            if IsControlJustPressed(0, 22) then
                local vehicle = vehicleInView(cam)
                if vehicle then
                    locked = vehicle
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                end
            end
        end

        if IsControlJustPressed(0, 241) then fov = math.max(fov - ZOOM_SPEED, FOV_MIN) end
        if IsControlJustPressed(0, 242) then fov = math.min(fov + ZOOM_SPEED, FOV_MAX) end
        local current = GetCamFov(cam)
        SetCamFov(cam, current + (fov - current) * 0.05)

        HideHudAndRadarThisFrame()
        if scaleform then
            BeginScaleformMovieMethod(scaleform, 'SET_ALT_FOV_HEADING')
            ScaleformMovieMethodAddParamFloat(GetEntityCoords(cache.vehicle).z)
            ScaleformMovieMethodAddParamFloat(zoom)
            ScaleformMovieMethodAddParamFloat(GetCamRot(cam, 2).z)
            EndScaleformMovieMethod()
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        end
        Wait(0)
    end

    heliCam = false
    lib.hideTextUI()
    ClearTimecycleModifier()
    fov = (FOV_MAX + FOV_MIN) * 0.5
    RenderScriptCams(false, false, 0, true, false)
    if scaleform then SetScaleformMovieAsNoLongerNeeded(scaleform) end
    DestroyCam(cam, false)
    SetNightvision(false)
    SetSeethrough(false)
    vision = 0
end

lib.onCache('vehicle', function(vehicle)
    if not vehicle or not heliModels[GetEntityModel(vehicle)] then return end
    CreateThread(function()
        while cache.vehicle == vehicle do
            local job = Integrations.getJob()
            if Departments.isOnDutyPolice(job) then
                if IsControlJustPressed(0, Config.heli.cameraControl) and not heliCam and GetEntityHeightAboveGround(vehicle) > 1.5
                    and (cache.seat == 0 or cache.seat == 1 or cache.seat == 2) then
                    runHeliCam()
                end
                if IsControlJustPressed(0, Config.heli.spotlightControl) and (cache.seat == -1 or cache.seat == 0) then
                    spotlight = not spotlight
                    TriggerServerEvent('noir_police:server:heliSpotlight', spotlight)
                end
                if IsControlJustPressed(0, 154) and (cache.seat == 1 or cache.seat == 2)
                    and GetEntityHeightAboveGround(vehicle) > 1.5 then
                    TaskRappelFromHeli(cache.ped, 1)
                end
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('noir_police:client:heliSpotlight', function(netId, state)
    if source ~= 65535 then return end
    local vehicle = NetToVeh(netId)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then SetVehicleSearchlight(vehicle, state == true, false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if camera.handle ~= 0 then closeCamera() end
    heliCam = false
    for _, zone in ipairs(zones) do Integrations.removeZone(zone) end
    for _, point in ipairs(radarPoints) do point:remove() end
end)
