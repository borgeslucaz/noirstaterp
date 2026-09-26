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

-- Prop da animação do preview (celular, cigarro). Local e anexado ao ped: sai com
-- DetachEntity + DeleteObject, nunca DeleteEntity — cada um desses já derrubou o cliente aqui.
local previewProp = nil

RemovePreviewProp = function()
    if previewProp and DoesEntityExist(previewProp) then
        DetachEntity(previewProp, true, false)
        DeleteObject(previewProp)
    end
    previewProp = nil
end

local lastAnimKey = {}

---Pose do preview. Cena com dict/anim próprios (sentado no sofá, piquenique) mantém a dela;
---as outras sorteiam uma das animações do noir_pausemenu pelo gênero, sem repetir a anterior.
local function pickAnimation(character, data)
    if data.dict and data.anim then
        return { dict = data.dict, anim = data.anim }
    end

    local gender = character.sex == false and 'female' or 'male'
    local pool = Config.Animations[gender] or {}
    local candidates = {}
    for i = 1, #pool do
        local entry = pool[i]
        if entry.dict .. '|' .. entry.anim ~= lastAnimKey[gender] and DoesAnimDictExist(entry.dict) then
            candidates[#candidates + 1] = entry
        end
    end
    if #candidates == 0 then
        for i = 1, #pool do
            if DoesAnimDictExist(pool[i].dict) then candidates[#candidates + 1] = pool[i] end
        end
    end
    if #candidates == 0 then return nil end

    local entry = candidates[math.random(1, #candidates)]
    lastAnimKey[gender] = entry.dict .. '|' .. entry.anim
    return entry
end

---Anexa o prop da animação, invisível: aparece junto com o ped.
local function attachPreviewProp(ped, entry, token)
    local preset = entry.prop and Config.AnimationPropPresets[entry.prop]
    if not preset then return end

    local hash = joaat(preset.model)
    -- Modelo ausente no build Enhanced derruba o cliente no render: confere antes de pedir.
    if not IsModelValid(hash) or not IsModelInCdimage(hash) then return end
    if not lib.requestModel(hash, 5000) then return end

    Wait(preset.delay or 500)
    if token ~= previewToken then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not prop or prop == 0 then return end

    SetEntityVisible(prop, false, false)
    SetEntityCollision(prop, false, false)
    SetEntityCompletelyDisableCollision(prop, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, preset.bone or 28422),
        preset.pos.x, preset.pos.y, preset.pos.z, preset.rot.x, preset.rot.y, preset.rot.z,
        true, true, false, true, 1, true)
    previewProp = prop
end

---@param character table
---@param data table
---@param transition? boolean escurece a tela durante a troca (só na troca de personagem; os
---outros fluxos que chamam isto já controlam o fade da tela)
---@param changeScene? boolean leva a cena para `data` no escuro antes de pôr o ped
CreateLocalPed = function(character, data, transition, changeScene)
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

    RemovePreviewProp()

    if changeScene and not MoveSceneTo(data, token) then return end

    -- location vem do /capturarcena (GetEntityCoords = centro do ped). SetEntityCoords trataria esse
    -- z como o chão e subiria o ped ~1 m (congelado, ele não cai); NoOffset põe o centro onde foi
    -- capturado.

    -- Slot de novo personagem: cena sem ped. Ele fica posicionado e congelado, só invisível,
    -- porque a câmera da criação aponta para ele.
    if character.emptyslot then
        SetEntityVisible(PlayerPedId(), false)
        SetEntityCoordsNoOffset(PlayerPedId(), data.location.x, data.location.y, data.location.z, false, false, false)
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

    SetEntityCoordsNoOffset(PlayerPedId(), data.location.x, data.location.y, data.location.z, false, false, false)
    SetEntityHeading(PlayerPedId(), data.location.w)


    lib.requestModel(model, 25000)
    if token ~= previewToken then return end

    SetPlayerModel(cache.playerId, model)

    if skin then
        LoadSkin(skin)
    end

    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(PlayerPedId(), true)

    local entry = pickAnimation(character, data)
    if entry and lib.requestAnimDict(entry.dict, 5000) then
        TaskPlayAnim(PlayerPedId(), entry.dict, entry.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        attachPreviewProp(PlayerPedId(), entry, token)
    end

    Wait(100)
    if token ~= previewToken then return end

    SetEntityVisible(PlayerPedId(), true)
    if previewProp then SetEntityVisible(previewProp, true, false) end

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

---Câmera viva: push-in lento na direção em que ela olha e um balanço leve de câmera na
---mão, em vez de ficar congelada. A criação de personagem sobrescreve com o próprio
---SetCamParams, então não precisa parar nada ao entrar nela.
---@param camera number
---@param data table cena atual
StartCinematicCamera = function(camera, data)
    local cfg = Config.CinematicCamera
    if not cfg or not cfg.enabled then return end

    if cfg.shake and cfg.shake > 0 then
        ShakeCam(camera, 'HAND_SHAKE', cfg.shake)
    end

    if cfg.pushDistance and cfg.pushDistance > 0 then
        local pitch, yaw = math.rad(data.camrotation.x), math.rad(data.camrotation.z)
        local forward = vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
        local target = data.camlocation + forward * cfg.pushDistance

        SetCamParams(camera, target.x, target.y, target.z,
            data.camrotation.x, data.camrotation.y, data.camrotation.z,
            data.fov - (cfg.fovDrop or 0), cfg.pushDuration or 20000, 0, 0, 2)
    end
end

-- Silencia o som do mundo (trânsito, pedestres, vento) enquanto a seleção está na tela. É a
-- audio scene que o GTA Online usa no placar; sons de interface continuam tocando.
local SILENT_SCENE = 'MP_LEADERBOARD_SCENE'

MuteSceneAudio = function()
    if Config.MuteScene and not IsAudioSceneActive(SILENT_SCENE) then
        StartAudioScene(SILENT_SCENE)
    end
end

UnmuteSceneAudio = function()
    if IsAudioSceneActive(SILENT_SCENE) then
        StopAudioScene(SILENT_SCENE)
    end
end

---Blur igual ao do noir_pausemenu (client/camera.lua): profundidade de campo focada no ped,
---faixa nítida de ±padding em volta dele, atualizada a cada 200 ms porque a câmera anda
---(push-in) e o ped troca. Para sozinho quando essa câmera deixa de existir.
StartSceneBlur = function(camera)
    local cfg = Config.SceneBlur
    if not cfg or not cfg.enabled then return end

    CreateThread(function()
        while DoesCamExist(camera) and cam == camera do
            local pedCoords = GetEntityCoords(PlayerPedId())
            local focus = #(GetCamCoord(camera) - vector3(pedCoords.x, pedCoords.y, pedCoords.z + 0.5))

            SetCamUseShallowDofMode(camera, true)
            SetCamNearDof(camera, math.max(0.05, focus - cfg.padding))
            SetCamFarDof(camera, focus + cfg.padding)
            SetCamDofStrength(camera, cfg.strength)
            SetCamDofFocalLengthMultiplier(camera, cfg.focalMultiplier)
            Wait(200)
        end
    end)
end

---Carro de enfeite da cena (ou nenhum). Apaga o da cena anterior.
SpawnPreviewVehicle = function(data)
    if DoesEntityExist(previewvehicle) then
        DeleteEntity(previewvehicle)
    end
    previewvehicle = nil
    if not data.vehicle then return end

    local vehicleModel = type(data.vehicle) == 'string' and joaat(data.vehicle) or data.vehicle
    if IsModelInCdimage(vehicleModel) and IsModelAVehicle(vehicleModel) then
        lib.requestModel(vehicleModel, 25000)
        previewvehicle = CreateVehicle(vehicleModel, data.vehiclelocation.x, data.vehiclelocation.y,
            data.vehiclelocation.z, data.vehiclelocation.w, false, false)
        SetModelAsNoLongerNeeded(vehicleModel)
    else
        print(('[noir_multichar] Ignoring invalid preview vehicle model: %s (hash 0x%08x)')
            :format(tostring(data.vehicle), vehicleModel & 0xffffffff))
    end
end

---Leva a cena já montada para outra, com a tela escura: clima, região carregada, carro e
---câmera. As cenas ficam longe umas das outras, então espera o mapa carregar (até 3 s) para
---não clarear com o chão sem textura.
---@return boolean concluiu (false se outra troca começou no meio)
MoveSceneTo = function(data, token)
    if Config.uniqueweathertime then
        SetOverrideWeather(data.weather)
        NetworkOverrideClockTime(data.time.hours, data.time.minutes, data.time.seconds)
    end

    local c = data.camlocation
    SetFocusPosAndVel(c.x, c.y, c.z, 0, 0, 0)
    NewLoadSceneStartSphere(c.x, c.y, c.z, 60.0, 0)
    local deadline = GetGameTimer() + 3000
    while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do
        if token ~= previewToken then
            NewLoadSceneStop()
            return false
        end
        Wait(0)
    end
    NewLoadSceneStop()

    SpawnPreviewVehicle(data)
    if token ~= previewToken then return false end

    -- Encaixa a câmera na cena nova (duração 0 cancela o push-in que estava em andamento) e
    -- recomeça o movimento de câmera viva a partir dela.
    StopCamShaking(cam, true)
    SetCamParams(cam, c.x, c.y, c.z, data.camrotation.x, data.camrotation.y, data.camrotation.z, data.fov, 0, 0, 0, 2)
    StartCinematicCamera(cam, data)
    return true
end

---@param character table
CreateCamScene = function(character)
    DisableWeatherSync()
    MuteSceneAudio()
    Wait(500)

    if DoesEntityExist(previewvehicle) then
        DeleteEntity(previewvehicle)
    end

    local data = PickRandomScene()

    if Config.uniqueweathertime then
    SetOverrideWeather(data.weather)
    NetworkOverrideClockTime(data.time.hours, data.time.minutes, data.time.seconds)
    end

    local previousCam = cam
    cam = CreateCameraWithParams('DEFAULT_SCRIPTED_CAMERA', data.camlocation.x, data.camlocation.y, data.camlocation.z,
        data.camrotation.x, data.camrotation.y, data.camrotation.z, data.fov, false, 0)

    SetFocusPosAndVel(data.camlocation.x, data.camlocation.y, data.camlocation.z, 0, 0, 0)

    SetTimecycleModifier('MIDDAY')
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Trocar de cena criava uma câmera nova e deixava a anterior viva. Destrói depois que a
    -- nova já está ativa, para não piscar a câmera do jogo no meio.
    if previousCam and previousCam ~= cam and DoesCamExist(previousCam) then
        DestroyCam(previousCam, false)
    end

    StartCinematicCamera(cam, data)
    StartSceneBlur(cam)



    Wait(1000)

    SpawnPreviewVehicle(data)


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
    UnmuteSceneAudio()
    RemovePreviewProp()
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
