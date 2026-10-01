---Uma viagem: o jogador vira para a porta, a porta fecha, a câmera fica presa nela tremendo
---e o contador anda de andar em andar. No meio do caminho, com a porta "fechada", troca de
---andar numa piscada curta; o destino é a mesma porta no mesmo enquadramento.

local config = require 'config.client'

local Travel = {}

---@type integer?
local cam = nil
local active = false

---Rastro de cada passo no F8/CitizenFX.log, para achar o passo que derruba o cliente.
local function trace(step, ...)
    if not config.trace then return end
    print(('[noir_elevator] %d %s'):format(GetGameTimer(), step:format(...)))
end


local function playDoorSound(name)
    PlaySoundFrontend(-1, name, config.sounds.set, true)
end

---Câmera travada nos olhos do jogador, olhando a porta à frente dele.
---@param ped integer
local function placeCam(ped)
    local from = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.12, 0.65)
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.6)
    SetCamCoord(cam, from.x, from.y, from.z)
    PointCamAtCoord(cam, at.x, at.y, at.z)
end

---Entra até o centro da cabine e vira para a porta. Sem bloquear se o caminho travar.
---@param ped integer
---@param coords vector4
---@param heading number
local function stepToDoor(ped, coords, heading)
    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, 1.0, 3000, heading, 0.05)
    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline and #(GetEntityCoords(ped) - coords.xyz) > 0.35 do
        Wait(50)
    end
    ClearPedTasks(ped)
    SetEntityHeading(ped, heading)
end

---Espera a colisão e, se for MLO/IPL, o interior do destino. Limitado por `loadTimeoutMs`.
---@param ped integer
---@param coords vector4
---@param needInterior boolean
---@return boolean ready
local function waitDestination(ped, coords, needInterior)
    local deadline = GetGameTimer() + config.loadTimeoutMs
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        local ready = HasCollisionLoadedAroundEntity(ped)
        if ready and needInterior then
            local interior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
            ready = interior ~= 0 and IsInteriorReady(interior)
        end
        if ready then return true end
        Wait(50)
    end
    return false
end

---@param ped integer
---@param stop NoirElevatorStop
---@param elevator NoirElevator
local function swapFloor(ped, stop, elevator)
    DoScreenFadeOut(config.swapFadeMs)
    local deadline = GetGameTimer() + config.swapFadeMs + 500
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end

    trace('swap: tela escura')
    local coords = stop.coords
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, coords.w)
    trace('swap: teleporte para %s', stop.label)

    if not waitDestination(ped, coords, elevator.waitInterior) then
        lib.print.warn(('destino %q não carregou em %d ms; soltando assim mesmo'):format(stop.label, config.loadTimeoutMs))
    end

    trace('swap: destino pronto, interior %d', GetInteriorAtCoords(coords.x, coords.y, coords.z))
    placeCam(ped)
    DoScreenFadeIn(config.swapFadeMs)
end

---@param elevator NoirElevator
---@param level integer
---@return string
local function labelOfLevel(elevator, level)
    for _, stop in ipairs(elevator.stops) do
        if stop.level == level then return stop.label end
    end
    return tostring(level)
end

local function blockControls()
    CreateThread(function()
        while active do
            DisableAllControlActions(0)
            -- A câmera está dentro da cabeça; sem isso o próprio corpo tapa a porta.
            SetEntityLocallyInvisible(PlayerPedId())
            EnableControlAction(0, 249, true) -- falar no rádio/voz
            Wait(0)
        end
    end)
end

---Volta tudo ao normal. Idempotente: serve para o fim da viagem e para o stop do resource.
function Travel.cleanup()
    active = false
    if cam then
        RenderScriptCams(false, true, 700, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
    lib.hideTextUI()
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(config.swapFadeMs) end
    FreezeEntityPosition(PlayerPedId(), false)
end

---@return boolean
function Travel.isActive()
    return active
end

---@param elevator NoirElevator
---@param from NoirElevatorStop
---@param to NoirElevatorStop
function Travel.run(elevator, from, to)
    if active then return end
    active = true

    local ped = PlayerPedId()
    trace('início %s -> %s', from.label, to.label)
    stepToDoor(ped, from.coords, from.coords.w)
    trace('na porta')
    FreezeEntityPosition(ped, true)
    blockControls()

    playDoorSound(config.sounds.close)
    trace('som fechar')
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    placeCam(ped)
    trace('câmera criada')
    ShakeCam(cam, 'HAND_SHAKE', config.shakeAmplitude)
    trace('câmera tremendo')
    RenderScriptCams(true, true, 700, true, false)
    trace('câmera ativa')
    Wait(700)

    local floors = math.abs(to.level - from.level)
    local direction = to.level > from.level and 1 or -1
    local arrow = direction > 0 and 'floor_up' or 'floor_down'
    local totalMs = math.max(elevator.minSeconds, floors * elevator.secondsPerFloor) * 1000
    local stepMs = math.floor(totalMs / (floors + 1))
    local swapAt = math.max(1, math.ceil(floors / 2))

    for i = 0, floors do
        if not active then return end
        if i == swapAt then swapFloor(ped, to, elevator) end
        local level = from.level + direction * i
        lib.showTextUI(locale(arrow, labelOfLevel(elevator, level)), { position = 'top-center' })
        trace('contador %d', level)
        Wait(stepMs)
    end

    if not active then return end
    playDoorSound(config.sounds.open)
    trace('som abrir')
    Travel.cleanup()
    trace('fim')
end

return Travel
