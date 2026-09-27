-- Medico NPC: ambulancia e medico locais (sem rede), so o jogador atendido os ve. Nao ha
-- autoridade neles; cobranca e reanimacao sao decididas no servidor.
local config = require 'config.shared'

local CPR_DICT = 'mini@cpr@char_a@cpr_str'
local CPR_ANIM = 'cpr_pumpchest'

local Doctor = {}

---@type { run: integer, vehicle?: integer, ped?: integer, blip?: integer }?
local active
local runCounter = 0
---@type fun(stage: string, data?: table)
local report = function() end

local function notify(message, ntype)
    exports.bgrz_core:Notify(message, ntype or 'inform')
end

local function setBlip(entity, route)
    if active.blip and DoesBlipExist(active.blip) then RemoveBlip(active.blip) end
    active.blip = AddBlipForEntity(entity)
    SetBlipSprite(active.blip, 61)
    SetBlipColour(active.blip, 1)
    if route then
        SetBlipRoute(active.blip, true)
        SetBlipRouteColour(active.blip, 1)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip'))
    EndTextCommandSetBlipName(active.blip)
end

local function deleteEntities(vehicle, ped)
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end

---Encerra o atendimento. `leave` faz o medico voltar para a ambulancia e ir embora antes de sumir.
---@param leave? boolean
local function finish(leave)
    if not active then return end
    local vehicle, ped, blip = active.vehicle, active.ped, active.blip
    active = nil
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end

    if not leave or not ped or not DoesEntityExist(ped) or not vehicle or not DoesEntityExist(vehicle) then
        deleteEntities(vehicle, ped)
        return
    end

    CreateThread(function()
        ClearPedTasks(ped)
        TaskEnterVehicle(ped, vehicle, 10000, -1, 1.0, 1, 0)
        local deadline = GetGameTimer() + 10000
        while not IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do Wait(250) end
        TaskVehicleDriveWander(ped, vehicle, 15.0, 786603)
        Wait(15000)
        deleteEntities(vehicle, ped)
    end)
end

---@param run integer
local function isCurrent(run)
    return active ~= nil and active.run == run
end

---@param run integer
---@param reason string
local function fail(run, reason)
    if not isCurrent(run) then return end
    TriggerServerEvent('noir_handledeath:server:doctorCancel')
    finish(true)
    report('failed', { reason = reason })
end

---@param origin vector3
---@param radius number
---@return vector3? position
---@return number? heading
local function roadNear(origin, radius)
    local angle = math.random() * 2 * math.pi
    local x, y = origin.x + math.cos(angle) * radius, origin.y + math.sin(angle) * radius
    local found, position, heading = GetClosestVehicleNodeWithHeading(x, y, origin.z, 1, 3.0, 0)
    if not found then return nil end
    return position, heading
end

---@param model string
---@return integer? hash
local function loadModel(model)
    local ok, hash = pcall(lib.requestModel, model, 10000)
    return ok and hash or nil
end

---@param run integer
local function driveToPlayer(run)
    local vehicle, ped = active.vehicle, active.ped
    local target = GetEntityCoords(cache.ped)
    TaskVehicleDriveToCoordLongrange(ped, vehicle, target.x, target.y, target.z, config.driveSpeed, 787004, 10.0)

    local deadline = GetGameTimer() + config.arriveTimeout
    while isCurrent(run) and #(GetEntityCoords(vehicle) - GetEntityCoords(cache.ped)) > 15.0 do
        if GetGameTimer() > deadline then
            local position, heading = roadNear(GetEntityCoords(cache.ped), 0.0)
            if position then
                SetEntityCoords(vehicle, position.x, position.y, position.z, false, false, false, false)
                SetEntityHeading(vehicle, heading)
            end
            break
        end
        Wait(500)
    end
end

