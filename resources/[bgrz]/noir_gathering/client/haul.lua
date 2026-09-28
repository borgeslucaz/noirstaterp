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

local function progress(label)
    return lib.progressBar({
        duration = Config.haul.loadMs,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
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

-- Marcador --------------------------------------------------------------------------------

local function markerThread()
    CreateThread(function()
        while run do
            local sleep = 500
            if Config.marker.enabled then
                local point = run.phase == 'LOAD' and run.route.haul.stack or run.route.haul.dropoff
                local target = toVector(point)
                if #(GetEntityCoords(cache.ped) - target) <= Config.marker.distance then
                    sleep = 0
                    DrawMarker(2, target.x, target.y, target.z + 1.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.3, 0.3, 0.3, 255, 255, 0, 80, false, true, 2, false, nil, nil, false)
                end
            end
            Wait(sleep)
        end
    end)
end

-- Ciclo -----------------------------------------------------------------------------------

local function cleanup()
    if not run then return end
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
    markerThread()
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
    if not progress(locale('progress_haul_load')) then return end
    local result = ask('haulLoad', NetworkGetNetworkIdFromEntity(entity))
    if not result then return end
    Carry.stop()
    run.loaded = result.loaded
    if not result.full then
        return Integrations.notify(locale('haul_loaded', run.loaded, run.count), 'success')
    end

    run.phase = 'UNLOAD'
    removeStack()
    createDropoff()
    guideTo(run.route.haul.dropoff, locale('blip_haul_dropoff'))
    Integrations.notify(locale('haul_full'), 'success')
end

---@param entity integer
function Haul.unload(entity)
    if not run or not DoesEntityExist(entity) then return end
    if not progress(locale('progress_haul_unload')) then return end
    local result = ask('haulUnload', NetworkGetNetworkIdFromEntity(entity))
    if not result then return end
    run.loaded = result.loaded
    Carry.start()
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
