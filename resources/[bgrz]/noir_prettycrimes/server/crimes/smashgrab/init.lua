---Smash & Grab — lado servidor.
---
---Três pedidos, nesta ordem: `reserve` tranca o objeto, `claim` entrega,
---`release` devolve se o jogador desistiu. Cada um revalida o mundo inteiro do
---zero — nenhum deles confia no que o anterior viu, porque entre um e outro o
---carro pode ter sumido, andado ou virado veículo de alguém.
---
---O client manda três coisas: netId, propKey e seatKey. As duas últimas não são
---aceitas: o servidor **recomputa** o objeto daquele veículo a partir da mesma
---semente determinística e compara. Divergiu, recusa. É o que fecha a porta para
---"chamar o evento à mão pedindo a maleta".

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local SharedConfig = require 'config.shared'
local ServerConfig = require 'config.server'
local CrimeConfig = require 'config.smashgrab'
local CrimeServerConfig = require 'config.smashgrab_server'
local Rules = require 'shared.smashgrab_rules'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Spawn = require 'server.crimes.smashgrab.spawn'
local Reservations = require 'server.crimes.smashgrab.reservations'
local Loot = require 'server.crimes.smashgrab.loot'

local CRIME = Constants.crimes.smashgrab
local DebugPrint = Utils.debugPrint(CRIME)
local ELIGIBILITY = CrimeConfig.eligibility

local EVENT_SURVEY = Constants.event('server', CRIME, 'survey')
local EVENT_BREAK = Constants.event('server', CRIME, 'break')
local EVENT_BROKEN = Constants.event('client', CRIME, 'windowBroken')
local EVENT_RESERVE = Constants.event('server', CRIME, 'reserve')
local EVENT_RELEASE = Constants.event('server', CRIME, 'release')
local EVENT_CLAIM = Constants.event('server', CRIME, 'claim')

local PRUNE_INTERVAL = 300000

local module = {}

---@type table<number, boolean>
local blockedModels = {}
for index = 1, #ELIGIBILITY.vehicleModelBlacklist do
    blockedModels[joaat(ELIGIBILITY.vehicleModelBlacklist[index])] = true
end

-- ---------------------------------------------------------------------------
-- Classe do veículo
-- ---------------------------------------------------------------------------

---Só é chamada com `classMultipliers.enabled`. O qbx_core monta esse mapa uma vez
---perguntando a um cliente e o mantém em cache; a primeira chamada pode ceder a
---thread, as seguintes não.
---@param model number
---@return integer? class
local function vehicleClass(model)
    if not CrimeServerConfig.classMultipliers.enabled then return nil end
    return Integrations.vehicleClass(model)
end

-- ---------------------------------------------------------------------------
-- Validação
-- ---------------------------------------------------------------------------

---Elegibilidade pelo que o SERVIDOR consegue ver.
---
---NPC dentro do carro ele não enxerga — isso fica com o client, que recusa o
---spawn. O que importa para exploit está coberto aqui: tipo, modelo, propriedade,
---jogador dentro, movimento e dano.
---@param vehicle number
---@param occupied table<number, boolean>? conjunto pronto (caminho do survey)
---@return boolean ok
---@return string? reason
local function isEligible(vehicle, occupied)
    if not ELIGIBILITY.allowedTypes[GetVehicleType(vehicle)] then return false, 'not_eligible' end
    if blockedModels[math.floor(GetEntityModel(vehicle)) % 0x100000000] then
        return false, 'not_eligible'
    end

    if ELIGIBILITY.blockPlayerOwned then
        local state = Entity(vehicle).state
        for index = 1, #ELIGIBILITY.ownedStateBags do
            if state[ELIGIBILITY.ownedStateBags[index]] then return false, 'not_eligible' end
        end
    end

    if ELIGIBILITY.blockOccupied then
        -- No survey vem o conjunto pronto; nos pedidos de um veículo só, a
        -- checagem direta é mais barata que montar a tabela inteira.
        local inside = occupied and occupied[vehicle] or
            (not occupied and Security.hasPlayerInside(vehicle))
        if inside then return false, 'not_eligible' end
    end
    if ELIGIBILITY.blockMoving and GetEntitySpeed(vehicle) > ELIGIBILITY.maxSpeed then
        return false, 'not_eligible'
    end
    if ELIGIBILITY.blockDestroyed and GetVehicleBodyHealth(vehicle) < ELIGIBILITY.minBodyHealth then
        return false, 'not_eligible'
    end

    return true
end

