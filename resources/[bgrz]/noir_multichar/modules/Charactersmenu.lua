CharactersMenu = function()
    local option = GetPlayerCharactersArray()

    local resp = CreateCamScene(option[1])

    Wait(2000)
    Nuimessage('visible', true)
    Nuimessage('loadingscreen', false)
    Nuicontrol(true)
end


---@param character table
---@param data table
CreateLocalPed = function(character, data)

    pcall( function ()
        
    local model, skin = GetPlayerSkin(character)

    local cm = model
    if type(cm) == 'string' then
        if tonumber(cm) then
            model = tonumber(cm)
        end
    end

    SetEntityVisible(PlayerPedId(), false)

    SetEntityCoords(PlayerPedId(), data.location.x, data.location.y, data.location.z, 0, 0, 0, false)
    SetEntityHeading(PlayerPedId(), data.location.w)


    lib.requestModel(model, 25000)

    SetPlayerModel(cache.playerId, model)

    if skin then
        LoadSkin(skin)
    end

    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(PlayerPedId(), true)
    lib.requestAnimDict(data.dict, 25000)
    TaskPlayAnim(PlayerPedId(), data.dict, data.anim, -1, -1, -1, 1, 1, true, true, true)

    Wait(100)
    SetEntityVisible(PlayerPedId(), true)

    end)

    return true
end


cazm = nil
previewvehicle = nil

---@param character table
CreateCamScene = function(character)
    DisableWeatherSync()
    Wait(500)

    if DoesEntityExist(previewvehicle) then
        DeleteEntity(previewvehicle)
    end

    local data = GetCurrentScene()

    if Config.uniqueweathertime then
    SetOverrideWeather(data.weather)
    NetworkOverrideClockTime(data.time.hours, data.time.minutes, data.time.seconds)
    end

    cam = CreateCameraWithParams('DEFAULT_SCRIPTED_CAMERA', data.camlocation.x, data.camlocation.y, data.camlocation.z,
        data.camrotation.x, data.camrotation.y, data.camrotation.z, data.fov, false, 0)

    SetFocusPosAndVel(data.camlocation.x, data.camlocation.y, data.camlocation.z, 0, 0, 0)

    SetTimecycleModifier('MIDDAY')
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, 0.4)
    SetCamFarDof(cam, 1.8)
    SetCamDofStrength(cam, 0.7)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)



    Wait(1000)

    if data.vehicle then
        local vehicleModel = type(data.vehicle) == 'string' and joaat(data.vehicle) or data.vehicle

        if IsModelInCdimage(vehicleModel) and IsModelAVehicle(vehicleModel) then
            lib.requestModel(vehicleModel, 25000)
            previewvehicle = CreateVehicle(vehicleModel, data.vehiclelocation.x, data.vehiclelocation.y,
                data.vehiclelocation.z,
                data.vehiclelocation.w, false, false)
            SetModelAsNoLongerNeeded(vehicleModel)
        else
            print(('[afterlife_ivmulticharacter2] Ignoring invalid preview vehicle model: %s (hash 0x%08x)')
                :format(tostring(data.vehicle), vehicleModel & 0xffffffff))
        end
    end


    CreateLocalPed(character, data)

    Wait(2000)
    -- CreateThread(function()
    --     while DoesCamExist(cam) do
    --         SetUseHiDof()
    --         Wait(0)
    --     end
    -- end)
    return true
end


DeleteCamScene = function()
    ClearFocus()
    SetCamActive(cam, false)
    DestroyCam(cam, true)
    RenderScriptCams(false, false, 1, true, true)
    DeleteEntity(PlayerPedId())

    CreateThread(function()
        Wait(1000)
        if DoesEntityExist(previewvehicle) then
            DeleteEntity(previewvehicle)
        end
    end)
end
