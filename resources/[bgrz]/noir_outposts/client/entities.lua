-- Entidades do client: alvos dos dealers (peds criados pelo servidor) e o atendente
-- local do terminal, que existe apenas para dar um alvo visível enquanto não há MLO.
NoirOutposts = NoirOutposts or {}

local Entities = {}
NoirOutposts.Entities = Entities

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

local tracked = {}
local trackedEntity = {}
local terminals = {}
---@type table<string, boolean>
local wantedTerminals = {}
---Falha de criação se repete a cada volta do laço. O aviso não.
local terminalWarned = {}

---@param outpostId string
---@param message string
local function warnOnce(outpostId, message)
    if terminalWarned[outpostId] then return end
    terminalWarned[outpostId] = true
    lib.print.warn(('[noir_outposts] %s'):format(message))
end

local function optionNames()
    return { 'dealer:inspect', 'dealer:rob' }
end

---Âncora da caminhada: a esquina cadastrada, lida do state bag.
---Sem ela o ped andaria a partir de onde estivesse, e derivaria a cada novo stream.
---@param entity integer
---@return vector3?
local function wanderAnchor(entity)
    local state = Entity(entity).state
    local outpostId = state[C.StateBag.OUTPOST]
    local cornerIndex = state[C.StateBag.DEALER_CORNER]
    local definition = type(outpostId) == 'string' and shared.outposts[outpostId] or nil
    local corner = definition and type(cornerIndex) == 'number'
        and definition.dealerCorners[cornerIndex] or nil
    if not corner then return nil end
    return vector3(corner.x, corner.y, corner.z)
end

---Só o dono de rede conduz a IA de um ped. Tarefa dada por quem não é dono é descartada.
---@param entity integer
---@return boolean
local function ownsEntity(entity)
    return NetworkGetEntityOwner(entity) == cache.playerId
end

---Última tentativa de caminhada por net ID, para o diagnóstico dizer onde ela parou.
local wanderReport = {}

---@param netId integer
---@return string
function Entities.wanderReport(netId)
    return wanderReport[netId] or 'nunca tentada'
end

---Estado da caminhada por net ID. Um único loop conduz todos, em vez de uma thread por ped.
---@type table<integer, { anchor: vector3, target: vector3?, taskedAt: integer, nextAt: integer,
---holding: boolean?, returning: boolean?, lastPosition: vector3?, stalled: integer? }>
local walks = {}

-- Corredor fixado no lugar porque não está caminhando: em recuperação, ou em serviço mas sem
-- caminhada possível. Guarda o estado que motivou a fixação, para não retarefar a cada tique.
---@type table<integer, string>
local pinned = {}

-- Quem já assumiu a caminhada de um ped. A propriedade de rede migra conforme os jogadores se
-- movem, e só o dono conduz a IA; isto faz quem assumir reaplicar a caminhada uma vez.
---@type table<integer, boolean>
local wanderOwned = {}

-- Reação de abordagem em curso, por net ID.
-- O state bag é a verdade do servidor, mas é encaminhado por outro caminho que o evento e pode
-- chegar depois dele. Nessa janela a manutenção da caminhada ainda leria `deployed` e retomaria
-- o ped por cima da rendição, que era o que fazia o corredor voltar a andar com a arma apontada.
-- Por isso a reação recém-recebida tem precedência por um tempo curto, e depois o bag manda.
local reactions = {}
local reactionApplied = {}
local applyReaction

---Põe um ponto no chão. Boa parte do mapa não tem malha de navegação de pedestre, docas e
---pátios industriais inclusive, então a malha é a primeira opção e não a única: sem ela vale
---o chão bruto, e o corredor caminha em linha reta em vez de usar rotas.
---@param x number
---@param y number
---@param z number
---@return vector3? point, boolean navigable
local function groundedPoint(x, y, z)
    local found, safe = GetSafeCoordForPed(x, y, z, true, 16)
    if found and safe then return vector3(safe.x, safe.y, safe.z), true end

    local hasGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    -- Sem chão o ponto é água ou vazio, e aí não serve como destino.
    if hasGround then return vector3(x, y, groundZ), false end

    return nil, false
end

---Há caminho livre entre dois pontos, na altura do peito. Sem malha de navegação não há
---rota a calcular, então é isto que impede o corredor de sair andando contra a parede.
---@param entity integer ped que deve ser ignorado no teste
---@param from vector3
---@param to vector3
---@return boolean
local function hasClearPath(entity, from, to)
    -- Mundo, veículos e objetos. Peds ficam de fora: outro corredor no caminho não é parede.
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        from.x, from.y, from.z + 0.9,
        to.x, to.y, to.z + 0.9,
        1 + 2 + 16, entity, 4)
    local _, hit = GetShapeTestResult(handle)
    return hit == 0 or hit == false
