---Rota de carga, com o servidor como fonte da verdade.
---
---O jogador fala com o NPC do início e recebe (ou traz) o veículo da rota. Na pilha de
---caixas ele pega uma caixa de cada vez e guarda no veículo, até completar a carga. Leva o
---veículo até o destino, tira as caixas uma a uma e deixa no ponto de entrega. Com a
---última, recebe os itens e a gang ganha reputação.
---
---O client só pede cada passo. Cada pedido confere a fase, a distância do jogador ao lugar
---do passo, que o veículo é o da corrida e que a caixa passou um tempo mínimo na mão.
---
---Fases de uma corrida:
---    LOAD    carregando: pilha → veículo, até `loaded == count`
---    UNLOAD  descarregando: veículo (perto do destino) → ponto de entrega
---    PAY     tudo entregue, pagamento pendente (inventário cheio na primeira tentativa)
---
---Uma rota tem uma corrida por vez: a pilha, a vaga do veículo e o destino são um só.

local Config = require 'config.server'
local SharedConfig = require 'config.shared'
local Rules = require 'shared.rules'
local Routes = require 'server.routes'
local Security = require 'server.security'
local Sessions = require 'server.sessions'
local Integrations = require 'server.integrations'

local Phase = { LOAD = 'LOAD', UNLOAD = 'UNLOAD', PAY = 'PAY' }

local Hauls = {}

---@type table<integer, table> source -> corrida
local runs = {}
---@type table<integer, integer> routeId -> source que está nela
local routeOwner = {}
---@type table<integer, integer> routeId -> GetGameTimer a partir do qual reabre
local routeReopensAt = {}

local function fail(code)
    return { ok = false, error = code }
end

local function debugPrint(...)
    if SharedConfig.debug then lib.print.info('[hauls]', ...) end
end

---Apaga o veículo que a rota entregou. Com alguém dentro não apaga: tenta de novo até
---o prazo, e depois desiste — veículo parado vira problema do reboque, não da rota.
---@param vehicle integer?
local function removeVehicle(vehicle)
    if not vehicle then return end
    CreateThread(function()
        local deadline = GetGameTimer() + Config.haul.vehicleCleanupMs
        while DoesEntityExist(vehicle) and GetGameTimer() < deadline do
            local occupied = false
            for seat = -1, 6 do
                if GetPedInVehicleSeat(vehicle, seat) ~= 0 then occupied = true break end
            end
            if not occupied then
                DeleteEntity(vehicle)
                return
            end
            Wait(5000)
        end
    end)
end

---Fecha a corrida. `reason` vai para o client quando não foi ele quem pediu.
---@param source integer
---@param reason string?
local function endRun(source, reason)
    local run = runs[source]
    if not run then return end
    runs[source] = nil
    if routeOwner[run.routeId] == source then routeOwner[run.routeId] = nil end
    if run.ownsVehicle then removeVehicle(run.vehicle) end
    if reason then TriggerClientEvent('noir_gathering:client:haulEnded', source, reason) end
    debugPrint(source, 'corrida encerrada', run.routeId, reason or 'pedido')
end

---A rota e a corrida do jogador, ou o erro. Rota editada no meio encerra a corrida.
local function current(source)
    local run = runs[source]
    if not run then return nil, nil, 'no_run' end
    local route = Routes.get(run.routeId)
    if not route or route.mode ~= 'haul' then
        endRun(source, 'route_changed')
        return nil, nil, 'route_changed'
    end
    run.touchedAt = GetGameTimer()
    return run, route
end

---O veículo que o client apontou, se for o da corrida. Rota que não entrega veículo
---amarra a corrida ao primeiro veículo do model em que o jogador guardar uma caixa.
local function resolveVehicle(run, route, netId)
    if not Rules.isInteger(netId) or netId <= 0 then return nil, 'wrong_vehicle' end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil, 'wrong_vehicle' end
    if run.vehicle then
        if vehicle ~= run.vehicle then return nil, 'wrong_vehicle' end
        return vehicle
    end
    if (GetEntityModel(vehicle) & 0xFFFFFFFF) ~= (joaat(route.vehicle) & 0xFFFFFFFF) then
        return nil, 'wrong_vehicle'
    end
    return vehicle
end

local function near(coords, point, distance)
    return coords ~= nil and #(coords - Security.toVector(point)) <= distance
end

---Carregou tudo: é aqui que a polícia e o olheiro podem ficar sabendo. O alerta sai da
---pilha — é onde a carga foi vista — com o centro deslocado dentro da área.
local function departed(source, route)
    local haul, stack = route.haul, route.haul.stack

    if route.police.enabled and Rules.chance(route.police.chance) then
        Integrations.dispatch(Rules.blurCoords(stack, route.police.radius), locale('dispatch_haul_title'),
            locale('dispatch_haul_message'), route.police.radius)
        debugPrint(source, 'alerta policial', route.name)
    end

    if haul.scout.enabled and haul.category and Rules.chance(haul.scout.chance) then
        local product = Hauls.productOf(haul.category)
        if product then
            local area = Rules.blurCoords(stack, haul.scout.radius)
            for _, target in ipairs(Integrations.rivalsWithProduct(source, product)) do
                Integrations.phoneMessage(target, locale('scout_message'))
                TriggerClientEvent('noir_gathering:client:scout', target, area, haul.scout.radius)
            end
            debugPrint(source, 'olheiro avisou', route.name, product)
        end
    end
