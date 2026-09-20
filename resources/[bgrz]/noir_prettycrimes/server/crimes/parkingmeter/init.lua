---Parquímetro — lado servidor.
---
---Três pedidos: `reserve` tranca o poste, `claim` entrega, `release` devolve se o
---jogador desistiu. Mais um `sync`, que é só o client pedindo a lista de postes
---já esvaziados quando entra.
---
---A pergunta difícil deste módulo, e a razão de ele não se parecer com o smash &
---grab, é esta: **o servidor não consegue ver o poste.** Prop de mapa não existe
---do lado de cá; não há `NetworkGetEntityFromNetworkId`, não há
---`GetEntityCoords`, não há o que resolver. O `Security.resolveEntity`, que é a
---espinha da validação do outro crime, não tem o que fazer aqui.
---
---O que existe para validar, e é o que este arquivo faz, em ordem de custo:
---
---  1. rate limit, antes de qualquer trabalho;
---  2. o model precisa estar na allowlist (§7.4);
---  3. a coordenada precisa ser um número plausível;
---  4. o JOGADOR precisa estar nela — medido com a posição server-side do ped,
---     que é a única coordenada desta troca em que se pode confiar;
---  5. a coordenada precisa cair numa área onde parquímetro existe, ou na
---     allowlist estrita de `positions` quando ela estiver preenchida;
---  6. o poste não pode estar vazio nem reservado por outro;
---  7. o jogador precisa estar abaixo do teto por hora e fora do cooldown;
---  8. a ferramenta precisa estar no inventário, conferida no servidor.
---
---O passo 4 é o que sustenta os outros: sem ele, coordenada seria só um número no
---payload. Com ele, o cheater precisa estar fisicamente onde diz que está, e o
---passo 7 limita quanto isso vale.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local SharedConfig = require 'config.shared'
local ServerConfig = require 'config.server'
local CrimeConfig = require 'config.parkingmeter'
local CrimeServerConfig = require 'config.parkingmeter_server'
local Rules = require 'shared.parkingmeter_rules'
local Security = require 'server.security'
local Integrations = require 'server.integrations'
local Registry = require 'server.crimes.parkingmeter.registry'
local Sessions = require 'server.crimes.parkingmeter.sessions'
local Loot = require 'server.crimes.parkingmeter.loot'

local CRIME = Constants.crimes.parkingmeter
local DebugPrint = Utils.debugPrint(CRIME)

local EVENT_SYNC = Constants.event('server', CRIME, 'sync')
local EVENT_RESERVE = Constants.event('server', CRIME, 'reserve')
local EVENT_RELEASE = Constants.event('server', CRIME, 'release')
local EVENT_CLAIM = Constants.event('server', CRIME, 'claim')
local EVENT_EMPTIED = Constants.event('client', CRIME, 'emptied')
local EVENT_DUMP = Constants.event('client', CRIME, 'dump')

local PRUNE_INTERVAL = 300000

local module = {}

---A allowlist estrita está em uso? Calculado uma vez: a config é imutável em
---runtime (§19.2), e perguntar `next()` a cada pedido seria trabalho por nada.
local strictPositions = type(CrimeServerConfig.positions) == 'table'
    and next(CrimeServerConfig.positions) ~= nil

-- ---------------------------------------------------------------------------
-- Validação
-- ---------------------------------------------------------------------------

---Resolve o pedido do client em uma chave de poste aceita.
---
---Devolve chave, ou nil e o código de recusa. Nenhum caminho aqui cede a thread:
---tudo é leitura de tabela e aritmética, e é isso que permite que o `reserve` que
---vem depois seja indivisível.
---@param source number
---@param coords any
---@param model any
---@return string? key
---@return string? errorCode
local function resolveMeter(source, coords, model)
    if not Security.isValidPlayer(source) then return nil, 'invalid_player' end
    if not Rules.isAllowedModel(model) then
        DebugPrint(('model fora da allowlist de %s: %s'):format(source, tostring(model)))
        return nil, 'not_eligible'
    end

    local key = Rules.meterKey(coords)
    if not key then
        DebugPrint(('coordenada inválida de %s'):format(source))
        return nil, 'not_eligible'
    end

    -- A distância é medida com a coordenada que o SERVIDOR tem do jogador contra
    -- a que o client disse do poste. O jogador é a âncora: ele existe dos dois
    -- lados, o poste não.
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local distance = Rules.flatDistance(playerCoords, coords)
    if not distance or distance > CrimeConfig.maxDistance then
        DebugPrint(('%s longe demais do poste: %s'):format(source, tostring(distance)))
        return nil, 'too_far'
    end

    if strictPositions then
        if not CrimeServerConfig.positions[key] then
            DebugPrint(('poste fora da allowlist estrita: %s'):format(key))
            return nil, 'not_eligible'
        end
    elseif not Rules.inAnyArea(coords, CrimeServerConfig.areas) then
        DebugPrint(('poste fora das áreas permitidas: %s'):format(key))
        return nil, 'not_eligible'
    end

    return key
