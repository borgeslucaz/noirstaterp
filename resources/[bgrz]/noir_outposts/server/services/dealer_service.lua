-- Contratação e demissão de dealers. Pagamento, limite e corner resolvidos no servidor.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Dealer = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Entities = NoirOutposts.Entities
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Notification = NoirOutposts.Services.Notification
local Rotation = NoirOutposts.Services.Rotation

---@param actor OutpostActor
---@param outpostId string
---@param action string
---@return table? entry, string? code
local function ownedEntry(actor, outpostId, action)
    local entry = State.get(outpostId)
    if not entry then return nil, 'unknown_outpost' end
    if entry.row.status ~= C.OutpostStatus.CONTROLLED then return nil, 'invalid_state' end
    if not Security.isOwner(actor, entry.row) then return nil, 'not_owner' end
    local allowed, permissionError = Security.requirePermission(actor, action)
    if not allowed then return nil, permissionError end
    local definition = shared.outposts[outpostId]
    if not Security.isNear(actor.source, definition.computer, shared.interaction.computerDistance) then
        return nil, 'too_far'
    end
    return entry
end

Service.ownedEntry = ownedEntry

---@param actor OutpostActor
---@param price integer
---@param reason string
---@return boolean ok, string? code
local function charge(actor, price, reason)
    if price <= 0 then return true end
    local payment = config.hire.payment
    if payment.type == 'item' then
        local ok = Integration.removeItem(actor.source, payment.item, price)
        if not ok then return false, 'insufficient_funds' end
        return true
    end
    local ok = Integration.removeMoney(actor.source, payment.account, price, reason)
    if not ok then return false, 'insufficient_funds' end
    return true
end

---@param actor OutpostActor
---@param price integer
---@param reason string
local function refund(actor, price, reason)
    if price <= 0 then return end
    local payment = config.hire.payment
    if payment.type == 'item' then
        Integration.addItem(actor.source, payment.item, price)
        return
    end
    Integration.addMoney(actor.source, payment.account, price, reason)
end