end

---Paga a corrida. Sem espaço para tudo, não paga nada e deixa pendente.
---@return boolean paid
local function pay(source, run, route)
    local rolled = {}
    for name, range in pairs(route.haul.rewards) do
        local amount = Rules.roll(range)
        if amount > 0 then
            if not Integrations.canCarry(source, name, amount) then return false end
            rolled[#rolled + 1] = { name = name, amount = amount }
        end
    end
    for _, reward in ipairs(rolled) do
        local ok, err = Integrations.addItem(source, reward.name, reward.amount)
        if ok then
            Integrations.notify(source, locale('collected', reward.amount, Integrations.itemLabel(reward.name)), 'success')
        else
            lib.print.warn(('carga: %s x%d não entregue a %d: %s'):format(reward.name, reward.amount, source, err))
        end
    end
    if route.haul.reputation > 0 and route.haul.category then
        Integrations.reportDelivery(source, run.routeId, route.name, route.haul.category, route.haul.reputation)
    end
    lib.print.info(('carga "%s" entregue por %s'):format(route.name, GetPlayerName(source) or source))
    return true
end

-- Passos ----------------------------------------------------------------------------------

local function start(source, routeId)
    if not Security.rateLimit(source, 'haul') then return fail('busy') end
    if not Integrations.coreReady() then return fail('provider_unavailable') end

    local route = Routes.get(routeId)
    if not route or route.mode ~= 'haul' or not Rules.isPlayable(route) then return fail('invalid_route') end
    if runs[source] or Sessions.isActive(source) then return fail('already_active') end
    if not Integrations.isLoaded(source) then return fail('not_loaded') end
    if not Sessions.canUseRoute(source, route) then return fail('not_allowed') end
    if not Integrations.meetsRequirement(source, route.requirement) then return fail('locked') end

    local coords = Security.pedCoords(source)
    if not near(coords, route.start, Config.distance.start) then return fail('too_far') end
    if routeOwner[routeId] then return fail('route_busy') end
    local now = GetGameTimer()
    if (routeReopensAt[routeId] or 0) > now then
        return { ok = false, error = 'route_cooldown', minutes = math.ceil((routeReopensAt[routeId] - now) / 60000) }
    end

    if route.vehicleSpawn then
        local spot = Security.toVector(route.vehicleSpawn)
        for _, vehicle in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(vehicle) - spot) < Config.distance.spawnClearance then return fail('spawn_blocked') end
        end
    end

    -- Trava antes do spawn, que espera: sem isso, dois pedidos juntos abririam a mesma rota.
    local run = { routeId = routeId, phase = Phase.LOAD, loaded = 0, delivered = 0, carrying = false,
        startedAt = now, touchedAt = now }
    runs[source] = run
    routeOwner[routeId] = source

    if route.vehicleSpawn then
        local netId, vehicle = Integrations.spawnVehicle(source, route.vehicle, route.vehicleSpawn)
        -- Jogador caiu ou a rota mudou durante o spawn: a corrida já foi fechada, e o
        -- veículo que chegou depois não tem dono.
        if runs[source] ~= run then
            if vehicle and DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
            return fail('route_changed')
        end
        if not netId or not vehicle then
            endRun(source)
            return fail('spawn_failed')
        end
        run.vehicle, run.netId, run.ownsVehicle = vehicle, netId, true
    end

    routeReopensAt[routeId] = now + route.haul.cooldown * 60000
    debugPrint(source, 'corrida aberta', route.name)
    return { ok = true, netId = run.netId, count = route.haul.count }
end

local function takeFromStack(source)
    if not Security.rateLimit(source, 'haulStep') then return fail('busy') end
    local run, route, err = current(source)
    if not run then return fail(err) end
    if run.phase ~= Phase.LOAD or run.carrying then return fail('wrong_step') end
    if run.loaded >= route.haul.count then return fail('wrong_step') end
    if not near(Security.pedCoords(source), route.haul.stack, Config.distance.stack) then return fail('too_far') end

    run.carrying, run.carryAt = true, GetGameTimer()
    return { ok = true }
end

