---Rota de carga do lado do jogador: pilha de caixas, veículo, destino. Só apresentação —
---cada passo pergunta ao servidor, que confere fase, distância e veículo.

local Config = require 'config.shared'
local Integrations = require 'client.integrations'
local Carry = require 'client.carry'

local Haul = {}

local VEHICLE_OPTIONS = { 'noir_gathering:haul:load', 'noir_gathering:haul:unload' }

---@type { route: table, count: integer, loaded: integer, delivered: integer, phase: string, netId: integer?, blip: integer?, vehicleBlip: integer?, stackZone: integer?, dropZone: integer?, busy: boolean }?
local run = nil

local ERRORS = {
    busy = 'error_busy',
    already_active = 'error_already_active',
    not_allowed = 'error_not_allowed',
    locked = 'error_locked',
    too_far = 'error_too_far',
    route_busy = 'error_route_busy',
    spawn_blocked = 'error_spawn_blocked',
    spawn_failed = 'error_generic',
    wrong_vehicle = 'error_wrong_vehicle_haul',
    vehicle_far = 'error_vehicle_far',
    wrong_step = 'error_generic',
    too_soon = 'error_busy',
    inventory_full = 'error_inventory_full',
    route_changed = 'error_route_changed',
    vehicle_lost = 'error_vehicle_lost',
    expired = 'error_haul_expired',
    no_run = 'error_generic',
    provider_unavailable = 'error_generic',
}

local function notifyError(result)
    local code = result and result.error
    if code == 'route_cooldown' then
        return Integrations.notify(locale('error_route_cooldown', result.minutes or 1), 'error')
    end
    Integrations.notify(locale(ERRORS[code] or 'error_generic'), 'error')
end

local function toVector(point)
    return vector3(point.x, point.y, point.z)
end

-- Mapa ------------------------------------------------------------------------------------

local function clearBlip()
    if run and run.blip and DoesBlipExist(run.blip) then RemoveBlip(run.blip) end
    if run then run.blip = nil end
end

local function guideTo(point, label)
    clearBlip()
    local blip = AddBlipForCoord(point.x, point.y, point.z)
    SetBlipSprite(blip, Config.blip.sprite)
    SetBlipColour(blip, Config.blip.color)
    SetBlipScale(blip, Config.blip.scale)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    run.blip = blip
end

---Blip no veículo da rota, quando ela entregou um.
local function markVehicle()
    if not run.netId then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 10000
        while run and not NetworkDoesNetworkIdExist(run.netId) and GetGameTimer() < deadline do Wait(250) end
        if not run or not NetworkDoesNetworkIdExist(run.netId) then return end
        local blip = AddBlipForEntity(NetToVeh(run.netId))
        SetBlipSprite(blip, 67)
        SetBlipColour(blip, Config.blip.color)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(locale('blip_haul_vehicle'))
        EndTextCommandSetBlipName(blip)
        run.vehicleBlip = blip
    end)
end

-- Pilha -----------------------------------------------------------------------------------

local function removeStack()
    Integrations.removeZone(run.stackZone)
    run.stackZone = nil
end

---A pilha em si é cenário, visto por todos (`client/scenery.lua`). Aqui é só o alvo, uma
---esfera no lugar dela, para quem está fazendo a carga.
local function createStack()
    local stack = run.route.haul.stack
    run.stackZone = Integrations.addZone({
        name = 'noir_gathering:haul:stack',
        coords = toVector(stack) + vector3(0.0, 0.0, 0.8),
        radius = Config.targetRadius,
        options = { {
            name = 'noir_gathering:haul:take',
            icon = 'fa-solid fa-box',
            label = locale('target_haul_take'),
            canInteract = function() return run ~= nil and run.phase == 'LOAD' and not run.busy and not Carry.isCarrying() end,
            onSelect = function() Haul.take() end,
        } },
    })
end

-- Destino ---------------------------------------------------------------------------------