---Sorteia nome e ped para dados antigos que ainda não possuem elenco da tomada.
---Evita repetir o que já está na rua neste posto: dois corredores com o mesmo rosto e o mesmo
---nome na mesma esquina entregam de graça que são script.
---@param entry table
---@return string? name, string? model
local function drawIdentity(entry)
    local identities = shared.dealerIdentities
    if type(identities) ~= 'table' then return nil, nil end

    local takenNames, takenModels = {}, {}
    for _, dealer in pairs(entry.dealers) do
        if dealer.display_name then takenNames[dealer.display_name] = true end
        if dealer.ped_model then takenModels[dealer.ped_model] = true end
    end

    local names = V.freeIdentityPool(identities.names, takenNames)
    local models = V.freeIdentityPool(identities.models, takenModels)
    if #names == 0 or #models == 0 then return nil, nil end

    return names[math.random(#names)], models[math.random(#models)]
end

---@param actor OutpostActor
---@param outpostId string
---@param profileKey string
---@param requestId string
---@return table result
function Service.hire(actor, outpostId, profileKey, requestId)
    local entry, code = ownedEntry(actor, outpostId, 'hire')
    if not entry then return { ok = false, code = code } end

    local profile = Security.profile(profileKey)
    if not profile then return { ok = false, code = 'unknown_profile' } end

    -- Idempotência em duas camadas: ledger (sobrevive a restart) e memória (duplo clique).
    if Repositories.Operation.findByRequest(actor.citizenId, requestId) then
        return { ok = false, code = 'already_processed' }
    end
    if Security.claimRequestId(actor.citizenId, requestId) == 'duplicate' then
        return { ok = false, code = 'already_processed' }
    end

    if State.dealerCount(outpostId) >= config.limits.maxDealersPerOutpost then
        return { ok = false, code = 'dealer_limit' }
    end
    for _, dealer in pairs(entry.dealers) do
        if dealer.profile_key == profileKey then return { ok = false, code = 'already_hired' } end
    end

    local corners = State.freeCorners(outpostId)
    if #corners == 0 then return { ok = false, code = 'no_corner' } end
    local cornerIndex = corners[math.random(#corners)]

    local reserved = type(entry.row.dealer_roster) == 'table' and entry.row.dealer_roster[profileKey] or nil
    local displayName = type(reserved) == 'table' and reserved.name or nil
    local pedModel = type(reserved) == 'table' and reserved.model or nil
    if type(displayName) ~= 'string' or displayName == '' or type(pedModel) ~= 'string' or pedModel == '' then
        displayName, pedModel = drawIdentity(entry)
    end
    if not displayName or not pedModel then return { ok = false, code = 'internal_error' } end

    local price = config.dealerHirePrice[profileKey] or 0
    local paid, chargeError = charge(actor, price, 'noir_outposts:hire:fee')
    if not paid then return { ok = false, code = chargeError } end

    local now = os.time()
    local dealerId = Repositories.Dealer.insert({
        outpostId = outpostId,
        profileKey = profileKey,
        displayName = displayName,
        pedModel = pedModel,
        cornerIndex = cornerIndex,
        hiredBy = actor.citizenId,
        hiredAt = now,
        nextSaleAt = now + State.intervalFor(profileKey),
    }, config.limits.maxDealersPerOutpost)

    if not dealerId then
        refund(actor, price, 'noir_outposts:hire:refund')
        State.reload(outpostId)
        return { ok = false, code = 'dealer_limit' }
    end

    Repositories.Operation.insert({
        id = Rotation.uuid(),
        type = C.OperationKind.HIRE,
        outpostId = outpostId,
        dealerId = dealerId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        gross = price,
        status = C.OperationStatus.COMMITTED,
        requestId = requestId,
        createdAt = now,
        committedAt = now,
        payload = {
            profileKey = profileKey,
            cornerIndex = cornerIndex,
            dealerName = displayName,
            pedModel = pedModel,
        },
    })

    State.reload(outpostId)
    local dealer = State.dealer(dealerId)
    if dealer then Entities.spawnDealer(outpostId, dealer) end

    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(outpostId)
    Log.info('dealer_hired', {
        outpostId = outpostId,
        dealerId = dealerId,
        profileKey = profileKey,
        citizenId = actor.citizenId,
        price = price,
    })

    return { ok = true, data = { dealerId = dealerId } }
end

---@param actor OutpostActor
---@param outpostId string
---@param dealerId integer
---@param requestId string
---@return table result
function Service.fire(actor, outpostId, dealerId, requestId)
    local entry, code = ownedEntry(actor, outpostId, 'fire')
    if not entry then return { ok = false, code = code } end

    local dealer = entry.dealers[dealerId]
    if not dealer then return { ok = false, code = 'unknown_dealer' } end

    if Repositories.Operation.findByRequest(actor.citizenId, requestId) then
        return { ok = false, code = 'already_processed' }
    end
    if Security.claimRequestId(actor.citizenId, requestId) == 'duplicate' then
        return { ok = false, code = 'already_processed' }
    end

    local session = Sessions.activeForDealer(dealerId)
    if session then return { ok = false, code = 'dealer_busy' } end

    local affected = Repositories.Dealer.delete(dealerId)
    if not affected or affected == 0 then
        State.reload(outpostId)
        return { ok = false, code = 'unknown_dealer' }
    end

    Entities.despawnDealer(dealerId)
    Service.forgetRobbery(dealerId)

    local now = os.time()
    local refundValue = 0
    if config.hire.refundOnFire then
        refundValue = math.floor((config.dealerHirePrice[dealer.profile_key] or 0) / 2)
        refund(actor, refundValue, 'noir_outposts:fire:refund')
    end

    Repositories.Operation.insert({
        id = Rotation.uuid(),
        type = C.OperationKind.FIRE,
        outpostId = outpostId,
        dealerId = dealerId,
        citizenId = actor.citizenId,
        organizationId = actor.organization.id,
        net = refundValue,
        status = C.OperationStatus.COMMITTED,
        requestId = requestId,
        createdAt = now,
        committedAt = now,
        payload = { profileKey = dealer.profile_key, dealerName = State.dealerName(dealer) },
    })

    State.reload(outpostId)
    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(outpostId)
    Log.info('dealer_fired', { outpostId = outpostId, dealerId = dealerId, citizenId = actor.citizenId })

    return { ok = true, data = { refund = refundValue } }
end

---Momento do último assalto por corredor. Só importa dentro da janela de graça, então
---memória basta: perder isso num restart não muda nada depois de um minuto.
---@type table<integer, integer>
local robbedAt = {}

---@param dealerId integer
function Service.markRobbed(dealerId)
    robbedAt[dealerId] = os.time()
end

---@param dealerId integer
function Service.forgetRobbery(dealerId)
    robbedAt[dealerId] = nil
    Service.forgetPositionSync(dealerId)
    Service.forgetReportedPosition(dealerId)
end

---Coordenada da esquina cadastrada de um corredor. É o único ponto que o servidor conhece
---sem depender de nada do client.
---@param dealer table
---@return vector3?
function Service.cornerOf(dealer)
    local definition = shared.outposts[dealer.outpost_id]
    local corner = definition and definition.dealerCorners[dealer.corner_index or 0]
    if not corner then return nil end
    return vector3(corner.x, corner.y, corner.z)
end

---Até onde um corredor pode ter se afastado da própria esquina.
---@return number
function Service.wanderSlack()
    local wander = shared.dealerWander
    if type(wander) == 'table' and wander.enabled == true then return wander.radius end
    return 0.0
end

-- Quando é `true`, alguma leitura já saiu da esquina de spawn e portanto o servidor recebe a
-- posição dos peds. Vale para o resource inteiro: é uma propriedade da sincronização, não de um
-- corredor. Volta a `false` no restart, que é quando a hipótese precisa ser provada de novo.
-- A prova de sincronização é POR CORREDOR, não global.
-- Já foi global e estava errado: bastava um corredor provar que o servidor enxerga peds para
-- todos os outros passarem a ser medidos com o alcance apertado, inclusive um cuja leitura
-- ainda era a coordenada de spawn. Aí o assalto media 2,5 m contra um ponto a dezenas de
-- metros do ped de verdade e recusava quem estava encostado nele.
---@type table<integer, { cornerIndex: integer?, proven: boolean }>
local syncProof = {}

---@param dealerId integer
---@return boolean
function Service.positionSyncProven(dealerId)
    if dealerId == nil then
        for _, proof in pairs(syncProof) do
            if proof.proven then return true end
        end
        return false
    end
    local proof = syncProof[dealerId]
    return proof ~= nil and proof.proven
end

---@param dealerId integer
function Service.forgetPositionSync(dealerId)
    syncProof[dealerId] = nil
end

-- Posição reportada pelo dono de rede do ped, por corredor.
---@type table<integer, { coords: vector3, at: integer, cornerIndex: integer? }>
local reported = {}

---Registra onde o dono de rede diz que o corredor está.
---
---A alegação NÃO é presa à esquina cadastrada. Um corredor assustado foge e pode parar bem
---longe, e esse comportamento é desejado; prendê-lo ao raio de caminhada tornaria impossível
---assaltar justamente quem fugiu.
---
---O que limita é a continuidade. A âncora começa na esquina, que o servidor conhece de fato, e
---cada reporte só pode afastá-la o que um ped consegue percorrer no tempo decorrido. Assim a
---posição acompanha a fuga a qualquer distância, mas ninguém teleporta o corredor para o próprio
---colo: arrastar a âncora custa o mesmo tempo que andar até lá de verdade.
---@param dealerId integer
---@param coords vector3
---@return boolean accepted
function Service.reportPosition(dealerId, coords)
    local dealer = State.dealer(dealerId)
    if not dealer then return false end

    local corner = Service.cornerOf(dealer)
    if not corner then return false end

    local now = GetGameTimer()
    local anchor = reported[dealerId]

    -- Sem âncora, ou esquina trocada por rotação: o ped é outro, e a origem volta a ser o ponto
    -- que o servidor conhece sem depender de ninguém.
    if not anchor or anchor.cornerIndex ~= dealer.corner_index then
        anchor = { coords = corner, at = now, cornerIndex = dealer.corner_index, seeded = true }
        reported[dealerId] = anchor
    end

    local elapsed = math.max(now - anchor.at, 0) / 1000
    local budget = config.validation.reportedPositionMaxSpeed
        * math.min(elapsed, config.validation.reportedPositionMaxGapSeconds)
        + config.validation.reportedPositionSlack

    -- No primeiro reporte o tempo decorrido não significa nada: a âncora acabou de ser posta na
    -- esquina, e o corredor legitimamente já pode estar em qualquer ponto da área dele.
    if anchor.seeded then
        budget = math.max(budget, Service.wanderSlack() + config.validation.reportedPositionSlack)
    end

    local jump = #(coords - anchor.coords)
    if jump > budget then
        Log.warn('dealer_position_rejected', {
            dealerId = dealerId,
            jump = math.floor(jump),
            budget = math.floor(budget),
            elapsedSeconds = math.floor(elapsed),
        })
        return false
    end

    anchor.coords = coords
    anchor.at = now
    anchor.seeded = nil
    return true
end

---@param dealerId integer
function Service.forgetReportedPosition(dealerId)
    reported[dealerId] = nil
end

---@param dealerId integer
---@return vector3? coords
local function freshReport(dealerId)
    local entry = reported[dealerId]
    if not entry then return nil end
    -- A âncora continua guardada mesmo vencida: ela é a origem do próximo reporte, e descartá-la
    -- devolveria ao client um orçamento de salto do tamanho do mapa.
    if GetGameTimer() - entry.at > config.validation.reportedPositionTtlSeconds * 1000 then
        return nil
    end
    return entry.coords
end

Service.freshReport = freshReport

---Onde o servidor acredita que o corredor está, e se essa crença é fato ou palpite.
---@param dealer table
---@param entity number?
---@return vector3? coords, boolean trusted
function Service.observedPosition(dealer, entity)
    local corner = Service.cornerOf(dealer)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return corner, false
    end

    -- Esquina nova é ped novo: a prova antiga não vale para ele.
    local proof = syncProof[dealer.id]
    if not proof or proof.cornerIndex ~= dealer.corner_index then
        proof = { cornerIndex = dealer.corner_index, proven = false }
        syncProof[dealer.id] = proof
    end

    -- O reporte do dono de rede vem primeiro. É a única fonte que acompanha o ped de fato,
    -- e já chegou limitada à área do posto, então não precisa da heurística de confiança.
    local report = freshReport(dealer.id)
    if report then return report, true end

    local coords = GetEntityCoords(entity)
    -- Medida em 3D. O servidor não simula física para estes peds, então qualquer diferença em
    -- relação ao spawn, altura inclusive, só pode ter chegado pela sincronização do dono.
    local drift = corner and #(coords - corner) or nil
    if V.provesPositionSync(drift, config.validation.positionSyncEpsilon) then
        if not proof.proven then
            proof.proven = true
            Log.info('position_sync_proven', { dealerId = dealer.id, drift = drift })
        end
        return coords, true
    end

    -- Leitura em cima do spawn: só vale como posição real se ESTE corredor já se provou antes.
    return coords, proof.proven
end

---Alvo válido para uma ação de rival (abordagem ou assalto).
---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@param maxDistance number
---@param anchor table? { coords: vector3, trusted: boolean } posição gravada na rendição
---@return table? context { dealer, entry, entity, coords, trusted, reach }, string? code
function Service.rivalTarget(actor, dealerId, netId, maxDistance, anchor)
    if not Security.isActorAble(actor) then return nil, 'player_unavailable' end

    local dealer = State.dealer(dealerId)
    if not dealer then return nil, 'unknown_dealer' end
    if dealer.status ~= C.DealerStatus.DEPLOYED then return nil, 'dealer_unavailable' end

    local now = os.time()
    if dealer.robbed_until and dealer.robbed_until > now then return nil, 'dealer_cooldown' end

    local entry = State.get(dealer.outpost_id)
    if not entry then return nil, 'unknown_outpost' end
    if entry.row.status ~= C.OutpostStatus.CONTROLLED then return nil, 'invalid_state' end
    if Security.isOwner(actor, entry.row) then return nil, 'own_outpost' end

    -- Gang dona inteira offline: o corredor não é alvo de ninguém. A venda passiva já para
    -- sozinha nesse período, então sem esta trava a madrugada seria ganho de graça para o rival
    -- e perda pura para quem não tem como reagir. Vale para abordagem e assalto de uma vez, que
    -- é o motivo de a checagem morar aqui e não nos dois serviços.
    --
    -- Falha fechado de propósito: outpost sem dono na linha não tem membro online por definição,
    -- e recusar é a resposta certa para um estado que não deveria existir com status controlado.
    if config.ownerOffline.protectDealers
        and not Integration.hasOnlineMember(entry.row.owner_organization_id) then
        return nil, 'owner_offline'
    end

    local entity = Entities.validate(dealerId, netId)
    if not entity then return nil, 'invalid_entity' end
    if not Security.sameBucket(actor.source, entity) then return nil, 'invalid_entity' end

    -- `anchor` é a posição gravada no instante da rendição. A revista mede contra ela, e não
    -- contra uma leitura nova: o corredor rendido não anda, e congelar o ponto impede que
    -- alguém arraste o alvo para perto de si durante a janela.
    local coords, trusted
    if anchor and anchor.coords then
        coords, trusted = anchor.coords, anchor.trusted == true
    else
        coords, trusted = Service.observedPosition(dealer, entity)
    end
    if not coords then return nil, 'invalid_entity' end

    -- Sem posição confiável sobra a esquina cadastrada mais o raio de caminhada. É frouxo, mas
    -- continua prendendo a ação à área do posto: sem checagem nenhuma, um client modificado
    -- drenaria a carteira da organização de qualquer lugar do mapa.
    local reach = V.dealerReach(trusted, maxDistance, Service.wanderSlack())
    if not Security.isNear(actor.source, coords, reach) then return nil, 'too_far' end

    return {
        dealer = dealer,
        entry = entry,
        entity = entity,
        coords = coords,
        trusted = trusted,
        reach = reach,
    }
end

---Corredor morto sai de operação pelo cooldown configurado. Detectado pela varredura do
---scheduler, nunca por aviso do client.
---@param dealerId integer
---@return boolean applied
function Service.markDown(dealerId)
    local dealer = State.dealer(dealerId)
    if not dealer then return false end

    -- Quem acabou de ser assaltado já está em `recovering`, porque o assalto grava esse estado no
    -- mesmo UPDATE que debita a carteira. Exigir `deployed` aqui fazia a morte dele ser recusada
    -- em silêncio: ele voltava no prazo do roubo, como se ninguém o tivesse executado.
    -- O carimbo do assalto é o que autoriza essa segunda passagem, e é consumido logo abaixo —
    -- sem isso a varredura remarcaria o mesmo corpo a cada volta, empurrando o prazo para sempre.
    local afterRobbery = robbedAt[dealerId] ~= nil
    local deployed = dealer.status == C.DealerStatus.DEPLOYED
    if not deployed and not (dealer.status == C.DealerStatus.RECOVERING and afterRobbery) then
        return false
    end

    local entry = State.get(dealer.outpost_id)
    if not entry then return false end

    local now = os.time()
    -- O prazo depende de ter havido assalto antes. Morte limpa é um contratempo curto; execução
    -- depois da revista fecha o episódio e substitui o que restava do roubo pelo prazo cheio.
    local cooldown = afterRobbery
        and config.dealers.downAfterRobberyCooldownSeconds
        or config.dealers.downCooldownSeconds
    local downUntil = now + cooldown
    local nextSaleAt = downUntil + State.intervalFor(dealer.profile_key)

    if not Repositories.Dealer.markDown(dealer.id, dealer.version, downUntil, nextSaleAt, dealer.status) then
        State.reload(dealer.outpost_id)
        return false
    end

    -- Consome o carimbo: a partir daqui ele está em recuperação de morte, e uma segunda
    -- remarcação do mesmo corpo precisa ser recusada como sempre foi.
    robbedAt[dealerId] = nil

    -- O corpo fica caído onde estava, e some sozinho quando a área esvaziar.
    Entities.markCorpse(dealerId)

    local organizationId = entry.row.owner_organization_id

    -- Executar quem acabou de ser assaltado não abre registro próprio: para a organização o
    -- episódio é um só, e o alerta de roubo já saiu. O prazo muda, o aviso não se repete.
    -- O `Log` abaixo continua registrando os dois casos — ele é diagnóstico de servidor, não
    -- o histórico que o jogador lê.
    if not afterRobbery then
        Repositories.Operation.insert({
            id = Rotation.uuid(),
            type = C.OperationKind.DOWN,
            outpostId = dealer.outpost_id,
            dealerId = dealer.id,
            organizationId = organizationId,
            status = C.OperationStatus.COMMITTED,
            createdAt = now,
            committedAt = now,
            payload = {
                profileKey = dealer.profile_key,
                dealerName = State.dealerName(dealer),
                downUntil = downUntil,
                cooldown = cooldown,
            },
        })
    end

    State.reload(dealer.outpost_id)

    if not afterRobbery then
        local definition = shared.outposts[dealer.outpost_id]
        Notification.notifyOrganization(organizationId, 'security', {
            title = locale('phone.dealer_down_title'),
            body = locale('phone.dealer_down_body',
                State.dealerName(dealer), definition.label),
        })
    end
    -- Chamado para a polícia, nos dois caminhos. Sem ele, três rivais executam os quatro
    -- corredores e vão embora sem gerar ocorrência nenhuma — o dono recebe alertas no telefone e
    -- mais nada. Sai da posição do corredor, como o do assalto, e o cooldown de dispatch é por
    -- posto: uma chacina inteira vira uma ocorrência, não quatro.
    Notification.maybeDispatch(dealer, 'down', config.dealers.dispatchChance)

    Notification.broadcastPublicSnapshot()
    Notification.refreshPanels(dealer.outpost_id)

    Log.info('dealer_down', {
        outpostId = dealer.outpost_id,
        dealerId = dealer.id,
        downUntil = downUntil,
        cooldown = cooldown,
        afterRobbery = afterRobbery,
    })
    return true
end

---Corredores que cumpriram o cooldown voltam a operar e reaparecem no posto.
---Cobre tanto assalto quanto morte.
function Service.recoverDue()
    local now = os.time()
    for outpostId, entry in pairs(State.outposts) do
        local changed = false
        for dealerId, dealer in pairs(entry.dealers) do
            if dealer.status == C.DealerStatus.RECOVERING
                and dealer.robbed_until and dealer.robbed_until <= now then
                local nextSaleAt = now + State.intervalFor(dealer.profile_key)
                local affected = Repositories.Dealer.recover(dealerId, now, nextSaleAt)
                if affected and affected > 0 then
                    Service.forgetRobbery(dealerId)
                    changed = true
                end
            end
        end
        if changed then
            State.reload(outpostId)
            for dealerId, dealer in pairs(State.get(outpostId).dealers) do
                if dealer.status == C.DealerStatus.DEPLOYED then
                    if Entities.isAlive(dealerId) then
                        -- Voltou de assalto: o mesmo corredor retoma o posto.
                        Entities.setState(dealerId, C.DealerStatus.DEPLOYED)
                    else
                        -- Voltou de morte: remove o que sobrou do corpo e traz um substituto.
                        Entities.despawnDealer(dealerId)
                        Entities.spawnDealer(outpostId, dealer)
                    end
                end
            end
            Notification.broadcastPublicSnapshot()
            Notification.refreshPanels(outpostId)
        end
    end
end

---Confirma a morte de um corredor no instante em que o dono de rede dele diz que ele caiu.
---O aviso do client não derruba ninguém: ele só diz quando olhar. Quem decide é a leitura do
---servidor, com a mesma regra da varredura, e um client mentindo encontra um ped vivo.
---@param dealerId integer
---@return boolean marked
function Service.confirmDown(dealerId)
    if not Entities.readDown(dealerId) then return false end
    return Service.markDown(dealerId)
end

---Marca quem caiu, sem esperar a varredura periódica do scheduler.
---@return integer marked
function Service.sweepDown()
    local dead = Entities.deadDealers()
    local marked = 0
    for index = 1, #dead do
        if Service.markDown(dead[index]) then marked = marked + 1 end
    end
    return marked
end

---Devolve imediatamente todos os corredores em recuperação de um outpost.
---Uso administrativo: encurta o cooldown em vez de esperar.
---@param outpostId string
---@return integer recovered
function Service.forceRecover(outpostId)
    -- Põe o estado em dia antes de recuperar. Morte só vira estado na varredura, que roda a cada
    -- `dealers.auditSeconds`; sem isto, matar e recuperar em seguida encontra o corredor ainda em
    -- campo e o comando responde zero, como se não houvesse nada a fazer.
    Service.sweepDown()
    State.reload(outpostId)
    local entry = State.get(outpostId)
    if not entry then return 0 end

    local now = os.time()
    local count = 0
    for dealerId, dealer in pairs(entry.dealers) do
        if dealer.status == C.DealerStatus.RECOVERING
            and Repositories.Dealer.expireRecovery(dealerId, now) then
            count = count + 1
        end
    end

    if count > 0 then
        State.reload(outpostId)
        Service.recoverDue()
    end
    return count
end

---Dados públicos de um dealer, para quem não é dono.
---@param actor OutpostActor
---@param dealerId integer
---@param netId integer
---@return table result
function Service.inspect(actor, dealerId, netId)
    local dealer = State.dealer(dealerId)
    if not dealer then return { ok = false, code = 'unknown_dealer' } end
    local entity = Entities.validate(dealerId, netId)
    if not entity then return { ok = false, code = 'invalid_entity' } end
    if not Security.sameBucket(actor.source, entity) then return { ok = false, code = 'invalid_entity' } end
    if not Security.isNearEntity(actor.source, entity, shared.interaction.dealerDistance) then
        return { ok = false, code = 'too_far' }
    end

    local entry = State.get(dealer.outpost_id)
    if not entry then return { ok = false, code = 'unknown_outpost' } end
    local profile = State.profiles[dealer.profile_key]
    local isOwner = Security.isOwner(actor, entry.row)

    -- O estado mostrado é o que se vê, não o da linha do banco: quem reagiu ou está abalado
    -- continua "em campo" para o banco, e "em campo" é a única coisa que ele não está.
    -- Serviço lido tarde de propósito: `holdup_service` depende deste no carregamento.
    local Holdup = NoirOutposts.Services and NoirOutposts.Services.Holdup
    local holdupState = Holdup and Holdup.stateOf(dealer.id) or nil
    local status = dealer.status
    if holdupState == C.HoldupState.SURRENDERED then
        status = 'surrendered'
    elseif holdupState then
        status = 'held_up'
    end

    local data = {
        dealerId = dealer.id,
        name = State.dealerName(dealer),
        profileName = profile and profile.name or dealer.profile_key,
        status = status,
        outpostLabel = shared.outposts[dealer.outpost_id].label,
        isOwner = isOwner,
    }
    if isOwner then
        data.nextSaleAt = dealer.next_sale_at
        data.lifetimeSales = dealer.lifetime_sales
        data.stockTotal = State.stockTotal(dealer.outpost_id)
    end
    return { ok = true, data = data }
end
