CharactersMenu = function()
    local option = GetPlayerCharactersArray()

    local resp = CreateCamScene(option[1])

    Wait(2000)
    Nuimessage('visible', true)
    Nuimessage('loadingscreen', false)
    Nuicontrol(true)
end


-- Cada preview ganha um número; só o mais recente pode deixar o ped visível. Sem isso, um
-- modelo que termina de carregar depois de o jogador já ter passado para o slot vazio
-- reaparecia.
local previewToken = 0

-- A tela é da troca enquanto uma transição escureceu e ainda não clareou; quem interrompe
-- uma troca no meio herda o escuro e é quem clareia no fim.
local transitionActive = false

---Invalida a troca em andamento sem clarear a tela. Para quem assume o fade dali em diante
---(entrar no jogo com um personagem).
CancelPreviewTransition = function()
    previewToken = previewToken + 1
    transitionActive = false
end

---@param character table
---@param data table
---@param transition? boolean escurece a tela durante a troca (só na troca de personagem; os
---outros fluxos que chamam isto já controlam o fade da tela)
CreateLocalPed = function(character, data, transition)
    previewToken = previewToken + 1
    local token = previewToken

    if transition and not transitionActive then
        transitionActive = true
        DoScreenFadeOut(240)
    end

    pcall( function ()

    -- Troca só com a tela já escura, para o jogador não ver o ped sumindo e reaparecendo.
    if transitionActive then
        while not IsScreenFadedOut() do
            if token ~= previewToken then return end
            Wait(0)
        end
    end

    -- Slot de novo personagem: cena sem ped. Ele fica posicionado e congelado, só invisível,
    -- porque a câmera da criação aponta para ele.
    if character.emptyslot then
        SetEntityVisible(PlayerPedId(), false)
        SetEntityCoords(PlayerPedId(), data.location.x, data.location.y, data.location.z, 0, 0, 0, false)
        SetEntityHeading(PlayerPedId(), data.location.w)
        FreezeEntityPosition(PlayerPedId(), true)
        ClearPedTasksImmediately(PlayerPedId())
        return
    end

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
    if token ~= previewToken then return end

    SetPlayerModel(cache.playerId, model)

    if skin then
        LoadSkin(skin)
    end

    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(PlayerPedId(), true)
    lib.requestAnimDict(data.dict, 25000)
    TaskPlayAnim(PlayerPedId(), data.dict, data.anim, -1, -1, -1, 1, 1, true, true, true)

    Wait(100)
    if token ~= previewToken then return end

    SetEntityVisible(PlayerPedId(), true)

    end)

    -- Clareia fora do pcall: se a troca der erro, a tela não fica presa no escuro. Só a troca
    -- mais recente clareia; as interrompidas deixam o escuro para ela.
    if transitionActive and token == previewToken then
        transitionActive = false
        DoScreenFadeIn(350)
    end

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
