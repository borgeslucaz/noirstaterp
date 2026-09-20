---Parquímetro — ponto de entrada do client.
---
---**Este módulo não tem thread.** Nenhuma. É a diferença mais visível para o
---smash & grab, que precisa varrer o pool de veículos a cada 1,5 s para descobrir
---quais carros existem por perto.
---
---Aqui não há o que varrer: o alvo é registrado por MODEL no ox_target, e todo
---parquímetro que o streaming carregar — agora ou daqui a uma hora, na outra
---ponta do mapa — já nasce com a opção. O custo em `resmon` com o jogador parado
---é zero.
---
---O registro do alvo é a ÚNICA parte do crime que fala com o ox_target direto,
---sem passar pelo `bgrz_core`. O resto — notificação, item, dinheiro, dispatch —
---continua pelo bridge. A chamada mora em `client/integrations.lua`, com o
---motivo escrito lá.
---
---O que sobra para este arquivo: pendurar o alvo, manter a lista de postes já
---esvaziados em dia, e tirar tudo no stop.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local SharedConfig = require 'config.shared'
local CrimeConfig = require 'config.parkingmeter'
local Rules = require 'shared.parkingmeter_rules'
local Integrations = require 'client.integrations'
local State = require 'client.crimes.parkingmeter.state'
local Interaction = require 'client.crimes.parkingmeter.interaction'

local CRIME = Constants.crimes.parkingmeter
local DebugPrint = Utils.debugPrint(CRIME)

local EVENT_SYNC = Constants.event('server', CRIME, 'sync')
local EVENT_EMPTIED = Constants.event('client', CRIME, 'emptied')
local EVENT_DUMP = Constants.event('client', CRIME, 'dump')
local EVENT_DIAG = Constants.event('client', CRIME, 'diag')

local OPTION_ROB = ('%s:%s:rob'):format(Constants.resource, CRIME)

local module = {}
local running = false

---O alvo chegou a ser registrado, e se não, por quê.
---
---Guardado porque é a pergunta que o `/meterdiag` responde. Com `Config.debug`
---desligado o sucesso não deixa rastro nenhum no console, então sem isto a
---única forma de saber se o alvo subiu era ir até um poste e olhar.
local attached = false
local attachError = nil

-- ---------------------------------------------------------------------------
-- Sincronização
-- ---------------------------------------------------------------------------

---Pede a lista completa de postes vazios.
---
---Numa thread porque `lib.callback.await` cede, e o `start()` do container não
---pode ficar pendurado esperando rede — um crime lento atrasaria o boot dos
---outros. Enquanto a resposta não chega, a lista fica vazia: o pior caso é o
---jogador ver o alvo de um poste que o servidor vai recusar, e a recusa já tem
---mensagem própria.
local function requestSnapshot()
    CreateThread(function()
        local snapshot = lib.callback.await(EVENT_SYNC, CrimeConfig.callbackTimeout)
        if not running then return end
        State.applySnapshot(snapshot)
    end)
end

---Aviso de um poste que acabou de ser esvaziado (ou reabastecido, com duração 0).
---@param key any
---@param duration any ms
local function onEmptied(key, duration)
    State.markEmptied(key, duration)
end

-- ---------------------------------------------------------------------------
-- Alvo
-- ---------------------------------------------------------------------------

