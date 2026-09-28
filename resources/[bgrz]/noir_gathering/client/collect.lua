---Lado do jogador: turno, coleta e modo AFK. Só apresentação — cada passo pergunta
---ao servidor, que decide ponto, tempo e o que é entregue.

local Config = require 'config.shared'
local Integrations = require 'client.integrations'

local Collect = {}

---Turno em andamento: rota pública, item e ponto atual.
---@type { route: table, itemName: string, point: integer, blip: integer?, zone: integer? }?
local shift = nil
local collecting = false
local afkRunning = false

local ERRORS = {
    busy = 'error_busy',
    already_active = 'error_already_active',
    not_allowed = 'error_not_allowed',
    not_loaded = 'error_generic',
    too_far = 'error_too_far',
    wrong_point = 'error_wrong_point',
    no_shift = 'error_no_shift',
    in_vehicle = 'error_in_vehicle',
    wrong_vehicle = 'error_wrong_vehicle',
    no_tool = 'error_no_tool',
    low_durability = 'error_low_durability',
    inventory_full = 'error_inventory_full',
    too_soon = 'error_generic',
    expired = 'error_generic',
    route_changed = 'error_route_changed',
    provider_unavailable = 'error_generic',
    locked = 'error_locked',
}

local function notifyError(code, item)
    local key = ERRORS[code] or 'error_generic'
    if key == 'error_no_tool' or key == 'error_low_durability' then
        Integrations.notify(locale(key, item and item.tool or '?'), 'error')
    else
        Integrations.notify(locale(key), 'error')
    end
end

---Animação conferida: dicionário ausente no build derruba o cliente no Enhanced, então
---o que não existe cai para a padrão, e a padrão ausente vira "sem animação".
---@param anim table?
---@return table?
local function safeAnim(anim)
    for _, candidate in ipairs({ anim, Config.defaultAnim }) do
        if candidate and DoesAnimDictExist(candidate.dict) then
            return { dict = candidate.dict, clip = candidate.clip, flag = candidate.flag or 1 }
        end
    end
    return nil
end

---@param point { x: number, y: number, z: number }
local function toVector(point)
    return vector3(point.x, point.y, point.z)
end

local function clearPoint()
    if not shift then return end
    if shift.blip and DoesBlipExist(shift.blip) then RemoveBlip(shift.blip) end
    Integrations.removeZone(shift.zone)
    shift.blip, shift.zone = nil, nil
end

local function cleanup()
    clearPoint()
    shift = nil
    afkRunning = false
end

---@return boolean
function Collect.isBusy()
    return collecting or shift ~= nil or afkRunning
end

---@param routeId integer
---@return boolean
function Collect.isOnRoute(routeId)
    return shift ~= nil and shift.route.id == routeId
end

---Uma coleta completa num ponto: pede, roda a barra, confirma. Devolve a resposta do
---servidor ao fim, ou nil quando não chegou a pagar.
---@param route table
---@param itemName string
---@param index integer
---@return table?
local function collectAt(route, itemName, index)
    if collecting then return nil end
    local item = route.items[itemName]
    collecting = true

    local started = lib.callback.await('noir_gathering:server:beginCollect', false, route.id, itemName, index)
    if not started or not started.ok then
        collecting = false
        notifyError(started and started.error, item)
        return nil
    end

    local completed = lib.progressBar({
        duration = started.duration,
        label = locale('progress_collect', item.label),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = safeAnim(item.anim),
    })

    if not completed then
        lib.callback.await('noir_gathering:server:cancelCollect', false)
        collecting = false
        Integrations.notify(locale('collect_cancelled'), 'error')
        return nil
    end

    local result = lib.callback.await('noir_gathering:server:finishCollect', false)
    collecting = false
    if not result or not result.ok then
        notifyError(result and result.error, item)
        return nil
    end
    return result
end

local function showPoint(index)
    clearPoint()
    local item = shift.route.items[shift.itemName]
    local point = item.points[index]
    shift.point = index

    local blip = AddBlipForCoord(point.x, point.y, point.z)
    SetBlipSprite(blip, Config.blip.sprite)
    SetBlipColour(blip, Config.blip.color)
    SetBlipScale(blip, Config.blip.scale)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip_point', item.label))
    EndTextCommandSetBlipName(blip)
    shift.blip = blip

    local route, itemName = shift.route, shift.itemName
    shift.zone = Integrations.addZone({
        name = ('noir_gathering:shift:%d'):format(index),
        coords = toVector(point),
        radius = Config.targetRadius,
        options = { {
            name = 'noir_gathering:shift:collect',
            icon = 'fa-solid fa-hand',
            label = locale('target_collect', item.label),
            canInteract = function() return not collecting end,
            onSelect = function()
                local result = collectAt(route, itemName, index)
                if not result or not shift then return end
                if result.finished then
                    cleanup()
                    Integrations.notify(locale('shift_finished'), 'success')
                elseif result.point then
                    showPoint(result.point)
                end
            end,
        } },
    })
end

local function markerThread()
    CreateThread(function()
        while shift do
            local sleep = 500
            if Config.marker.enabled and shift.point and not collecting then
                local point = shift.route.items[shift.itemName].points[shift.point]
                local target = toVector(point)
                if #(GetEntityCoords(cache.ped) - target) <= Config.marker.distance then
                    sleep = 0
                    DrawMarker(2, target.x, target.y, target.z + 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.3, 0.3, 0.3, 255, 255, 0, 80, false, true, 2, false, nil, nil, false)
                end
            end
            Wait(sleep)
        end
    end)
end

---@param route table
---@param itemName string
function Collect.startShift(route, itemName)
    if Collect.isBusy() then return notifyError('already_active') end
    local result = lib.callback.await('noir_gathering:server:startShift', false, route.id, itemName)
    if not result or not result.ok then return notifyError(result and result.error) end

    shift = { route = route, itemName = itemName }
    showPoint(result.point)
    markerThread()
    Integrations.notify(locale('shift_started', route.items[itemName].label, Config.stopKey), 'inform')
end

---Encerra o que estiver rodando: coleta, AFK ou turno.
function Collect.stop()
    if collecting then lib.cancelProgress() end
    if afkRunning then
        afkRunning = false
        Integrations.notify(locale('afk_stopped'), 'inform')
    end
    if shift then
        lib.callback.await('noir_gathering:server:stopShift', false)
        cleanup()
        Integrations.notify(locale('shift_stopped'), 'inform')
    end
end

---Coleta num ponto de rota sem início. Em rota AFK, repete no mesmo ponto até a tecla
---de parar, um erro ou o jogador sair de perto.
---@param route table
---@param itemName string
---@param index integer
function Collect.free(route, itemName, index)
    if Collect.isBusy() then return end
    if not route.afk then
        collectAt(route, itemName, index)
        return
    end

    afkRunning = true
    Integrations.notify(locale('afk_started', Config.stopKey), 'inform')
    CreateThread(function()
        while afkRunning do
            if not collectAt(route, itemName, index) then break end
            Wait(250)
        end
        afkRunning = false
    end)
end

---O servidor encerrou o turno (rota editada, inatividade).
---@param reason string
function Collect.ended(reason)
    if not shift then return end
    cleanup()
    Integrations.notify(locale(reason == 'idle' and 'shift_idle' or 'error_route_changed'), 'error')
end

function Collect.reset()
    if collecting then lib.cancelProgress() end
    cleanup()
end

return Collect