---Resolve o pedido em um veículo real e no objeto que ele DEVE ter.
---
---O `propKey`/`seatKey` do client só é usado para comparar. Quem diz o que tem
---dentro daquele carro é a semente, recomputada aqui.
---@param source number
---@param netId any
---@param propKey any
---@param seatKey any
---@return number? vehicle
---@return table? loot
---@return string? errorCode
local function resolve(source, netId, propKey, seatKey)
    local vehicle, resolveError = Security.resolveVehicle(source, netId, CrimeConfig.maxDistance)
    if not vehicle then return nil, nil, resolveError end

    local eligible, reason = isEligible(vehicle)
    if not eligible then return nil, nil, reason end

    local loot = Spawn.decisionFor(netId, vehicle, vehicleClass(GetEntityModel(vehicle)))
    if not loot then return nil, nil, 'no_loot' end

    -- O client pediu um objeto diferente do que existe naquele carro.
    if propKey ~= nil and (loot.propKey ~= propKey or loot.seatKey ~= seatKey) then
        DebugPrint(('divergência de %s: pediu %s/%s, é %s/%s')
            :format(source, tostring(propKey), tostring(seatKey), loot.propKey, loot.seatKey))
        return nil, nil, 'mismatch'
    end

    return vehicle, loot
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

---Ponto único de alerta policial do módulo. Trocar de dispatch é mexer aqui e no
---wrapper do `server/integrations.lua` — nada chama provider direto.
---@param stage 'reserved'|'claimed'
---@param vehicle number
---@param loot table
---@param context table?
local function dispatchSmashGrab(stage, vehicle, loot, context)
    local trigger = CrimeServerConfig.dispatch.trigger
    if trigger ~= stage and trigger ~= 'both' then return end

    local chance = CrimeServerConfig.dispatch.chance * module.witnessMultiplier(context)
    if not Utils.chance(chance) then return end

    Integrations.dispatch({
        title = locale('sg_dispatch_title'),
        message = locale('sg_dispatch_message', locale(loot.prop.label)),
        coords = GetEntityCoords(vehicle),
        code = CrimeServerConfig.dispatch.code,
    })
end

---Gancho de testemunhas. Desligado, devolve 1.0 e não custa nada.
---
---Ligado, `context.witnesses` deve vir de uma contagem feita NO SERVIDOR. Contagem
---mandada pelo client é palpite do client, e viraria mais um número para forjar.
---Enquanto essa contagem não existir, a opção fica desligada.
---@param context table?
---@return number
function module.witnessMultiplier(context)
    local config = CrimeServerConfig.witnesses
    if not config.enabled then return 1.0 end

    local witnesses = context and context.witnesses
    if not Utils.isFinite(witnesses) or witnesses <= 0 then return 1.0 end

    return 1.0 + math.min(witnesses * config.bonusPerWitness, config.maxBonus)
end

-- ---------------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------------

---Responde quais dos veículos perguntados têm objeto.
---
---A checagem de distância aqui é o ponto inteiro da mudança: sem ela, um client
---adulterado enumeraria netIds e receberia o mapa completo de maletas. Com ela, a
---resposta só sai para o que o jogador já teria como enxergar de qualquer jeito.
---
---Recusa o lote inteiro em vez de responder parcialmente quando o pedido está mal
---formado: resposta parcial ensinaria por tentativa e erro quais netIds existem.
---@param source number
---@param netIds any
---@return table<number, table>|nil answer  netId -> { propKey, seatKey }
local function handleSurvey(source, netIds)
    if not Security.rateLimit(source, CRIME .. ':survey', CrimeConfig.scanInterval - 250) then
        return nil
    end
    if type(netIds) ~= 'table' then return nil end

    local count = #netIds
    if count == 0 or count > CrimeConfig.surveyBatchMax then
        DebugPrint(('lote inválido de %s: %d netIds'):format(source, count))
        return nil
    end
    if not Security.isValidPlayer(source) then return nil end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    -- Folga sobre o raio de ativação: a posição que o servidor tem e a que o
    -- client tem divergem um pouco, e negar por 2 m faria o prop piscar.
    local maxDistance = CrimeConfig.activationDistance * 1.25
    local occupied = ELIGIBILITY.blockOccupied and Security.occupiedVehicles() or nil

    -- A resposta distingue três coisas, e a distinção importa:
    --   tabela -> tem este objeto;
    --   false  -> decidido, não tem nada (o client pode memorizar);
    --   ausente -> não deu para responder AGORA (longe, andando, ocupado).
    --
    -- Sem o `false` explícito, o client leria toda ausência como "não tem" e
    -- memorizaria uma recusa temporária até o carro sair dos 120 m.
    local answer = {}
    for index = 1, count do
        local netId = netIds[index]
        if Utils.isPositiveInteger(netId) then
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and GetEntityType(vehicle) == 2
                and #(playerCoords - GetEntityCoords(vehicle)) <= maxDistance
                and isEligible(vehicle, occupied) then
                local loot = Spawn.decisionFor(netId, vehicle, vehicleClass(GetEntityModel(vehicle)))
                answer[netId] = loot and { propKey = loot.propKey, seatKey = loot.seatKey } or false
            end
        end
    end

    return answer