local function attachTarget()
    local ok, err = Integrations.addModelTarget(CrimeConfig.models, {
        {
            name = OPTION_ROB,
            icon = CrimeConfig.icon,
            label = locale('pm_target_rob'),
            distance = CrimeConfig.targetDistance,
            -- As duas assinaturas do ox_target são DIFERENTES, e confundi-las
            -- não dá erro de carregamento — dá erro no clique:
            --
            --   canInteract(entity, distance, coords, name, bone)  <- entity cru
            --   onSelect(response)                                 <- TABELA
            --
            -- O `response` é um clone da option com `entity`, `coords`,
            -- `distance` e `zone` acrescentados. Passá-lo inteiro adiante faz o
            -- `GetEntityModel` receber uma tabela e o cliente cospe
            -- "Failed to parse integer from string" — mensagem que não aponta
            -- para lugar nenhum perto daqui.
            canInteract = function(entity)
                local key = Interaction.keyFor(entity)
                if State.isEmptied(key) then return false end
                return Interaction.canStart(key)
            end,
            onSelect = function(response)
                Interaction.rob(type(response) == 'table' and response.entity or response)
            end,
        },
    })

    if not ok then
        -- Mandar "veja o erro no console" quando o console só diz um código não
        -- ajuda ninguém; cada causa tem uma ação diferente.
        if err == 'provider_unavailable' then
            lib.print.error(
                'ox_target não está started; o alvo do parquímetro não foi registrado.')
        else
            lib.print.error(('não foi possível registrar o alvo do parquímetro: %s')
                :format(tostring(err)))
        end
        attached, attachError = false, err or 'unknown'
        return false
    end

    attached, attachError = true, nil
    DebugPrint(('alvo registrado em %d models'):format(#CrimeConfig.models))
    return true
end

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------

---Todos os parquímetros carregados em volta do jogador.
---@param radius number
---@return { entity: number, key: string, distance: number }[]
local function nearbyMeters(radius)
    local playerCoords = GetEntityCoords(cache.ped)
    local found = {}

    local objects = GetGamePool('CObject')
    for index = 1, #objects do
        local object = objects[index]
        if Rules.isAllowedModel(GetEntityModel(object)) then
            local coords = GetEntityCoords(object)
            local distance = #(playerCoords - coords)
            if distance <= radius then
                found[#found + 1] = {
                    entity = object,
                    key = Rules.meterKey(coords),
                    distance = distance,
                }
            end
        end
    end

    table.sort(found, function(a, b) return a.distance < b.distance end)
    return found
end

---Levanta as chaves dos postes em volta, prontas para colar em `positions` de
---`config/parkingmeter_server.lua`. É o caminho de quem quer trocar a allowlist
---por área pela allowlist estrita: rode por alguns bairros, junte a saída e cole.
---
---**Não é comando de debug, é ferramenta de setup**, e por isso não depende de
---`Config.debug`. Quem chama é o servidor, por um comando atrás de `debugAce`:
---a lista dos postes do mapa não é coisa que qualquer jogador deva conseguir
---pedir, e o client não tem como conferir ACE sozinho.
---@param radius any
local function dumpNearby(radius)
    if not Utils.isFinite(radius) or radius <= 0 then radius = 100.0 end
    if radius > 500.0 then radius = 500.0 end

    local meters = nearbyMeters(radius)
    if #meters == 0 then
        return Integrations.notify(('Nenhum parquímetro em %.0fm.'):format(radius), 'error')
    end

    lib.print.info(('dumpmeters: %d postes em %.0fm'):format(#meters, radius))
    for index = 1, #meters do
        local meter = meters[index]
        local coords = GetEntityCoords(meter.entity)
        lib.print.info(("    ['%s'] = true, -- %.2f, %.2f, %.2f")
            :format(meter.key, coords.x, coords.y, coords.z))
    end
    Integrations.notify(('%d postes no console (F8).'):format(#meters), 'success')
end

---Percorre a cadeia inteira e diz em qual elo ela quebrou.
---
---Existe porque este módulo tem dependências em série — ox_target de pé, export
---presente, alvo registrado, bgrz_core de pé, personagem carregado — e quando o
---alvo não aparece o sintoma é o mesmo em todas: nada. Sem isto, a investigação
---é reiniciar resources na sorte, que foi exatamente como este comando nasceu.
---
---Como o `/dumpmeters`, é ferramenta de setup: não depende de `Config.debug` e
---quem chama é o servidor, atrás de `debugAce`.
local function diagnose()
    -- Tudo pelas sondas do `integrations.lua`: este arquivo não cita outro
    -- resource pelo nome, nem para diagnosticar.
    local coreState = Integrations.coreState()
    local targetState = Integrations.targetState()
    local hasExport = Integrations.hasModelTarget()

    local nearby = nearbyMeters(50.0)
    local nearest = nearby[1]

    local lines = {
        ('bgrz_core: %s'):format(coreState),
        ('ox_target: %s'):format(targetState),
        ('export ox_target:addModel: %s'):format(hasExport and 'presente' or 'AUSENTE'),
        ('alvo registrado: %s%s'):format(attached and 'sim' or 'NÃO',
            attached and '' or (' (' .. tostring(attachError) .. ')')),
        ('módulo rodando: %s'):format(running and 'sim' or 'NÃO'),
        ('personagem carregado: %s'):format(Integrations.isLoggedIn() and 'sim' or 'NÃO'),
        ('a pé: %s'):format(cache.vehicle and 'NÃO (dentro de veículo)' or 'sim'),
        ('models na allowlist: %d'):format(#CrimeConfig.models),
        ('postes num raio de 50m: %d'):format(#nearby),
        ('lista local de vazios: %d'):format(State.count()),
    }

    if nearest then
        lines[#lines + 1] = ('poste mais próximo: %s a %.2fm, %s'):format(
            nearest.key, nearest.distance,
            State.isEmptied(nearest.key) and 'ESVAZIADO' or 'disponível')
        lines[#lines + 1] = ('alcance do alvo: %.1fm (targetDistance)'):format(
            CrimeConfig.targetDistance)
    end

    lib.print.info('--- meterdiag ---')
    for index = 1, #lines do lib.print.info('  ' .. lines[index]) end

    -- O primeiro elo quebrado é o que interessa; os seguintes são consequência.
    local verdict
    if targetState ~= 'started' then
        verdict = 'ox_target não está started'
    elseif not hasExport then
        verdict = 'ox_target nao expoe addModel; confira a versao do ox_target'
    elseif not attached then
        verdict = ('o alvo não foi registrado (%s)'):format(tostring(attachError))
    elseif coreState ~= 'started' then
        -- O bridge não entra mais no caminho do ALVO, mas o roubo em si morre
        -- sem ele: notificação, item, dinheiro e dispatch continuam passando
        -- por lá. O alvo apareceria e toda tentativa seria recusada.
        verdict = 'bgrz_core não está started: o alvo aparece, mas o roubo será recusado'
    elseif not Integrations.isLoggedIn() then
        verdict = 'personagem não carregado'
    elseif #nearby == 0 then
        verdict = 'nenhum parquímetro por perto — vá até uma calçada do centro'
    else
        verdict = 'a cadeia está inteira; chegue a menos de '
            .. ('%.1fm do poste'):format(CrimeConfig.targetDistance)
    end

    lib.print.info('  => ' .. verdict)
    Integrations.notify(verdict, attached and 'inform' or 'error')
end

local function registerDebugCommands()
    ---Explica o poste mais próximo: qual é a chave dele e por que ele está ou não
    ---disponível. É o comando que responde "por que esse não dá para arrombar".
    RegisterCommand('meterinfo', function()
        local meters = nearbyMeters(CrimeConfig.maxDistance * 2)
        if #meters == 0 then
            return Integrations.notify('Nenhum parquímetro por perto.', 'error')
        end

        local meter = meters[1]
        local emptied = State.isEmptied(meter.key)
        local reason = emptied and 'já foi esvaziado'
            or (not Interaction.canStart(meter.key) and 'o client não deixa começar agora')
            or nil

        lib.print.info(('meterinfo: chave %s | %.2fm | %s'):format(
            meter.key, meter.distance, reason or 'disponível'))
        lib.print.info(('meterinfo: %d postes na lista local de vazios'):format(State.count()))

        -- O client só conhece metade da resposta: área permitida, teto por hora e
        -- ferramenta são do servidor, e ele não recebe nada disso.
        Integrations.notify(('%s — %s'):format(meter.key, reason or 'disponível pelo client'),
            reason and 'error' or 'success')
    end, false)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

-- No escopo do arquivo, e não dentro do `start()`: registrar handler dentro de
-- uma função que pode ser chamada duas vezes é como se acumulam handlers
-- duplicados. O `running` cuida de o módulo parado não reagir a nada.
RegisterNetEvent(EVENT_EMPTIED, function(key, duration)
    if not running then return end
    onEmptied(key, duration)
end)

-- Sem guarda de `running`: o levantamento serve justamente para investigar um
-- módulo que não subiu, e o servidor só manda este evento para quem passou pela
-- ACE de admin.
RegisterNetEvent(EVENT_DUMP, dumpNearby)

-- Sem guarda de `running` pelo mesmo motivo, e aqui ela seria contraproducente:
-- o diagnóstico serve justamente para o caso em que o módulo NÃO está rodando.
RegisterNetEvent(EVENT_DIAG, diagnose)

-- Evento local do bridge, então `AddEventHandler` e não `RegisterNetEvent`
-- (§24, Segurança). Trocar de personagem precisa de um snapshot novo: a lista
-- que estava na tela é do personagem anterior, e meia hora de cooldown é tempo
-- suficiente para ela ter envelhecido.
AddEventHandler('bgrz_core:client:playerLoaded', function()
    if not running then return end
    requestSnapshot()
end)

function module.start()
    -- Os comandos de debug entram ANTES do alvo, e de propósito.
    --
    -- Na ordem inversa, um `attachTarget` que falha — bgrz_core velho sem
    -- ox_target fora do ar, por exemplo — levava o `return` junto e o
    -- módulo ficava sem os comandos justamente na hora em que eles seriam
    -- úteis. Quem fosse investigar ouvia "Not allowed to execute command" e não
    -- tinha como saber que o problema era outro, três camadas abaixo.
    if SharedConfig.debug then
        registerDebugCommands()
        DebugPrint('comandos /dumpmeters e /meterinfo registrados')
    end

    if not attachTarget() then return end

    running = true
    requestSnapshot()
end

function module.stop()
    running = false
    State.clear()
    -- O `bgrz_core` também limparia isto sozinho no stop do resource; remover
    -- aqui é explícito de propósito, para o módulo não depender de o bridge
    -- lembrar dele (§21.2).
    Integrations.removeModelTarget(CrimeConfig.models, { OPTION_ROB })
end

return module