local function createDropoff()
    run.dropZone = Integrations.addZone({
        name = 'noir_gathering:haul:drop',
        coords = toVector(run.route.haul.dropoff),
        radius = Config.targetRadius,
        options = {
            {
                name = 'noir_gathering:haul:drop',
                icon = 'fa-solid fa-dolly',
                label = locale('target_haul_drop'),
                canInteract = function() return run ~= nil and run.phase == 'UNLOAD' and not run.busy and Carry.isCarrying() end,
                onSelect = function() Haul.drop() end,
            },
            {
                name = 'noir_gathering:haul:pay',
                icon = 'fa-solid fa-sack-dollar',
                label = locale('target_haul_pay'),
                canInteract = function() return run ~= nil and run.phase == 'PAY' and not run.busy end,
                onSelect = function() Haul.collectPay() end,
            },
        },
    })
end

-- Veículo ---------------------------------------------------------------------------------

---@param label string
---@param anim? { dict: string, clip: string } animação durante a barra, conferida antes
local function progress(label, anim)
    local playing = anim and DoesAnimDictExist(anim.dict) and { dict = anim.dict, clip = anim.clip, flag = 0 } or nil
    if playing then Carry.suspend(true) end
    local completed = lib.progressBar({
        duration = Config.haul.loadMs,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = playing,
    })
    Carry.suspend(false)
    return completed
end

-- Portas de carga -------------------------------------------------------------------------