end

-- ---------------------------------------------------------------------------
-- Fachada
-- ---------------------------------------------------------------------------

---Avisa todo mundo que um poste ficou vazio.
---
---Vai para `-1` porque prop de mapa não tem state bag: não há entidade em que
---publicar o estado para os clients lerem. O payload é uma chave curta e uma
---duração, e a informação é pública de qualquer jeito — quem passar na calçada vê
---a portinhola arrombada.
---@param key string
---@param seconds integer
local function broadcastEmptied(key, seconds)
    TriggerClientEvent(EVENT_EMPTIED, -1, key, seconds * 1000)
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

---Ponto único de alerta policial do módulo.
---@param stage 'reserved'|'claimed'
---@param coords any
local function dispatchMeter(stage, coords)
    local trigger = CrimeServerConfig.dispatch.trigger
    if trigger ~= stage and trigger ~= 'both' then return end
    if not Utils.chance(CrimeServerConfig.dispatch.chance) then return end

    Integrations.dispatch({
        title = locale('pm_dispatch_title'),
        message = locale('pm_dispatch_message'),
        -- A coordenada do ALERTA é a do jogador, não a que o client mandou: um
        -- payload forjado não pode mandar a polícia para o outro lado do mapa.
        coords = coords,
        code = CrimeServerConfig.dispatch.code,
    })
end

-- ---------------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------------

---O client acabou de entrar e quer saber quais postes já estão vazios.
---@param source number
---@return table<string, integer>? snapshot key -> ms restantes
local function handleSync(source)
    if not Security.rateLimit(source, CRIME .. ':sync', 10000) then return nil end
    if not Security.isValidPlayer(source) then return nil end
    return Registry.snapshot()
end

---@param source number
---@param coords any
---@param model any
---@return { ok: boolean, code?: string }
local function handleReserve(source, coords, model)
    -- Anti-spam primeiro, antes de qualquer trabalho. É curto de propósito: a
    -- espera longa entre dois arrombamentos é cobrada mais abaixo, e só de quem
    -- de fato levou moedas.
    if not Security.rateLimit(source, CRIME, CrimeServerConfig.attemptInterval) then
        return { ok = false, code = 'busy' }
    end
    -- Falhar aqui poupa o jogador de fazer o minigame e as duas barras para
    -- descobrir no fim que não havia como pagar.
    if not Integrations.coreReady() then
        return { ok = false, code = 'provider_unavailable' }
    end

    local key, resolveError = resolveMeter(source, coords, model)
    if not key then return { ok = false, code = resolveError } end

    if Registry.isEmptied(key) then return { ok = false, code = 'already_taken' } end

    -- Identidade pelo citizenId: `source` é o canal, não a pessoa (§12.6), e
    -- reconectar não pode zerar o teto.
    local citizenId = Integrations.getCitizenId(source)
    if not citizenId then return { ok = false, code = 'provider_unavailable' } end

    local cooldownLeft = Registry.claimCooldownLeft(citizenId)
    if cooldownLeft > 0 then
        DebugPrint(('%s ainda em cooldown: %ds'):format(source, cooldownLeft))
        return { ok = false, code = 'cooldown' }
    end

    local allowed, count = Registry.underCap(citizenId)
    if not allowed then
        DebugPrint(('%s no teto: %d na janela'):format(source, count))
        return { ok = false, code = 'too_much_heat' }
    end

    if CrimeServerConfig.tool.required
        and not Integrations.firstItemOwned(source, CrimeServerConfig.tool.items) then
        return { ok = false, code = 'no_tool' }
    end

    local ok, reserveError = Sessions.reserve(key, source, citizenId)
    if not ok then return { ok = false, code = reserveError } end

    dispatchMeter('reserved', GetEntityCoords(GetPlayerPed(source)))
    return { ok = true }
end

