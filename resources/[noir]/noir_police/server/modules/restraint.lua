---Algema, zip tie, arrombar algema, escolta, carregar no ombro e viatura.
---
---O cliente pede; o servidor confere papel, item, distância e estado nas próprias
---tabelas (server/state.lua) e só então muda o estado.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local State = require 'server.state'

local Restraint = {}

local pendingEscape = {}
local escapeCooldown = {}
local lockpickSessions = {}

local function fail(code) return { ok = false, code = code } end

---Frente ou costas, pelo lado de onde o policial chega (calculado no servidor).
---@return 'front'|'back'
local function cuffAngle(officer, target)
    local officerPed, targetPed = GetPlayerPed(officer), GetPlayerPed(target)
    local toOfficer = GetEntityCoords(officerPed) - GetEntityCoords(targetPed)
    local heading = math.rad(GetEntityHeading(targetPed))
    local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local length = #toOfficer
    if length == 0 then return 'back' end
    local dot = (toOfficer.x * forward.x + toOfficer.y * forward.y) / length
    return dot > 0 and 'front' or 'back'
end

local function awaitEscape(target, officerHeading, cuffType)
    local token = Utils.opaqueId('esc')
    local p = promise.new()
    pendingEscape[token] = { target = target, promise = p }
    TriggerClientEvent('noir_police:client:beingCuffed', target, token, officerHeading, cuffType,
        ServerConfig.cuff.escapeWindowMs)
    SetTimeout(ServerConfig.cuff.escapeWindowMs + 1500, function()
        local entry = pendingEscape[token]
        if entry then
            pendingEscape[token] = nil
            entry.promise:resolve(false)
        end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('noir_police:server:cuffEscape', function(token, escaped)
    local src = source
    local entry = type(token) == 'string' and pendingEscape[token] or nil
    if not entry or entry.target ~= src then return end
    pendingEscape[token] = nil
    entry.promise:resolve(escaped == true)
end)

---@return table result
local function cuff(src, targetId, cuffType)
    if not Security.rateLimit(src, 'cuff') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end
    if cuffType ~= 'cuffs' and cuffType ~= 'zipties' then return fail('invalid_type') end

    if State.isRestrained(src) or State.busy[src] or State.escorting[src] or State.carrying[src] then
        return fail('busy')
    end
    if State.busy[target] or State.cuffed[target] then return fail('target_busy') end
    if Security.inVehicle(src) or Security.inVehicle(target) then return fail('in_vehicle') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end

    local item = Config.items[cuffType]
    if Integrations.itemCount(src, item) < 1 then return fail('no_item') end

    -- `handsUp` é o próprio alvo dizendo que se rendeu. Não é autorização de nada:
    -- só decide se o zip tie é possível e se a algemação é normal ou agressiva.
    local handsUp = Player(target).state.handsUp
    local downed = Integrations.isDowned(target)
    -- Qualquer um algema (algema ou zip tie) quem está rendido. Só o policial em serviço
    -- algema quem não se rendeu, na algemação agressiva com chance de fuga.
    local surrendered = handsUp or downed
    if not surrendered and (cuffType == 'zipties' or not Security.police(src)) then
        return fail('needs_hands_up')
    end
    local aggressive = handsUp ~= 'hu' and not downed

    State.busy[src], State.busy[target] = true, true
    local angle = aggressive and 'back' or cuffAngle(src, target)

    if aggressive then
        local canEscape = (escapeCooldown[target] or 0) <= os.time()
        local escaped = awaitEscape(target, GetEntityHeading(GetPlayerPed(src)), canEscape and cuffType or false)
        if escaped and canEscape then
            escapeCooldown[target] = os.time() + ServerConfig.cuff.escapeCooldownSeconds
            State.busy[src], State.busy[target] = nil, nil
            Integrations.log(src, 'cuff_escaped', ('alvo %s fugiu da algemação'):format(target))
            return fail('escaped')
        end
        -- O await cede a thread: tudo pode ter mudado.
        if not Security.player(target) or not Security.playersNear(src, target, ServerConfig.distance.interact + 1.0) then
            State.busy[src], State.busy[target] = nil, nil
            return fail('too_far')
        end
    end

    local removed = Integrations.removeItem(src, item, 1)
    if not removed then
        State.busy[src], State.busy[target] = nil, nil
        TriggerClientEvent('noir_police:client:cuffAborted', target)
        return fail('no_item')
    end

    State.releaseAll(target)
    State.cuff(target, cuffType, angle)
    State.busy[src], State.busy[target] = nil, nil
    Integrations.log(src, 'cuff', ('%s algemou %s (%s, %s)'):format(
        Integrations.getName(src), Integrations.getName(target), cuffType, aggressive and 'agressiva' or 'normal'))
    return { ok = true, aggressive = aggressive, angle = angle }
end

lib.callback.register('noir_police:server:cuff', function(src, targetId, cuffType)
    local ok, result = pcall(cuff, src, targetId, cuffType)
    if ok then return result end
    -- Erro no meio do fluxo: não deixa ninguém preso em `busy`.
    State.busy[src] = nil
    local target = tonumber(targetId)
    if target then State.busy[target] = nil end
    lib.print.error(('[noir_police] cuff falhou: %s'):format(result))
    return fail('unknown')
end)

lib.callback.register('noir_police:server:uncuff', function(src, targetId)
    if not Security.rateLimit(src, 'cuff') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end
    local entry = State.cuffed[target]
    if not entry then return fail('not_cuffed') end
    if State.isCuffed(src) then return fail('busy') end
    if Security.inVehicle(src) then return fail('in_vehicle') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end

    local tool = entry.type == 'cuffs' and Config.items.cuffKey or Config.items.cutters
    if Integrations.itemCount(src, tool) < 1 then return fail('no_item') end

    State.releaseAll(target)
    State.uncuff(target)
    if entry.type == 'cuffs' and ServerConfig.cuff.returnCuffsOnRemove then
        Integrations.addItem(src, Config.items.cuffs, 1)
    end
    Integrations.log(src, 'uncuff', ('%s tirou a algema de %s'):format(Integrations.getName(src), Integrations.getName(target)))
    return { ok = true }
end)

-- Arrombar algema ------------------------------------------------------------------

lib.callback.register('noir_police:server:lockpickStart', function(src, targetId)
    if not Security.rateLimit(src, 'lockpick') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end
    local entry = State.cuffed[target]
    if not entry or entry.type ~= 'cuffs' then return fail('not_cuffed') end
    if State.isRestrained(src) then return fail('busy') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end
    if Integrations.itemCount(src, Config.cuffs.lockpickItem) < 1 then return fail('no_item') end

    local token = Utils.opaqueId('lck')
    lockpickSessions[src] = { token = token, target = target, startedAt = GetGameTimer() }
    return { ok = true, token = token }
end)

lib.callback.register('noir_police:server:lockpickFinish', function(src, token, success)
    local session = lockpickSessions[src]
    lockpickSessions[src] = nil
    if not session or session.token ~= token then return fail('invalid_session') end

    local elapsed = GetGameTimer() - session.startedAt
    if elapsed < ServerConfig.cuff.lockpickMinMs or elapsed > ServerConfig.cuff.lockpickMaxMs then
        Integrations.log(src, 'lockpick_timing', ('tempo fora da janela: %dms'):format(elapsed))
        return fail('invalid_session')
    end
    local target = session.target
    local entry = State.cuffed[target]
    if not entry or entry.type ~= 'cuffs' then return fail('not_cuffed') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end

    if success ~= true then
        if math.random(100) <= ServerConfig.cuff.lockpickBreakChance then
            Integrations.removeItem(src, Config.cuffs.lockpickItem, 1)
            return fail('lockpick_broke')
        end
        return fail('failed')
    end

    State.releaseAll(target)
    State.uncuff(target)
    Integrations.log(src, 'lockpick_uncuff', ('%s arrombou a algema de %s'):format(
        Integrations.getName(src), Integrations.getName(target)))
    return { ok = true }
end)

-- Escolta e carregar ---------------------------------------------------------------

---Condição comum: algemado ou caído. Polícia e EMS em serviço escoltam qualquer um.
local function canMove(src, target, allowEmergency)
    if State.cuffed[target] or Integrations.isDowned(target) then return true end
    return allowEmergency and Security.emergency(src) ~= nil
end

lib.callback.register('noir_police:server:escort', function(src, targetId)
    if not Security.rateLimit(src, 'escort') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end

    if State.escorting[src] == target then
        State.releaseEscort(src)
        return { ok = true, released = true }
    end

    if State.isRestrained(src) or State.escorting[src] or State.carrying[src] then return fail('busy') end
    if State.escortedBy[target] or State.carriedBy[target] or State.busy[target] then return fail('target_busy') end
    if Security.inVehicle(src) or Security.inVehicle(target) then return fail('in_vehicle') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end
    if not canMove(src, target, true) then return fail('not_restrained') end

    State.escortedBy[target] = src
    State.escorting[src] = target
    Player(target).state:set('isEscorted', src, true)
    return { ok = true }
end)

lib.callback.register('noir_police:server:carry', function(src, targetId)
    if not Security.rateLimit(src, 'escort') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target or target == src then return fail('invalid_target') end

    if State.carrying[src] == target then
        State.releaseCarry(src)
        return { ok = true, released = true }
    end

    if State.isRestrained(src) or State.escorting[src] or State.carrying[src] then return fail('busy') end
    if State.escortedBy[target] or State.carriedBy[target] or State.busy[target] then return fail('target_busy') end
    if Security.inVehicle(src) or Security.inVehicle(target) then return fail('in_vehicle') end
    if not Security.playersNear(src, target, ServerConfig.distance.interact) then return fail('too_far') end
    if not canMove(src, target, false) then return fail('not_restrained') end

    State.carriedBy[target] = src
    State.carrying[src] = target
    Player(target).state:set('isCarried', src, true)
    return { ok = true }
end)

-- Viatura --------------------------------------------------------------------------

local function vehicleFromNet(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return nil end
    return vehicle
end

lib.callback.register('noir_police:server:putInVehicle', function(src, targetId, netId, seat)
    if not Security.rateLimit(src, 'escort') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target then return fail('invalid_target') end
    if State.escorting[src] ~= target and State.carrying[src] ~= target then return fail('not_escorting') end

    local vehicle = vehicleFromNet(netId)
    if not vehicle then return fail('invalid_vehicle') end
    seat = Utils.intInRange(seat, -1, 8)
    if not seat then return fail('invalid_seat') end
    local vehicleCoords = GetEntityCoords(vehicle)
    if not Security.near(src, vehicleCoords, ServerConfig.distance.vehicle)
        or not Security.near(target, vehicleCoords, ServerConfig.distance.vehicle + 2.0) then
        return fail('too_far')
    end
    if GetPedInVehicleSeat(vehicle, seat) ~= 0 then return fail('seat_taken') end

    State.releaseAll(src)
    -- O desanexo acontece no cliente do alvo; espera um pouco antes de sentar.
    Wait(400)
    if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, seat) ~= 0 then return fail('seat_taken') end
    SetPedIntoVehicle(GetPlayerPed(target), vehicle, seat)
    TriggerClientEvent('noir_police:client:enterVehicle', target, NetworkGetNetworkIdFromEntity(vehicle), seat)
    return { ok = true }
end)

---Quem está em qual porta-malas (fonte de verdade; o state do carro é espelho para o target).
local trunkOf = {}

local function freeTrunk(target)
    local vehicle = trunkOf[target]
    trunkOf[target] = nil
    if vehicle and DoesEntityExist(vehicle) and Entity(vehicle).state.noirTrunk == target then
        Entity(vehicle).state:set('noirTrunk', nil, true)
    end
end

-- Porta-malas: quem está no ombro vai para o porta-malas (animação e câmera do
-- qbx_radialmenu, que só recebe a ordem daqui, já validada).
lib.callback.register('noir_police:server:putInTrunk', function(src, targetId, netId)
    if not Security.rateLimit(src, 'escort') then return fail('rate_limited') end
    local target = Security.player(targetId)
    if not target or State.carrying[src] ~= target then return fail('not_carrying') end
    local vehicle = vehicleFromNet(netId)
    if not vehicle then return fail('invalid_vehicle') end
    local vehicleCoords = GetEntityCoords(vehicle)
    if not Security.near(src, vehicleCoords, ServerConfig.distance.vehicle) then return fail('too_far') end

    if Entity(vehicle).state.noirTrunk then return fail('trunk_occupied') end

    State.releaseAll(src)
    Wait(400)
    if not DoesEntityExist(vehicle) then return fail('invalid_vehicle') end
    Entity(vehicle).state:set('noirTrunk', target, true)
    trunkOf[target] = vehicle
    TriggerClientEvent('qb-trunk:client:KidnapGetIn', target, NetworkGetNetworkIdFromEntity(vehicle))
    return { ok = true }
end)

lib.callback.register('noir_police:server:takeOutOfTrunk', function(src, netId)
    if not Security.rateLimit(src, 'escort') then return fail('rate_limited') end
    local vehicle = vehicleFromNet(netId)
    if not vehicle then return fail('invalid_vehicle') end
    local target = Entity(vehicle).state.noirTrunk
    if not target or trunkOf[target] ~= vehicle then return fail('trunk_empty') end
    if not Security.near(src, GetEntityCoords(vehicle), ServerConfig.distance.vehicle) then return fail('too_far') end

    freeTrunk(target)
    -- O mesmo evento, com a pessoa já dentro, é a saída do fluxo do qbx_radialmenu.
    TriggerClientEvent('qb-trunk:client:KidnapGetIn', target, NetworkGetNetworkIdFromEntity(vehicle))
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    freeTrunk(source)
end)

lib.callback.register('noir_police:server:takeOutOfVehicle', function(src, netId, seat)
    if not Security.rateLimit(src, 'escort') then return fail('rate_limited') end
    if State.isRestrained(src) or State.escorting[src] or State.carrying[src] then return fail('busy') end
    local vehicle = vehicleFromNet(netId)
    if not vehicle then return fail('invalid_vehicle') end
    if Security.inVehicle(src) then return fail('in_vehicle') end
    if not Security.near(src, GetEntityCoords(vehicle), ServerConfig.distance.vehicle) then return fail('too_far') end

    seat = Utils.intInRange(seat, -1, 8)
    if not seat then return fail('invalid_seat') end
    local ped = GetPedInVehicleSeat(vehicle, seat)
    if not ped or ped == 0 then return fail('seat_empty') end

    local target
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if GetPlayerPed(id) == ped then target = id break end
    end
    if not target or target == src then return fail('invalid_target') end
    if not canMove(src, target, false) then return fail('not_restrained') end

    local coords = Security.coords(src)
    SetEntityCoords(GetPlayerPed(target), coords.x, coords.y, coords.z, false, false, false, false)
    State.escortedBy[target] = src
    State.escorting[src] = target
    Player(target).state:set('isEscorted', src, true)
    return { ok = true, target = target }
end)

-- Ciclo de vida --------------------------------------------------------------------

AddEventHandler('bgrz_core:server:playerLoaded', function(src)
    src = tonumber(src)
    if not src then return end
    SetTimeout(3000, function()
        if Security.player(src) then State.restore(src) end
    end)
end)

AddEventHandler('bgrz_core:server:playerUnloaded', function(src)
    src = tonumber(src)
    if not src then return end
    State.forget(src)
end)

-- Renascer no hospital solta tudo, como o qbx_police fazia pelo cliente.
AddEventHandler('bgrz_core:server:playerRespawned', function(src)
    src = tonumber(src)
    if not src then return end
    State.releaseAll(src)
    if State.cuffed[src] then State.uncuff(src) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lockpickSessions[src] = nil
    for token, entry in pairs(pendingEscape) do
        if entry.target == src then
            pendingEscape[token] = nil
            entry.promise:resolve(false)
        end
    end
end)

-- Admin: alterna a própria algema (usado pelo qbx_adminmenu).
RegisterNetEvent('noir_police:server:adminToggleCuff', function()
    local src = source
    if not IsPlayerAceAllowed(src, 'command.noir_police_admin') and not IsPlayerAceAllowed(src, 'group.admin') then return end
    if State.cuffed[src] then
        State.releaseAll(src)
        State.uncuff(src)
    else
        State.cuff(src, 'cuffs', 'back')
    end
end)

-- Prisão (xt-prison): quem entra na cela sai da algema e da escolta. O xt-prison
-- grava `injail` no metadata quando a prisão acontece.
RegisterNetEvent('police:server:JailPlayer', function(targetId)
    local src = source
    local target = Security.player(targetId)
    if not target or not Security.police(src) then return end
    SetTimeout(3000, function()
        local months = tonumber(Integrations.getMetadata(target, 'injail')) or 0
        if months > 0 and Security.player(target) then
            State.releaseAll(target)
            if State.cuffed[target] then State.uncuff(target) end
        end
    end)
end)

-- API para outros resources --------------------------------------------------------

---@param source integer
---@return boolean
function Restraint.isCuffed(source)
    return State.isCuffed(tonumber(source) or 0)
end

---@param source integer
function Restraint.release(source)
    source = tonumber(source)
    if not source then return end
    State.releaseAll(source)
    if State.cuffed[source] then State.uncuff(source) end
end

exports('IsCuffed', Restraint.isCuffed)
exports('ReleaseRestraints', Restraint.release)

return Restraint