end

---Autoriza a quebra do vidro e manda o estouro para o dono de rede do veículo.
---
---O native de quebrar janela só replica a partir do dono, então o servidor manda o
---recado direto para ele em vez de pedir ao ladrão que dispute o controle. Em troca,
---não há disputa de controle de entidade em lugar nenhum deste resource.
---
---A quebra não concede nada, mas passa pela mesma porta das outras ações: sem
---objeto naquele carro, sem quebra — o vidro não é um brinquedo para quem descobriu
---o nome do evento.
---@param source number
---@param netId any
---@return { ok: boolean, code?: string }
local function handleBreak(source, netId)
    if not Security.rateLimit(source, CRIME .. ':break', CrimeServerConfig.breakCooldown) then
        return { ok = false, code = 'cooldown' }
    end

    local vehicle, loot, resolveError = resolve(source, netId)
    if not vehicle then return { ok = false, code = resolveError } end

    if Reservations.status(netId) == 'claimed' then
        return { ok = false, code = 'already_taken' }
    end

    local alarm = CrimeServerConfig.alarm
    local duration = (alarm.enabled and Utils.chance(alarm.chance)) and alarm.duration or nil

    local owner = NetworkGetEntityOwner(vehicle)
    local target = (type(owner) == 'number' and owner > 0) and owner or source
    TriggerClientEvent(EVENT_BROKEN, target, netId, loot.seat.window, duration)

    DebugPrint(('%s quebrou o vidro %d do netId %s%s')
        :format(source, loot.seat.window, netId, duration and ' (alarme)' or ''))
    return { ok = true }
end

---@param source number
---@param netId any
---@param propKey any
---@param seatKey any
---@return { ok: boolean, code?: string }
local function handleReserve(source, netId, propKey, seatKey)
    if not Security.rateLimit(source, CRIME, CrimeServerConfig.playerCooldown) then
        return { ok = false, code = 'cooldown' }
    end
    -- Falhar aqui poupa o jogador de fazer as duas animações para descobrir no
    -- fim que não há como pagar.
    if not Integrations.coreReady() then
        return { ok = false, code = 'provider_unavailable' }
    end
    if type(propKey) ~= 'string' or type(seatKey) ~= 'string' then
        return { ok = false, code = 'mismatch' }
    end

    local vehicle, loot, resolveError = resolve(source, netId, propKey, seatKey)
    if not vehicle then return { ok = false, code = resolveError } end

    local ok, reserveError = Reservations.reserve(netId, vehicle, source, loot.propKey, loot.seatKey)
    if not ok then return { ok = false, code = reserveError } end

    dispatchSmashGrab('reserved', vehicle, loot)
    return { ok = true }
end

---@param source number
---@param netId any
---@return { ok: boolean }
local function handleRelease(source, netId)
    if not Utils.isPositiveInteger(netId) then return { ok = false } end
    Reservations.release(netId, source)
    return { ok = true }
end