---Van (classe 12, como o burrito3) abre as duas portas traseiras; o resto abre o
---porta-malas. Se o veículo não tem as portas da regra, tenta as da outra.
---@param entity integer
---@return integer[]
local function cargoDoors(entity)
    local rear, trunk = { 2, 3 }, { 5 }
    local order = GetVehicleClass(entity) == 12 and { rear, trunk } or { trunk, rear }
    for _, doors in ipairs(order) do
        local valid = {}
        for _, door in ipairs(doors) do
            if GetIsDoorValid(entity, door) then valid[#valid + 1] = door end
        end
        if #valid > 0 then return valid end
    end
    return {}
end

---Porta de veículo de rede só obedece a quem tem o controle dele: pede antes, com prazo.
local function takeControl(entity)
    local deadline = GetGameTimer() + 500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
end

---Abre as portas de carga e as deixa abertas enquanto houver caixa entrando ou saindo.
local function openCargo(entity)
    takeControl(entity)
    for _, door in ipairs(cargoDoors(entity)) do
        if GetVehicleDoorAngleRatio(entity, door) < 0.1 then SetVehicleDoorOpen(entity, door, false, false) end
    end
    run.openVehicle = entity
end

local function closeCargo()
    local entity = run and run.openVehicle
    if not entity then return end
    run.openVehicle = nil
    if not DoesEntityExist(entity) then return end
    takeControl(entity)
    for _, door in ipairs(cargoDoors(entity)) do SetVehicleDoorShut(entity, door, false) end
end

local function addVehicleTarget()
    Integrations.addModelTarget(run.route.vehicle, {
        {
            name = VEHICLE_OPTIONS[1],
            icon = 'fa-solid fa-box-open',
            label = locale('target_haul_load'),
            canInteract = function() return run ~= nil and run.phase == 'LOAD' and not run.busy and Carry.isCarrying() end,
            onSelect = function(data) Haul.load(data.entity) end,
        },
        {
            name = VEHICLE_OPTIONS[2],
            icon = 'fa-solid fa-box',
            label = locale('target_haul_unload'),
            canInteract = function()
                return run ~= nil and run.phase == 'UNLOAD' and not run.busy and not Carry.isCarrying() and run.loaded > 0
            end,
            onSelect = function(data) Haul.unload(data.entity) end,
        },
    })
end

-- Ciclo -----------------------------------------------------------------------------------

local function cleanup()
    if not run then return end
    closeCargo()
    Carry.stop()
    clearBlip()
    if run.vehicleBlip and DoesBlipExist(run.vehicleBlip) then RemoveBlip(run.vehicleBlip) end
    removeStack()
    Integrations.removeZone(run.dropZone)
    Integrations.removeModelTarget(run.route.vehicle, VEHICLE_OPTIONS)
    run = nil
end

---@param action string callback do servidor
---@return table? result
local function ask(action, ...)
    run.busy = true
    local result = lib.callback.await('noir_gathering:server:' .. action, false, ...)
    -- O servidor pode ter encerrado a corrida enquanto a resposta vinha.
    if not run then return nil end
    run.busy = false
    if not result or not result.ok then
        notifyError(result)
        return nil
    end
    return result
end

---@return boolean
function Haul.isActive()
    return run ~= nil
end

---@param route table
function Haul.start(route)
    if run then return notifyError({ error = 'already_active' }) end
    local result = lib.callback.await('noir_gathering:server:haulStart', false, route.id)
    if not result or not result.ok then return notifyError(result) end

    run = { route = route, count = result.count, loaded = 0, delivered = 0, phase = 'LOAD',
        netId = result.netId, busy = false }
    createStack()
    addVehicleTarget()
    markVehicle()
    guideTo(route.haul.stack, locale('blip_haul_stack'))
    Integrations.notify(locale('haul_started', result.count, Config.stopKey), 'inform')
end

function Haul.take()
    if not run or not ask('haulTake') then return end
    Carry.start()
    Integrations.notify(locale('haul_carry_to_vehicle'), 'inform')
end

---@param entity integer veículo que o jogador mirou
function Haul.load(entity)
    if not run or not DoesEntityExist(entity) then return end
    openCargo(entity)
    if not progress(locale('progress_haul_load'), Config.haul.carry.load) then return end
    local result = ask('haulLoad', NetworkGetNetworkIdFromEntity(entity))
    if not result then return end
    Carry.stop()
    run.loaded = result.loaded
    if not result.full then
        return Integrations.notify(locale('haul_loaded', run.loaded, run.count), 'success')
    end

    -- Carga completa: fecha para viajar.
    closeCargo()
    run.phase = 'UNLOAD'
    removeStack()
    createDropoff()
    guideTo(run.route.haul.dropoff, locale('blip_haul_dropoff'))
    Integrations.notify(locale('haul_full'), 'success')
end

---@param entity integer
function Haul.unload(entity)
    if not run or not DoesEntityExist(entity) then return end
    openCargo(entity)
    if not progress(locale('progress_haul_unload')) then return end
    local result = ask('haulUnload', NetworkGetNetworkIdFromEntity(entity))
    if not result then return end
    run.loaded = result.loaded
    Carry.start()
    -- Última caixa fora: fecha.
    if run.loaded == 0 then closeCargo() end
end

function Haul.drop()
    if not run then return end
    if not progress(locale('progress_haul_drop')) then return end
    local result = ask('haulDrop')
    if not result then return end
    Carry.stop()
    run.delivered = result.delivered
    if result.finished then
        cleanup()
        return Integrations.notify(locale('haul_finished'), 'success')
    end
    if result.pending then
        run.phase = 'PAY'
        return Integrations.notify(locale('haul_pay_pending'), 'error')
    end
    Integrations.notify(locale('haul_delivered', run.delivered, run.count), 'success')
end

function Haul.collectPay()
    if not run or not ask('haulPay') then return end
    cleanup()
    Integrations.notify(locale('haul_finished'), 'success')
end

---Desistir perde a carga: pergunta antes.
function Haul.stop()
    if not run then return end
    local answer = lib.alertDialog({
        header = run.route.name,
        content = locale('haul_stop_confirm'),
        centered = true,
        cancel = true,
    })
    if answer ~= 'confirm' or not run then return end
    lib.callback.await('noir_gathering:server:haulStop', false)
    cleanup()
    Integrations.notify(locale('haul_stopped'), 'inform')
end

---O servidor encerrou a corrida (rota editada, veículo perdido, prazo).
---@param reason string
function Haul.ended(reason)
    if not run then return end
    cleanup()
    notifyError({ error = reason })
end

function Haul.reset()
    cleanup()
end

-- Motorista da entrega ----------------------------------------------------------------------

---@param entity integer
---@return boolean
local function control(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    return pcall(lib.waitFor, function()
        if NetworkHasControlOfEntity(entity) then return true end
    end, false, 1500)
end

---O servidor criou o motorista; aqui ele entra no veículo e sai dirigindo pela cidade.
---Quem apaga os dois depois é o servidor. Se ele não conseguir entrar, o servidor o põe no
---banco, e o laço abaixo ainda dá a ordem de dirigir.
---@param driverNet integer
---@param vehicleNet integer
function Haul.driveAway(driverNet, vehicleNet)
    CreateThread(function()
        local streamed = pcall(lib.waitFor, function()
            if NetworkDoesEntityExistWithNetworkId(driverNet) and NetworkDoesEntityExistWithNetworkId(vehicleNet) then
                return true
            end
        end, false, 6000)
        if not streamed then return end
        local driver, vehicle = NetToPed(driverNet), NetToVeh(vehicleNet)
        if not DoesEntityExist(driver) or not DoesEntityExist(vehicle) then return end

        control(driver)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetPedFleeAttributes(driver, 0, false)
        SetPedKeepTask(driver, true)
        if control(vehicle) then SetVehicleDoorsLocked(vehicle, 1) end
        TaskEnterVehicle(driver, vehicle, 20000, -1, 1.0, 1, 0)

        -- Espera o banco do MOTORISTA, não só estar dentro: com a porta dele obstruída o NPC
        -- entra pelo passageiro, e a ordem de dirigir dada dali se perde quando ele troca de
        -- banco. Entrou pelo lado errado: passa de banco. O servidor ainda o põe no banco se
        -- nada disso der certo a tempo.
        local deadline, shuffled = GetGameTimer() + 25000, false
        while DoesEntityExist(driver) and DoesEntityExist(vehicle) and GetGameTimer() < deadline
            and GetPedInVehicleSeat(vehicle, -1) ~= driver do
            if not shuffled and GetVehiclePedIsIn(driver, false) == vehicle then
                shuffled = true
                control(driver)
                TaskShuffleToNextVehicleSeat(driver, vehicle)
            end
            Wait(500)
        end
        if not DoesEntityExist(driver) or not DoesEntityExist(vehicle)
            or GetPedInVehicleSeat(vehicle, -1) ~= driver then
            return
        end

        -- Motor ligado por quem tem o controle da van; sem isso o NPC fica sentado nela.
        -- Van ainda parada depois de alguns segundos: a ordem não pegou, e é dada de novo.
        for _ = 1, 3 do
            if control(vehicle) then
                SetVehicleUndriveable(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)
            end
            control(driver)
            TaskVehicleDriveWander(driver, vehicle, 20.0, 786603)
            Wait(4000)
            if not DoesEntityExist(vehicle) or GetEntitySpeed(vehicle) > 1.0 then return end
        end
    end)
end

-- Olheiro ---------------------------------------------------------------------------------

---Aviso de carga de outra gang: uma área no mapa por um tempo, sem o ponto exato.
---@param area { x: number, y: number, z: number }
---@param radius number
function Haul.scout(area, radius)
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(area.x, area.y, area.z))
    Integrations.notify(locale('scout_notify', street), 'inform')

    local circle = AddBlipForRadius(area.x, area.y, area.z, radius + 0.0)
    SetBlipColour(circle, 1)
    SetBlipAlpha(circle, 90)
    local center = AddBlipForCoord(area.x, area.y, area.z)
    SetBlipSprite(center, 161)
    SetBlipColour(center, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip_scout'))
    EndTextCommandSetBlipName(center)

    SetTimeout(Config.haul.scoutBlipSeconds * 1000, function()
        if DoesBlipExist(circle) then RemoveBlip(circle) end
        if DoesBlipExist(center) then RemoveBlip(center) end
    end)
end

return Haul