local function loadVehicle(source, netId)
    if not Security.rateLimit(source, 'haulStep') then return fail('busy') end
    local run, route, err = current(source)
    if not run then return fail(err) end
    if run.phase ~= Phase.LOAD or not run.carrying then return fail('wrong_step') end
    if GetGameTimer() - run.carryAt < Config.haul.minCarryMs then return fail('too_soon') end

    local vehicle, vehicleErr = resolveVehicle(run, route, netId)
    if not vehicle then return fail(vehicleErr) end
    local coords = Security.pedCoords(source)
    if not coords or #(coords - GetEntityCoords(vehicle)) > Config.distance.vehicleUse then return fail('too_far') end

    run.vehicle, run.netId = vehicle, netId
    run.carrying = false
    run.loaded = run.loaded + 1
    if run.loaded < route.haul.count then return { ok = true, loaded = run.loaded } end

    run.phase = Phase.UNLOAD
    departed(source, route)
    return { ok = true, loaded = run.loaded, full = true }
end

local function takeFromVehicle(source, netId)
    if not Security.rateLimit(source, 'haulStep') then return fail('busy') end
    local run, route, err = current(source)
    if not run then return fail(err) end
    if run.phase ~= Phase.UNLOAD or run.carrying or run.loaded <= 0 then return fail('wrong_step') end

    local vehicle, vehicleErr = resolveVehicle(run, route, netId)
    if not vehicle then return fail(vehicleErr) end
    local vehicleCoords = GetEntityCoords(vehicle)
    if not near(vehicleCoords, route.haul.dropoff, Config.distance.unloadVehicle) then return fail('vehicle_far') end
    local coords = Security.pedCoords(source)
    if not coords or #(coords - vehicleCoords) > Config.distance.vehicleUse then return fail('too_far') end

    run.carrying, run.carryAt = true, GetGameTimer()
    run.loaded = run.loaded - 1
    return { ok = true, loaded = run.loaded }
end

local function dropOff(source)
    if not Security.rateLimit(source, 'haulStep') then return fail('busy') end
    local run, route, err = current(source)
    if not run then return fail(err) end
    if run.phase ~= Phase.UNLOAD or not run.carrying then return fail('wrong_step') end
    if GetGameTimer() - run.carryAt < Config.haul.minCarryMs then return fail('too_soon') end
    if not near(Security.pedCoords(source), route.haul.dropoff, Config.distance.dropoff) then return fail('too_far') end

    run.carrying = false
    run.delivered = run.delivered + 1
    if run.delivered < route.haul.count then return { ok = true, delivered = run.delivered } end

    run.phase = Phase.PAY
    if not pay(source, run, route) then return { ok = true, delivered = run.delivered, pending = true } end
    endRun(source)
    return { ok = true, delivered = run.delivered, finished = true }
end

local function collectPay(source)
    if not Security.rateLimit(source, 'haulStep') then return fail('busy') end
    local run, route, err = current(source)
    if not run then return fail(err) end
    if run.phase ~= Phase.PAY then return fail('wrong_step') end
    if not near(Security.pedCoords(source), route.haul.dropoff, Config.distance.dropoff) then return fail('too_far') end
    if not pay(source, run, route) then return fail('inventory_full') end
    endRun(source)
    return { ok = true, finished = true }
end

local function stop(source)
    endRun(source)
    return { ok = true }
end

-- Registro --------------------------------------------------------------------------------

---Produto do noir_gangs de uma categoria do core; é por ele que o olheiro acha os rivais.
---@type fun(category: string): string?
function Hauls.productOf(category)
    local catalog = Integrations.progressionCatalog()
    for _, entry in ipairs(catalog and catalog.categories or {}) do
        if entry.id == category then return entry.product end
    end
    return nil
end

---@param source integer
---@return boolean
function Hauls.isActive(source)
    return runs[source] ~= nil
end

---@param source integer
function Hauls.forget(source)
    endRun(source)
end

function Hauls.register()
    lib.callback.register('noir_gathering:server:haulStart', start)
    lib.callback.register('noir_gathering:server:haulTake', takeFromStack)
    lib.callback.register('noir_gathering:server:haulLoad', loadVehicle)
    lib.callback.register('noir_gathering:server:haulUnload', takeFromVehicle)
    lib.callback.register('noir_gathering:server:haulDrop', dropOff)
    lib.callback.register('noir_gathering:server:haulPay', collectPay)
    lib.callback.register('noir_gathering:server:haulStop', stop)

    Routes.onChange(function(routeId)
        for source, run in pairs(runs) do
            if run.routeId == routeId then endRun(source, 'route_changed') end
        end
        routeReopensAt[routeId] = nil
    end)

    AddEventHandler('playerDropped', function() endRun(source) end)
    AddEventHandler('bgrz_core:server:playerUnloaded', function(playerId)
        endRun(tonumber(playerId) or source)
    end)

    -- Veículo perdido (explodiu, afundou, foi apagado) e corrida esquecida acabam aqui.
    CreateThread(function()
        while true do
            Wait(10000)
            local now = GetGameTimer()
            for source, run in pairs(runs) do
                if run.vehicle and not DoesEntityExist(run.vehicle) then
                    run.ownsVehicle = false
                    endRun(source, 'vehicle_lost')
                elseif now - run.startedAt > Config.haul.maxRunMs then
                    endRun(source, 'expired')
                end
            end
        end
    end)
end

return Hauls