---@param source number
---@param coords any
---@return { ok: boolean }
local function handleRelease(source, coords)
    local key = Rules.meterKey(coords)
    if not key then return { ok = false } end
    -- Sem revalidar nada além da chave: devolver o que é seu nunca pode falhar
    -- por o jogador ter andado dois metros no meio do cancelamento.
    Sessions.release(key, source)
    return { ok = true }
end

---@param source number
---@param coords any
---@param model any
---@return { ok: boolean, code?: string, reward?: string }
local function handleClaim(source, coords, model)
    -- A reserva é conferida antes de qualquer trabalho: quem não reservou não
    -- chega perto do sorteio, mesmo chamando o evento à mão.
    local key = Rules.meterKey(coords)
    if not key then return { ok = false, code = 'mismatch' } end
    if Sessions.holder(key) ~= source then
        return { ok = false, code = Registry.isEmptied(key) and 'already_taken' or 'reserved' }
    end

    -- Revalida o mundo do zero: entre reservar e entregar o jogador pode ter
    -- andado, morrido ou entrado num carro.
    local resolved, resolveError = resolveMeter(source, coords, model)
    if not resolved or resolved ~= key then
        Sessions.release(key, source)
        return { ok = false, code = resolveError or 'mismatch' }
    end

    -- O core pode ter caído entre a reserva e agora. Conferir ANTES de fechar a
    -- sessão: marcar o poste como vazio e só então descobrir que não dá para
    -- conceder esvaziaria o poste sem pagar ninguém.
    if not Integrations.coreReady() then
        return { ok = false, code = 'provider_unavailable' }
    end

    local tool
    if CrimeServerConfig.tool.required then
        tool = Integrations.firstItemOwned(source, CrimeServerConfig.tool.items)
        if not tool then return { ok = false, code = 'no_tool' } end
    end

    local minElapsed = math.floor(Rules.totalDuration() * CrimeServerConfig.minElapsedFactor)
    local ok, claimError, citizenId = Sessions.claim(key, source, minElapsed)
    if not ok then return { ok = false, code = claimError } end

    -- Daqui para baixo o poste já é deste pedido. Marcar e avisar ANTES de
    -- conceder: se o provider falhar no meio, o poste fica vazio e o jogador não
    -- recebe — o inverso (pagar e não marcar) deixaria o mesmo poste pagando de
    -- novo, que é o erro que não se conserta sozinho.
    local seconds = Registry.markEmptied(key)
    broadcastEmptied(key, seconds)
    Registry.addHeat(citizenId or Integrations.getCitizenId(source) or tostring(source))

    local granted = Loot.grant(source, Loot.roll())

    if tool and Utils.chance(CrimeServerConfig.tool.breakChance) then
        if Integrations.removeItem(source, tool, 1) then
            Integrations.notify(source, locale('pm_tool_broke', Integrations.itemLabel(tool)), 'error')
        end
    end

    dispatchMeter('claimed', GetEntityCoords(GetPlayerPed(source)))

    if #granted == 0 then
        Integrations.notify(source, locale('pm_empty'), 'inform')
    else
        Integrations.notify(source, locale('pm_looted', Loot.describe(granted)), 'success')
        Integrations.recordActivity(source, CrimeServerConfig.progressionActivity,
            Integrations.transactionId(), { meter = key, rewards = #granted })
    end

    DebugPrint(('%s esvaziou o poste %s (%d recompensas)'):format(source, key, #granted))
    return { ok = true }
end

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------

---Levantamento das posições dos postes, para preencher `positions`.
---
---Fica FORA de `registerDebugCommands` de propósito. É ferramenta de setup, não
---de debug: quem precisa dela precisa num servidor de produção, com o
---`Config.debug` desligado, e amarrá-la à flag obrigava a ligar o debug inteiro
---— que também libera comando de client para qualquer jogador — só para
---levantar uma lista.
---
---A ACE é a trava certa aqui: o mapa dos parquímetros não é informação que um
---jogador qualquer deva conseguir pedir, e o client não tem como conferir ACE
---sozinho. Por isso o comando é do SERVIDOR e só manda o evento para quem
---passou.
local function registerSetupCommands()
    lib.addCommand('dumpmeters', {
        help = 'Lista no seu F8 as chaves dos parquímetros em volta, para `positions`',
        restricted = ServerConfig.debugAce,
        params = {
            { name = 'raio', type = 'number', help = 'metros (padrão 100, máx 500)', optional = true },
        },
    }, function(source, args)
        TriggerClientEvent(EVENT_DUMP, source, args.raio)
    end)

    lib.addCommand('meterdiag', {
        help = 'Diz em qual elo a cadeia do parquímetro quebrou (bridge, target, alvo, sessão)',
        restricted = ServerConfig.debugAce,
    }, function(source)
        TriggerClientEvent(EVENT_DIAG, source)

        -- A metade do servidor não aparece no F8 de quem chamou, então ela sai
        -- no console do servidor: são justamente as travas que o client não
        -- enxerga, e que explicam a recusa que ele não sabe explicar.
        local emptiedCount, players = Registry.counts()
        lib.print.info('--- meterdiag (servidor) ---')
        lib.print.info(('  allowlist: %s'):format(
            strictPositions and 'estrita (positions)' or 'por área'))
        lib.print.info(('  áreas configuradas: %d'):format(#CrimeServerConfig.areas))
        lib.print.info(('  postes vazios: %d | reservas: %d | jogadores com histórico: %d')
            :format(emptiedCount, Sessions.counts(), players))
        lib.print.info(('  ferramenta exigida: %s'):format(
            CrimeServerConfig.tool.required
                and table.concat(CrimeServerConfig.tool.items, ', ') or 'nenhuma'))

        local citizenId = Integrations.getCitizenId(source)
        if not citizenId then
            lib.print.info('  citizenId: INDISPONÍVEL (bgrz_core fora do ar?)')
            return
        end

        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        lib.print.info(('  %s: %d/%s na janela, cooldown %ds')
            :format(citizenId, Registry.heatCount(citizenId),
                tostring(CrimeServerConfig.maxPerHour), Registry.claimCooldownLeft(citizenId)))
        lib.print.info(('  está em área permitida: %s'):format(
            tostring(Rules.inAnyArea(playerCoords, CrimeServerConfig.areas))))
        lib.print.info(('  tem a ferramenta: %s'):format(
            tostring(Integrations.firstItemOwned(source, CrimeServerConfig.tool.items) or false)))
    end)
end

local function registerDebugCommands()
    lib.addCommand('meterstate', {
        help = 'Mostra postes vazios, reservas e o teto por jogador (debug)',
        restricted = ServerConfig.debugAce,
    }, function(source)
        local emptiedCount, players = Registry.counts()
        local message = ('vazios: %d | reservados: %d | jogadores com histórico: %d')
            :format(emptiedCount, Sessions.counts(), players)
        Integrations.notify(source, message, 'inform')
        lib.print.info('meterstate: ' .. message)

        local citizenId = Integrations.getCitizenId(source)
        if citizenId then
            lib.print.info(('meterstate: %s fez %d na janela (teto %s)'):format(
                citizenId, Registry.heatCount(citizenId), tostring(CrimeServerConfig.maxPerHour)))
        end
    end)

    lib.addCommand('meterreset', {
        help = 'Devolve as moedas a todos os postes esvaziados (debug)',
        restricted = ServerConfig.debugAce,
    }, function(source)
        local snapshot = Registry.snapshot()
        local keys = Utils.sortedKeys(snapshot)
        for index = 1, #keys do
            Registry.forget(keys[index])
            -- Duração zero é como o client entende "voltou a ter moedas".
            TriggerClientEvent(EVENT_EMPTIED, -1, keys[index], 0)
        end
        Integrations.notify(source, ('%d postes reabastecidos.'):format(#keys), 'success')
        lib.print.info(('meterreset: %d postes reabastecidos'):format(#keys))
    end)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function module.start()
    lib.callback.register(EVENT_SYNC, handleSync)
    lib.callback.register(EVENT_RESERVE, handleReserve)
    lib.callback.register(EVENT_RELEASE, handleRelease)
    lib.callback.register(EVENT_CLAIM, handleClaim)

    if strictPositions then
        lib.print.info(('parkingmeter: allowlist estrita com %d postes')
            :format(#Utils.sortedKeys(CrimeServerConfig.positions)))
    end

    -- Manutenção: chave vencida não precisa continuar guardada. Intervalo longo
    -- de propósito — isto não é caminho quente, e a expiração preguiçosa já
    -- garante a correção.
    SetTimeout(PRUNE_INTERVAL, function()
        local function loop()
            local removed = Registry.prune() + Sessions.prune()
            if removed > 0 then DebugPrint(('limpeza: %d entradas descartadas'):format(removed)) end
            SetTimeout(PRUNE_INTERVAL, loop)
        end
        loop()
    end)

    registerSetupCommands()
    if SharedConfig.debug then registerDebugCommands() end
end

---@param source number
function module.onPlayerDropped(source)
    Sessions.releaseAllFor(source)
end

return module