---@param run integer
local function walkToPlayer(run)
    local vehicle, ped = active.vehicle, active.ped
    SetVehicleSiren(vehicle, false)
    TaskVehicleTempAction(ped, vehicle, 27, 2000)
    Wait(1000)
    TaskLeaveVehicle(ped, vehicle, 0)

    local deadline = GetGameTimer() + 5000
    while isCurrent(run) and IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < deadline do Wait(100) end
    if not isCurrent(run) then return end

    setBlip(ped, false)
    report('walking')

    deadline = GetGameTimer() + config.walkTimeout
    local nextTask = 0
    while isCurrent(run) and #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) > 1.8 do
        if GetGameTimer() > deadline then
            local side = GetOffsetFromEntityInWorldCoords(cache.ped, 1.0, 0.0, 0.0)
            SetEntityCoords(ped, side.x, side.y, side.z - 1.0, false, false, false, false)
            break
        end
        -- Refaz a tarefa quando ele trava (porta, calcada, outro ped no caminho).
        if GetGameTimer() > nextTask and GetEntitySpeed(ped) < 0.5 then
            local target = GetEntityCoords(cache.ped)
            TaskGoToCoordAnyMeans(ped, target.x, target.y, target.z, 2.0, 0, false, 786603, 0xbf800000)
            nextTask = GetGameTimer() + 2000
        end
        Wait(250)
    end
end

---@param run integer
local function treat(run)
    local ped = active.ped
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, cache.ped, 1000)
    Wait(1000)
    if not isCurrent(run) then return end

    TriggerServerEvent('noir_handledeath:server:doctorArrived')
    lib.requestAnimDict(CPR_DICT)
    TaskPlayAnim(ped, CPR_DICT, CPR_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)
    report('treating', { duration = config.reviveTime })

    local deadline = GetGameTimer() + config.reviveTime
    while isCurrent(run) and GetGameTimer() < deadline do Wait(250) end
    RemoveAnimDict(CPR_DICT)
    if not isCurrent(run) then return end

    -- Sem checar isCurrent depois daqui: a propria reanimacao derruba o isDead, e a tela pode
    -- encerrar o atendimento antes de a resposta chegar.
    local ok, result = lib.callback.await('noir_handledeath:server:doctorFinish', false)
    finish(true)
    if ok then
        notify(locale('revived', result), 'success')
        report('done')
    else
        report('failed', { reason = result or 'failed' })
    end
end

---@param run integer
local function dispatch(run)
    local vehicleHash = loadModel(config.vehicleModel)
    local pedHash = loadModel(config.pedModel)
    if not isCurrent(run) then return end
    if not vehicleHash or not pedHash then return fail(run, 'unavailable') end

    local position, heading = roadNear(GetEntityCoords(cache.ped), config.spawnDistance)
    if not position then
        SetModelAsNoLongerNeeded(vehicleHash)
        SetModelAsNoLongerNeeded(pedHash)
        return fail(run, 'no_road')
    end

    local vehicle = CreateVehicle(vehicleHash, position.x, position.y, position.z, heading, false, false)
    local ped = CreatePedInsideVehicle(vehicle, 26, pedHash, -1, false, false)
    SetModelAsNoLongerNeeded(vehicleHash)
    SetModelAsNoLongerNeeded(pedHash)
    active.vehicle, active.ped = vehicle, ped

    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, config.plate)
    SetVehicleEngineOn(vehicle, true, true, false)
    if config.useSiren then SetVehicleSiren(vehicle, true) end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedCanRagdoll(ped, false)
    setBlip(vehicle, true)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)

    driveToPlayer(run)
    if not isCurrent(run) then return end
    walkToPlayer(run)
    if not isCurrent(run) then return end
    treat(run)
end

---@param reporter fun(stage: string, data?: table) recebe 'enroute', 'walking', 'treating', 'done', 'failed'
function Doctor.setReporter(reporter)
    report = reporter
end

---@return boolean
function Doctor.isActive()
    return active ~= nil
end

---Pede o medico ao servidor e, se aceito, comeca o atendimento.
---@return boolean ok
---@return string? reason codigo de erro (locales error.*)
function Doctor.call()
    if active then return false, 'already_called' end

    local ok, reason = lib.callback.await('noir_handledeath:server:callDoctor', false)
    if not ok then return false, reason or 'unavailable' end
    if active then return false, 'already_called' end

    runCounter += 1
    local run = runCounter
    active = { run = run }
    report('enroute')
    CreateThread(function() dispatch(run) end)
    return true
end

---Encerra sem cobranca (levantou por outro caminho). `leave` manda o medico embora andando.
---@param leave? boolean
function Doctor.abort(leave)
    if not active then return end
    finish(leave)
    report('idle')
end

return Doctor