---@param source number
---@param netId any
---@return { ok: boolean, code?: string }
local function handleClaim(source, netId)
    -- A reserva é conferida antes de qualquer trabalho: quem não reservou não
    -- chega perto do sorteio, mesmo chamando o evento à mão.
    if not Utils.isPositiveInteger(netId) then return { ok = false, code = 'mismatch' } end
    if Reservations.holder(netId) ~= source then
        return { ok = false, code = Reservations.status(netId) == 'claimed' and 'already_taken' or 'reserved' }
    end

    local vehicle, loot, resolveError = resolve(source, netId)
    if not vehicle then
        Reservations.release(netId, source)
        return { ok = false, code = resolveError }
    end

    -- O core pode ter caído entre a reserva e agora. Conferir ANTES de fechar a
    -- reserva: marcar como levado e só então descobrir que não dá para conceder
    -- consumiria a mochila e não entregaria nada.
    if not Integrations.coreReady() then
        return { ok = false, code = 'provider_unavailable' }
    end

    -- Fecha a reserva ANTES de conceder. Daqui para baixo o objeto já é deste
    -- pedido, e nenhum segundo `claim` passa por cima.
    local minElapsed = math.floor(CrimeConfig.duration * CrimeServerConfig.minElapsedFactor)
    local ok, claimError = Reservations.claim(netId, vehicle, source, minElapsed)
    if not ok then return { ok = false, code = claimError } end

    local multiplier = 1.0
    if CrimeServerConfig.classMultipliers.enabled then
        local class = vehicleClass(GetEntityModel(vehicle))
        multiplier = (class and CrimeServerConfig.classLootMultipliers[class])
            or CrimeServerConfig.classLootMultipliers.default
    end

    local granted = Loot.grant(source, Loot.roll(loot.prop.lootTable, multiplier))

    dispatchSmashGrab('claimed', vehicle, loot)

    if #granted == 0 then
        Integrations.notify(source, locale('sg_empty'), 'inform')
    else
        Integrations.notify(source, locale('sg_looted', Loot.describe(granted)), 'success')
        Integrations.recordActivity(source, CrimeServerConfig.progressionActivity,
            Integrations.transactionId(), { prop = loot.propKey, rewards = #granted })
    end

    DebugPrint(('%s levou %s do netId %s (%d recompensas)')
        :format(source, loot.propKey, netId, #granted))
    return { ok = true }
end

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------

local function registerDebugCommands()
    ---Força objeto no veículo mais próximo de quem chamou, escrevendo a placa numa
    ---lista que os dois lados leem. Não é um atalho de teste que mente: com a
    ---placa na lista, `Rules.resolve` devolve objeto para todo mundo, e o `claim`
    ---passa pela mesma validação de sempre.
    lib.addCommand('spawnsmashloot', {
        help = 'Força um objeto de smash & grab no veículo mais próximo (debug)',
        restricted = ServerConfig.debugAce,
    }, function(source)
        local ped = GetPlayerPed(source)
        if ped == 0 then return end

        local coords = GetEntityCoords(ped)
        local closest, closestDistance

        local vehicles = GetAllVehicles()
        for index = 1, #vehicles do
            local vehicle = vehicles[index]
            local distance = #(coords - GetEntityCoords(vehicle))
            if distance < (closestDistance or 15.0) then
                closest, closestDistance = vehicle, distance
            end
        end

        if not closest then
            return Integrations.notify(source, 'Nenhum veículo a 15m.', 'error')
        end

        local netId = NetworkGetNetworkIdFromEntity(closest)
        if netId == 0 then
            return Integrations.notify(source, 'Veículo não está em rede.', 'error')
        end

        Reservations.forget(netId)
        local loot = Spawn.force(netId, closest)

        Integrations.notify(source, ('Forçado no netId %d: %s no %s'):format(
            netId, loot and loot.propKey or '?', loot and loot.seatKey or '?'), 'success')
        lib.print.info(('spawnsmashloot: netId %d -> %s / %s'):format(
            netId, loot and loot.propKey or '?', loot and loot.seatKey or '?'))
    end)

    lib.addCommand('smashstate', {
        help = 'Mostra quantos objetos estão reservados e levados (debug)',
        restricted = ServerConfig.debugAce,
    }, function(source)
        local reserved, claimed = Reservations.counts()
        Integrations.notify(source, ('decididos: %d | reservados: %d | levados: %d')
            :format(Spawn.count(), reserved, claimed), 'inform')
        lib.print.info(('smashstate: decididos %d, reservados %d, levados %d')
            :format(Spawn.count(), reserved, claimed))
    end)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function module.start()
    lib.callback.register(EVENT_SURVEY, handleSurvey)
    lib.callback.register(EVENT_BREAK, handleBreak)
    lib.callback.register(EVENT_RESERVE, handleReserve)
    lib.callback.register(EVENT_RELEASE, handleRelease)
    lib.callback.register(EVENT_CLAIM, handleClaim)

    -- Manutenção: netId de carro que já sumiu não precisa continuar guardado.
    -- Intervalo longo de propósito — isto não é caminho quente.
    SetTimeout(PRUNE_INTERVAL, function()
        local function loop()
            local removed = Reservations.prune() + Spawn.prune()
            if removed > 0 then DebugPrint(('limpeza: %d netIds descartados'):format(removed)) end
            SetTimeout(PRUNE_INTERVAL, loop)
        end
        loop()
    end)

    if SharedConfig.debug then registerDebugCommands() end
end

---@param source number
function module.onPlayerDropped(source)
    Reservations.releaseAllFor(source)
end

return module