end

---Ponto aleatório dentro do raio, a pelo menos `minimalLength` da posição atual.
---@param entity integer
---@param anchor vector3
---@param from vector3
---@return vector3? destination, boolean navigable
local function pickDestination(entity, anchor, from)
    local wander = shared.dealerWander
    for _ = 1, 10 do
        local angle = math.random() * math.pi * 2
        local distance = wander.minimalLength
            + math.random() * math.max(0.0, wander.radius - wander.minimalLength)
        local point, navigable = groundedPoint(
            anchor.x + math.cos(angle) * distance,
            anchor.y + math.sin(angle) * distance,
            anchor.z)

        if point and #(point - from) >= wander.minimalLength then
            -- Com rota o jogo contorna sozinho; em linha reta o caminho precisa estar limpo.
            if navigable or hasClearPath(entity, from, point) then
                return point, navigable
            end
        end
    end
    return nil, false
end

---Blindagem contra fuga, reaplicada a cada troca de estado. Trocar de dono de rede, de tarefa
---ou de modelo devolve o ped ao padrão do jogo, e o padrão do jogo é correr.
---O atributo 17 é "sempre fugir" e fica desligado. Os atributos 5 e 46, "sempre lutar" e "encara
---ped armado mesmo desarmado", não estão aqui para deixar o corredor agressivo: desarmado e sem
---eles, a resposta padrão dele a uma arma apontada é a corrida. Com eles, o susto vira qualquer
---outra coisa.
---@param ped integer
local function denyFlee(ped)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, false)
    SetPedCombatAttributes(ped, 5, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedAlertness(ped, 0)
end

---Para o corredor no lugar e fecha a porta dos eventos.
---`SetBlockingOfNonTemporaryEvents` é o único freio de fuga que não depende de atributo de
---combate, mas ligado durante a caminhada ele cancela a tarefa de destino junto e o corredor não
---sai do lugar, o que está testado e anotado no README. Parado não há destino a cancelar, então
---ele entra exatamente aqui. E é aqui que importa: abordagem exige 12 metros, a parada por
---jogador perto começa em 18, então quem aponta uma arma sempre encontra o corredor já parado.
---@param entity integer
---@param scenario string? cenário de ócio, ou nil para só ficar de pé
local function holdGround(entity, scenario)
    ClearPedTasks(entity)
    denyFlee(entity)
    -- Bloqueio antes do cenário, como nos outros resources deste servidor.
    SetBlockingOfNonTemporaryEvents(entity, true)
    if scenario then
        TaskStartScenarioInPlace(entity, scenario, 0, true)
    end
end

---Solta o bloqueio para o corredor poder andar de novo. Precisa vir antes da tarefa de destino.
---@param entity integer
local function releaseHold(entity)
    SetBlockingOfNonTemporaryEvents(entity, shared.dealerWander.blockEvents == true)
    denyFlee(entity)
end

---@param entity integer
---@return boolean wandering
local function startWander(entity)
    local netId = NetworkGetEntityIsNetworked(entity)
        and NetworkGetNetworkIdFromEntity(entity) or 0

    local wander = shared.dealerWander
    if type(wander) ~= 'table' or wander.enabled ~= true then
        wanderReport[netId] = 'desligada no config'
        walks[netId] = nil
        return false
    end

    if not ownsEntity(entity) then
        wanderReport[netId] = 'não sou dono de rede'
        return false
    end

    local anchor = wanderAnchor(entity)
    if not anchor then
        wanderReport[netId] = 'sem âncora'
        return false
    end

    -- Encaixa a esquina no chão. Onde há malha de navegação usa ela; onde não há, o chão bruto.
    local grounded = groundedPoint(anchor.x, anchor.y, anchor.z)
    if grounded then anchor = grounded end

    -- Andando, o bloqueio de eventos fica no que o config mandar, que é false: ligado ele cancela
    -- a tarefa de destino junto com a reação ao susto. Quem segura a fuga enquanto ele anda é
    -- `denyFlee`; parado, é `holdGround`.
    releaseHold(entity)
    -- Sem marcar como entidade de missão, o gerenciador de população pode descartar a tarefa.
    SetEntityAsMissionEntity(entity, true, true)
    ClearPedTasks(entity)

    walks[netId] = { anchor = anchor, target = nil, taskedAt = 0, nextAt = 0 }
    wanderReport[netId] = 'ativa'
    return true
end

---Há jogador perto o suficiente para o corredor parar de circular.
---@param position vector3
---@return boolean
local function playerNearby(position)
    local limit = shared.dealerWander.pauseNearPlayers
    if type(limit) ~= 'number' or limit <= 0 then return false end
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= 0 and DoesEntityExist(ped) and #(GetEntityCoords(ped) - position) <= limit then
            return true
        end
    end
    return false
end

---Sorteia um cenário de ócio, ou nil quando o corredor não para desta vez.
---Quem toca o cenário é `holdGround`: parar e bloquear evento são a mesma decisão, e separar as
---duas deixava o ped com cenário tocando e a fuga liberada.
---@return string?
local function pickIdleScenario()
    local idle = shared.dealerWander.idle
    if type(idle) ~= 'table' or #idle.scenarios == 0 then return nil end
    if math.random(100) > idle.chance then return nil end
    return idle.scenarios[math.random(#idle.scenarios)]
end

---Avança um passo da caminhada. Chamado pelo loop de manutenção, um ped por vez.
---@param netId integer
---@param entity integer
local function advanceWalk(netId, entity)
    local walk = walks[netId]
    if not walk then return end

    local now = GetGameTimer()
    local position = GetEntityCoords(entity)

    -- Coleira. Nenhuma blindagem cobre tudo: um empurrão, um carro ou um susto que escapou ainda
    -- podem tirar o corredor da esquina. Fora do limite ele volta andando, em vez de ficar onde
    -- parou. Tem precedência sobre a parada por jogador perto, porque parar longe do posto é
    -- justamente o que não pode durar: lá ele não é abordável, não é assaltável e não é dele.
    -- Config antigo sem coleira não pode quebrar o laço a cada tique: cai no raio com folga.
    local leash = shared.dealerWander.leashDistance or (shared.dealerWander.radius * 1.5)
    local strayed = #(position - walk.anchor) > leash

    -- Com gente por perto ele fica no posto. Isso mantém a posição estável para o servidor
    -- validar assalto e abordagem, além de ficar melhor do que ele passar andando por você.
    if playerNearby(position) and not strayed then
        if walk.target then
            walk.target = nil
            walk.returning = nil
            walk.stalled = 0
        end
        if not walk.holding then
            walk.holding = true
            local scenario = pickIdleScenario() or shared.dealerWander.idle.scenarios[1]
            holdGround(entity, scenario)
            wanderReport[netId] = scenario
                and ('parado com jogador perto: %s')
                    :format(scenario:lower():gsub('world_human_', ''))
                or 'parado com jogador perto'
        end
        walk.nextAt = now + 1000
        return
    end
    walk.holding = nil

    if walk.target then
        local arrived = #(position - walk.target) <= 1.5

        -- Encostou em algo que o teste não pegou: parado dois tiques seguidos com destino
        -- pendente. Abandonar cedo é melhor do que esperar o teto e ficar de cara na parede.
        local moved = walk.lastPosition and #(position - walk.lastPosition) or 999.0
        walk.lastPosition = position
        walk.stalled = moved < 0.15 and (walk.stalled or 0) + 1 or 0
        local blocked = walk.stalled >= 2 and now - walk.taskedAt > 1500

        local expired = now - walk.taskedAt > 20000
        if arrived or blocked or expired then
            local returning = walk.returning
            walk.target = nil
            walk.returning = nil
            walk.stalled = 0

            local pause = math.floor(shared.dealerWander.timeBetweenWalks * 1000)
            local scenario = arrived and pickIdleScenario() or nil
            -- Parado é parado, com cenário sorteado ou sem: a pausa entre trechos também precisa
            -- do bloqueio, senão ela vira a janela em que o corredor ainda foge.
            holdGround(entity, scenario)
            if scenario then
                local duration = shared.dealerWander.idle.durationSeconds
                pause = math.random(duration.min, duration.max) * 1000
                wanderReport[netId] = ('parado: %s'):format(scenario:lower():gsub('world_human_', ''))
            else
                wanderReport[netId] = arrived and (returning and 'voltou para a esquina' or 'chegou, aguardando')
                    or blocked and 'caminho bloqueado, trocando'
                    or 'trecho expirou'
            end

            walk.nextAt = now + pause
        end
        return
    end

    if now < walk.nextAt then return end

    local destination, navigable
    if strayed then
        -- Longe demais: o destino não é sorteado, é a esquina. Sem ponto navegável ali ele volta
        -- em linha reta, que é o mesmo tratamento dos pátios sem malha de navegação.
        local point, nav = groundedPoint(walk.anchor.x, walk.anchor.y, walk.anchor.z)
        destination, navigable = point or walk.anchor, nav
    else
        destination, navigable = pickDestination(entity, walk.anchor, position)
    end
    if not destination then
        walk.nextAt = now + 5000
        wanderReport[netId] = 'sem destino livre no raio'
        return
    end

    -- Encerra o cenário da pausa e libera o evento antes de voltar a andar.
    releaseHold(entity)
    ClearPedTasks(entity)
    walk.target = destination
    walk.returning = strayed or nil
    walk.taskedAt = now
    walk.lastPosition = nil
    walk.stalled = 0
    if navigable then
        TaskGoToCoordAnyMeans(entity, destination.x, destination.y, destination.z, 1.0, 0, false, 786603, 0.0)
    else
        -- Sem malha não há rota a calcular: o corredor vai em linha reta, que é o suficiente
        -- num pátio aberto e evita ele ficar imóvel esperando um caminho que não existe.
        TaskGoStraightToCoord(entity, destination.x, destination.y, destination.z, 1.0, 20000, 0.0, 0.0)
    end
    wanderReport[netId] = ('%s para %.1f, %.1f (%s)'):format(
        strayed and 'voltando' or 'andando',
        destination.x, destination.y, navigable and 'rota' or 'linha reta')
end

---O ped é criado pelo servidor, que não consegue configurar comportamento de IA.
---Cada client ajusta o seu: o corredor não foge do posto, anda pela esquina e morre normalmente.
---@param entity integer
local function settleDealer(entity)
    denyFlee(entity)
    SetPedCanRagdollFromPlayerImpact(entity, false)
    SetPedDropsWeaponsWhenDead(entity, false)

    if startWander(entity) then return end
    -- Sem caminhada não há tarefa de destino para o bloqueio cancelar, então ele entra cheio,
    -- e o corredor fica de pé no cenário de esquina.
    holdGround(entity, clientConfig.dealerScenario)
end

---@param netId integer
-- Declarado antes porque `attach` precisa soltar o registro velho quando um ped novo
-- herda o mesmo net ID.
local detach

---@param dealerId integer
---@param entity integer
local function attach(netId, dealerId, entity)
    -- O FiveM recicla net ID: um ped recriado pode herdar o número do anterior. Comparar a
    -- entidade evita ficar preso ao registro velho, que deixaria o novo sem target nem IA.
    if tracked[netId] then
        if trackedEntity[netId] == entity then return end
        detach(netId)
    end
    settleDealer(entity)

    local options = {
        {
            name = 'dealer:inspect',
            icon = clientConfig.target.icons.inspect,
            label = locale('target.inspect_dealer'),
            distance = shared.interaction.dealerDistance,
            canInteract = function()
                -- Corpo caído não conversa.
                return NoirOutposts.Interaction.isDealerResponsive(netId)
            end,
            onSelect = function()
                NoirOutposts.Interaction.inspectDealer(dealerId, netId)
            end,
        },
        {
            name = 'dealer:rob',
            icon = clientConfig.target.icons.robbery,
            label = locale('target.rob_dealer'),
            distance = shared.interaction.dealerDistance,
            canInteract = function()
                return NoirOutposts.Interaction.canRobDealer(netId)
            end,
            onSelect = function()
                NoirOutposts.Interaction.robDealer(dealerId, netId)
            end,
        },
    }

    local ok, err = exports.bgrz_core:AddEntityTarget(netId, options)
    if not ok then
        if clientConfig.debug then
            lib.print.debug(('[noir_outposts] target do dealer %s falhou: %s'):format(dealerId, tostring(err)))
        end
        return
    end
    tracked[netId] = dealerId
    trackedEntity[netId] = entity
end

---Esquece tudo que este client guarda sobre um ped: caminhada, fixação, propriedade de rede e
---reação. O FiveM recicla net ID, então o corredor recriado costuma herdar o número do anterior,
---e qualquer resto aqui vale por uma instrução que nunca mais será dada. Um `wanderOwned`
---esquecido, por exemplo, deixa o ped novo parado para sempre: a caminhada dele consta como já
---iniciada, e ninguém a inicia de novo.
---@param netId integer
local function forgetPed(netId)
    walks[netId] = nil
    pinned[netId] = nil
    wanderOwned[netId] = nil
    reactions[netId] = nil
    reactionApplied[netId] = nil
end

---@param netId integer
function detach(netId)
    if not tracked[netId] then return end
    exports.bgrz_core:RemoveEntityTarget(netId, optionNames())
    tracked[netId] = nil
    trackedEntity[netId] = nil
    forgetPed(netId)
    -- Guardado porque `Entities.clear` também roda no stop do resource, e a ordem de carga entre
    -- os arquivos do client não é contrato.
    if NoirOutposts.Interaction then NoirOutposts.Interaction.forgetDealer(netId) end
end

---Há algum corredor transmitido para este client. Evita manter o loop de mira aceso à toa.
---@return boolean
function Entities.hasTracked()
    return next(tracked) ~= nil
end

---Peds de corredor com target registrado neste client, para diagnóstico.
---@return table<integer, integer> netId -> dealerId
function Entities.tracked()
    local copy = {}
    for netId, dealerId in pairs(tracked) do copy[netId] = dealerId end
    return copy
end

---@param netId integer
---@return integer? dealerId
function Entities.dealerOf(netId)
    return tracked[netId]
end

---@param entity number
---@return string? outpostId, integer? dealerId, string? status
function Entities.readState(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local state = Entity(entity).state
    return state[C.StateBag.OUTPOST], state[C.StateBag.DEALER], state[C.StateBag.DEALER_STATE]
end

-- Atendente do terminal -----------------------------------------------------------------

---@param outpostId string
local function removeTerminal(outpostId)
    terminalWarned[outpostId] = nil
    local terminal = terminals[outpostId]
    if not terminal then return end
    terminals[outpostId] = nil
    if DoesEntityExist(terminal.ped) then
        exports.bgrz_core:RemoveEntityTarget(terminal.ped, { 'terminal:open' })
        SetEntityAsMissionEntity(terminal.ped, true, true)
        DeleteEntity(terminal.ped)
    end
end

---Chama um nativo opcional. Um nome que não existe nesta build chega aqui como `nil`, e
---chamar `nil` derruba o resource inteiro no client. Já derrubou: `SetPedDiesFromLowHealth`
---não existe e eu o escrevi de cabeça. Endurecer o atendente é acumular garantias, então uma
---garantia indisponível deve ser ignorada, nunca custar as outras.
---@param native any
---@return boolean called
local function optional(native, ...)
    if type(native) ~= 'function' then return false end
    return (pcall(native, ...))
end

---Deixa o atendente imune e imóvel. Ele é mobília com voz: não morre, não cambaleia, não
---reage a tiro, explosão ou carro, e não sai do lugar por nada.
---@param ped integer
local function hardenTerminal(ped)
    -- Estes já são usados por outros resources do servidor, então existem.
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    SetPedSuffersCriticalHits(ped, false)
    SetPedCanBeTargetted(ped, false)

    -- Estes reforçam, mas não são essenciais. Se a build não tiver algum, o atendente continua
    -- imune e parado pelos de cima.
    optional(SetPedDiesWhenInjured, ped, false)
    optional(SetPedDiesInWater, ped, false)
    optional(SetPedCanRagdollFromPlayerImpact, ped, false)
    optional(SetEntityProofs, ped, true, true, true, true, true, true, true, true)

    -- O congelamento é o que de fato prende a posição.
    FreezeEntityPosition(ped, true)

    if shared.terminalNpc.scenario then
        TaskStartScenarioInPlace(ped, shared.terminalNpc.scenario, 0, true)
    end
end

---Cria o atendente local do terminal. Ped não networked: é só âncora de interação,
---nenhuma autoridade passa por ele.
---@param outpostId string
---@return boolean created
local function createTerminal(outpostId)
    if terminals[outpostId] then return true end

    local definition = shared.outposts[outpostId]
    local coords = definition.computer
    local model = joaat(shared.terminalNpc.model)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        warnOnce(outpostId, ('modelo de atendente inválido: %s'):format(shared.terminalNpc.model))
        return false
    end
    if not lib.requestModel(model, 5000) then
        warnOnce(outpostId, ('timeout carregando o atendente de %s'):format(outpostId))
        return false
    end

    -- `computer` é usada como está, sem procurar chão e sem corrigir altura. O ped fica
    -- congelado exatamente aí, então a coordenada cadastrada é a posição final.
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    hardenTerminal(ped)

    local ok, err = exports.bgrz_core:AddEntityTarget(ped, {
        {
            name = 'terminal:open',
            icon = clientConfig.target.icons.operator,
            label = locale('target.talk_operator'),
            distance = shared.interaction.computerDistance,
            onSelect = function() NoirOutposts.Interaction.openComputer(outpostId) end,
        },
    })
    if not ok then
        warnOnce(outpostId, ('target do atendente de %s falhou: %s'):format(outpostId, tostring(err)))
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
        return false
    end

    terminalWarned[outpostId] = nil
    terminals[outpostId] = { ped = ped }
    return true
end

---Declara em quais locais deve haver atendente. A criação em si fica no laço abaixo.
---@param activeIds table<string, boolean>
function Entities.syncTerminals(activeIds)
    wantedTerminals = activeIds
end

-- O atendente é a única porta de entrada do terminal, então uma falha não pode deixar o local
-- inacessível até o próximo snapshot. Streaming de modelo falha, e o engine remove o ped em
-- algumas situações; as duas coisas se resolvem tentando de novo.
CreateThread(function()
    while true do
        local stale = {}
        for outpostId, terminal in pairs(terminals) do
            if not wantedTerminals[outpostId] or not DoesEntityExist(terminal.ped) then
                stale[#stale + 1] = outpostId
            end
        end
        for index = 1, #stale do
            if wantedTerminals[stale[index]] then
                -- Ped sumiu mas o local continua ativo: solta o registro para recriar abaixo.
                terminals[stale[index]] = nil
            else
                removeTerminal(stale[index])
            end
        end

        for outpostId in pairs(wantedTerminals) do
            if createTerminal(outpostId) then
                local terminal = terminals[outpostId]
                -- Reafirma a cada volta. Uma explosão perto, ou outro resource mexendo em peds
                -- por perto, pode soltar a animação ou o congelamento sem apagar o ped.
                if not shared.terminalNpc.scenario then
                    -- Sem cenário não há estado observável para comparar, e reafirmar as flags
                    -- é barato. Sai mais em conta que deixar o ped solto entre as voltas.
                    hardenTerminal(terminal.ped)
                elseif type(IsPedUsingScenario) == 'function'
                    and not IsPedUsingScenario(terminal.ped, shared.terminalNpc.scenario) then
                    -- `IsPedUsingScenario` não é usado por nenhum outro resource daqui, então
                    -- não confio que exista. Sem ele, o congelamento sozinho segura o ped.
                    hardenTerminal(terminal.ped)
                end
            end
        end

        Wait(shared.terminalNpc.checkIntervalMs)
    end
end)

function Entities.clearTerminals()
    wantedTerminals = {}
    local ids = {}
    for outpostId in pairs(terminals) do ids[#ids + 1] = outpostId end
    for index = 1, #ids do removeTerminal(ids[index]) end
end

function Entities.clear()
    local netIds = {}
    for netId in pairs(tracked) do netIds[#netIds + 1] = netId end
    for index = 1, #netIds do detach(netIds[index]) end
    trackedEntity = {}
    Entities.clearTerminals()
end

---@param state string?
---@return boolean
local function isHoldupState(state)
    return state == C.HoldupState.SURRENDERED
        or state == C.HoldupState.HOSTILE
        or state == C.HoldupState.SHAKEN
end

---@param netId integer
---@param bagState string?
---@return table? reaction
local function holdupReaction(netId, bagState)
    local fresh = reactions[netId]
    if fresh and (GetGameTimer() - fresh.at) < clientConfig.holdup.reactionGraceMs then
        return isHoldupState(fresh.state) and fresh or nil
    end

    -- Passada a janela o bag decide: é ele que sobrevive à troca de dono de rede e a quem
    -- entrou no servidor depois de a abordagem já ter começado.
    if isHoldupState(bagState) then
        if fresh and fresh.state == bagState then return fresh end
        return { state = bagState, at = GetGameTimer() }
    end

    reactions[netId] = nil
    return nil
end

---Fixa o corredor que não está caminhando: blindagem, bloqueio de evento e cenário de esquina.
---Uma vez por estado, para não retarefar a cada tique, e nunca sobre um corpo caído.
---@param netId integer
---@param entity integer
---@param state string estado que motivou a fixação
local function pin(netId, entity, state)
    if pinned[netId] == state then return end
    if IsPedDeadOrDying(entity, true) then
        -- Corpo caído não recebe tarefa. A remoção é do servidor, na recuperação.
        pinned[netId] = state
        return
    end
    pinned[netId] = state
    -- Em serviço e sem caminhada ele só fica de pé na esquina. Fora de serviço, que é o corredor
    -- em recuperação de assalto ou de morte, ele fica agachado com medo: é o que diz ao jogador,
    -- sem nenhum texto, que ali não há o que tirar agora.
    local scenario = state == C.DealerStatus.DEPLOYED
        and clientConfig.dealerScenario
        or clientConfig.cowerScenario
    holdGround(entity, scenario)
    wanderReport[netId] = ('parado, fora da caminhada (%s)'):format(state)
end

-- State bags são apenas identificação: nunca autorizam a ação.
-- Último envio de posições ao servidor. O servidor não enxerga um ped conduzido por IA aqui,
-- então quem é dono de rede precisa contar. Sem isso a validação de distância mede contra a
-- coordenada de spawn e recusa quem está encostado no corredor.
local lastPositionReport = 0

CreateThread(function()
    while true do
        local sleep = 2000
        if next(tracked) ~= nil then
            sleep = 500
            -- Sobre uma cópia das chaves: aplicar uma reação cede um frame, e nesse intervalo
            -- um ped novo pode entrar em `tracked`, o que quebraria a travessia em andamento.
            local netIds = {}
            for netId in pairs(tracked) do netIds[#netIds + 1] = netId end

            local now = GetGameTimer()
            local reportDue = (now - lastPositionReport) >= shared.dealerWander.reportIntervalMs
            local report = reportDue and {} or nil
            if reportDue then lastPositionReport = now end

            for index = 1, #netIds do
                local netId = netIds[index]
                -- Reconfere `tracked`: o ped pode ter sido solto enquanto a volta cedia o frame.
                local entity = tracked[netId] and NetworkDoesNetworkIdExist(netId)
                    and NetworkGetEntityFromNetworkId(netId) or 0
                if entity == 0 or not DoesEntityExist(entity) then
                    wanderOwned[netId] = nil
                    walks[netId] = nil
                    pinned[netId] = nil
                elseif not ownsEntity(entity) then
                    -- Perdeu a propriedade: quem assumir reaplica.
                    wanderOwned[netId] = nil
                    walks[netId] = nil
                    pinned[netId] = nil
                    reactionApplied[netId] = nil
                else
                    local bagState = Entity(entity).state[C.StateBag.DEALER_STATE]
                    local reaction = holdupReaction(netId, bagState)
                    if reaction then
                        -- Sob abordagem a IA é a da encenação. Caminhar por cima dela cancelaria
                        -- a rendição ou tiraria o corredor armado do combate.
                        wanderOwned[netId] = nil
                        walks[netId] = nil
                        pinned[netId] = nil
                        if reactionApplied[netId] ~= reaction.state then
                            applyReaction(entity, reaction)
                            reactionApplied[netId] = reaction.state
                        end
                    elseif bagState ~= C.DealerStatus.DEPLOYED then
                        -- Fora de serviço — em recuperação de assalto ou de morte — ele some da
                        -- lógica de venda, mas continua na rua e continua sendo um ped. Aqui
                        -- antes só se largava a caminhada, e ped largado volta à IA do jogo: era
                        -- ele que fugia da arma apontada durante os dez minutos de recuperação.
                        wanderOwned[netId] = nil
                        walks[netId] = nil
                        pin(netId, entity, bagState or 'sem estado')
                    else
                        reactionApplied[netId] = nil
                        if not wanderOwned[netId] then
                            if startWander(entity) then
                                wanderOwned[netId] = true
                                pinned[netId] = nil
                            else
                                -- Em serviço e sem caminhada: config desligado, esquina que ainda
                                -- não chegou pelo state bag. Solto ele fugiria do mesmo jeito.
                                pin(netId, entity, C.DealerStatus.DEPLOYED)
                            end
                        end
                        advanceWalk(netId, entity)
                    end

                    -- Reporta em qualquer estado, inclusive rendido ou hostil: é justamente
                    -- nesses que a posição precisa estar certa para a revista funcionar.
                    if reportDue then
                        local position = GetEntityCoords(entity)
                        report[#report + 1] = {
                            netId = netId,
                            x = position.x,
                            y = position.y,
                            z = position.z,
                            -- Só a hora de olhar. O servidor confirma com a leitura dele, que é
                            -- confiável enquanto este client for o dono — e no instante da morte
                            -- ele é, porque quem matou está aqui. A varredura sozinha chegava até
                            -- dez segundos depois, quando o corpo já podia estar sem dono.
                            dead = IsPedDeadOrDying(entity, true) or nil,
                        }
                    end
                end
            end

            if report and #report > 0 then
                TriggerServerEvent(C.Events.DEALER_POSITION, report)
            end
        end
        Wait(sleep)
    end
end)

-- A esquina pode chegar depois do gatilho, e muda na rotação de posições.
-- Nos dois casos a caminhada precisa ser refeita a partir da âncora nova.
AddStateBagChangeHandler(C.StateBag.DEALER_CORNER, nil, function(bagName, _, value)
    if type(value) ~= 'number' then return end
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if not NetworkGetEntityIsNetworked(entity) then return end
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not tracked[netId] then return end
    wanderOwned[netId] = nil
    walks[netId] = nil
    pinned[netId] = nil
    -- A rotação de esquinas pode cair no meio de uma abordagem. Reassentar aqui cancelaria a
    -- rendição; o laço de manutenção refaz a caminhada quando a abordagem terminar.
    if holdupReaction(netId, Entity(entity).state[C.StateBag.DEALER_STATE]) then return end
    settleDealer(entity)
end)

AddStateBagChangeHandler(C.StateBag.DEALER, nil, function(bagName, _, value)
    -- O net ID vem do nome do bag, não da entidade. Quando o servidor apaga o ped ele limpa
    -- o bag e deleta em seguida, então esperar pela entidade aqui perderia toda remoção,
    -- e o registro velho bloquearia o ped seguinte que herdasse o mesmo net ID.
    local netId = tonumber(bagName:match('^entity:(%d+)$'))
    if not netId then return end

    if type(value) ~= 'number' then
        detach(netId)
        return
    end

    CreateThread(function()
        -- Na criação vale o contrário: o bag pode chegar antes de a entidade existir aqui.
        local entity, attempts = 0, 0
        repeat
            entity = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
            if entity ~= 0 and DoesEntityExist(entity) then break end
            attempts = attempts + 1
            Wait(100)
        until attempts >= 20
        if entity == 0 or not DoesEntityExist(entity) then return end

        attach(netId, value, entity)
    end)
end)

-- Reação à abordagem. O servidor decide o resultado; aqui só encenamos.
-- Vale para todos os clients: quem for dono de rede do ped é quem de fato conduz a IA.
function applyReaction(entity, payload)
    if payload.state == C.HoldupState.HOSTILE then
        -- Imediato de propósito. `ClearPedTasks` num cenário de ócio não corta nada: o ped toca
        -- a animação de saída inteira antes de obedecer, e reagir a uma arma apontada chegava
        -- segundos depois, quando a mira já tinha acabado.
        ClearPedTasksImmediately(entity)
        if payload.weapon then
            GiveWeaponToPed(entity, joaat(payload.weapon), 250, false, true)
        end
        denyFlee(entity)
        SetPedCombatAbility(entity, 2)
        SetPedSeeingRange(entity, 60.0)

        local target = payload.targetServerId and GetPlayerFromServerId(payload.targetServerId) or -1
        local targetPed = target ~= -1 and GetPlayerPed(target) or 0
        if targetPed ~= 0 and DoesEntityExist(targetPed) then
            TaskCombatPed(entity, targetPed, 0, 16)
        else
            -- O alvo pode não existir neste client. Aqui era `TaskReactAndFleePed`, que mandava
            -- o corredor correr — e correr do jogador local, que quase nunca é quem apontou a
            -- arma. Sem alvo ele fica firme, armado, até o servidor encerrar a hostilidade.
            TaskStandStill(entity, 60000)
        end
        -- Depois da tarefa de combate, e ligado: é ela que ele deve seguir. Sem isto, levar tiro
        -- durante a briga gera o evento que larga o combate e vira fuga.
        SetBlockingOfNonTemporaryEvents(entity, true)
        return
    end

    if payload.state == C.HoldupState.SURRENDERED then
        local anim = clientConfig.holdup.surrenderAnim
        -- O dicionário é pedido antes de cortar as tarefas: se o streaming demorasse com o ped
        -- já zerado, ele ficaria parado sem pose nenhuma no meio da rendição.
        local loaded = lib.requestAnimDict(anim.dict, 3000)

        ClearPedTasksImmediately(entity)
        denyFlee(entity)
        SetBlockingOfNonTemporaryEvents(entity, true)
        RemoveAllPedWeapons(entity, true)

        if loaded then
            -- Um frame para a limpeza imediata assentar antes de dar a tarefa nova.
            Wait(0)
            if not DoesEntityExist(entity) then return end
            -- Corpo inteiro em loop. A flag 49 é de animação secundária de tronco: as pernas
            -- ficam livres, e o corredor continuava andando de mãos para o alto.
            TaskPlayAnim(entity, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
            RemoveAnimDict(anim.dict)
        end
        return
    end

    if payload.state == C.HoldupState.SHAKEN then
        -- Abordagem encerrada, cooldown correndo. Ele não volta a caminhar como se nada tivesse
        -- acontecido: fica agachado com medo até o servidor devolver o estado normal.
        -- Imediato pelo mesmo motivo da rendição: um cenário de ócio só obedece depois de tocar
        -- a animação de saída inteira, e aqui ele vem direto de uma arma na cara.
        ClearPedTasksImmediately(entity)
        denyFlee(entity)
        RemoveAllPedWeapons(entity, true)
        SetBlockingOfNonTemporaryEvents(entity, true)
        TaskStartScenarioInPlace(entity, clientConfig.cowerScenario, 0, true)
        return
    end

    -- Voltou ao normal.
    ClearPedTasks(entity)
    RemoveAllPedWeapons(entity, true)
    settleDealer(entity)
end

---@param netId integer
local function forgetWander(netId)
    wanderOwned[netId] = nil
    walks[netId] = nil
    pinned[netId] = nil
end

RegisterNetEvent(C.Events.DEALER_REACTION, function(payload)
    if source ~= 65535 then return end
    if type(payload) ~= 'table' or type(payload.netId) ~= 'number' then return end
    if not NetworkDoesNetworkIdExist(payload.netId) then return end
    local entity = NetworkGetEntityFromNetworkId(payload.netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    reactions[payload.netId] = {
        state = payload.state,
        weapon = payload.weapon,
        targetServerId = payload.targetServerId,
        at = GetGameTimer(),
    }
    reactionApplied[payload.netId] = nil
    forgetWander(payload.netId)

    -- Só o dono de rede conduz a IA. Nos outros clients o laço reaplica se a propriedade migrar.
    if not ownsEntity(entity) then return end
    applyReaction(entity, payload)
    reactionApplied[payload.netId] = payload.state
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Entities.clear()
end)
