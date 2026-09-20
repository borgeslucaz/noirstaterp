---Smash & Grab — o mundo: quais carros têm objeto, e o ciclo de vida do prop.
---
---Este arquivo é onde mora todo o custo do sistema, então vale dizer o que ele NÃO
---faz: não roda por frame, não pergunta nada ao servidor sobre spawn, e não guarda
---veículo nenhum além dos que estão com prop na tela agora.
---
---A varredura é um passo só, a cada `scanInterval`: pega o pool de veículos que o
---client já tem carregado, filtra por distância e elegibilidade, e **pergunta ao
---servidor** quais deles têm objeto. O client não decide e não consegue adivinhar:
---sem resposta do servidor não há prop, e o servidor só responde sobre veículos
---realmente perto de quem perguntou.
---
---A resposta é memorizada por veículo, então cada carro é perguntado uma vez só
---enquanto estiver por perto — a consulta carrega só os que ainda não têm resposta.

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local CrimeConfig = require 'config.smashgrab'
local Rules = require 'shared.smashgrab_rules'
local Interaction = require 'client.crimes.smashgrab.interaction'

local CRIME = Constants.crimes.smashgrab
local DebugPrint = Utils.debugPrint(CRIME)
local STATE = Constants.state.smashGrab
local ELIGIBILITY = CrimeConfig.eligibility
local EVENT_SURVEY = Constants.event('server', CRIME, 'survey')

local World = {}

---Quantas varreduras completaram. Numerar é o que mostra se o laço parou.
local scanCount = 0

---Veículos vistos ao alcance na última varredura. É o sinal honesto de "região
---vazia", e o que decide se vale desacelerar.
local lastNearby = 0

---@return integer
function World.lastNearbyCount()
    return lastNearby
end

---Veículos com prop na tela agora. É a única tabela que cresce, e ela é limitada
---pelo número de carros dentro de `renderDistance`.
---@type table<number, table>
local tracked = {}

---Resposta do servidor por veículo, para perguntar cada carro uma vez só.
---Guarda a placa junto porque handle de entidade é reciclado pelo jogo: se a placa
---mudou, o handle é outro carro e a pergunta precisa ser refeita.
---@type table<number, { plate: string?, loot: table|false }>
local evaluated = {}

---@type table<number, boolean>
local blockedModels = {}
for index = 1, #ELIGIBILITY.vehicleModelBlacklist do
    blockedModels[joaat(ELIGIBILITY.vehicleModelBlacklist[index])] = true
end

---Hash -> nome, só para os modelos que têm override de offset. É o único caso em
---que precisamos voltar do hash para o nome, e o jogo não oferece isso.
---@type table<number, string>
local overrideNames = {}
for name in pairs(CrimeConfig.vehicleOffsets) do overrideNames[joaat(name)] = name end

---Props cujo modelo não existe neste build. Ficam de fora do desenho, mas NÃO do
---sorteio: o servidor sorteia sobre a lista inteira, e tirar um prop daqui faria os
---dois lados discordarem. O que se perde é o visual daquele objeto, não o loot.
---@type table<string, boolean>
local invalidProps = {}

---@param model number
---@return number
local function normalizeModel(model)
    return math.floor(model) % 0x100000000
end

-- ---------------------------------------------------------------------------
-- Elegibilidade
-- ---------------------------------------------------------------------------

---@param vehicle number
---@return boolean
local function isEmpty(vehicle)
    if not IsVehicleSeatFree(vehicle, -1) then return false end
    local seats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 0, seats - 1 do
        if not IsVehicleSeatFree(vehicle, seat) then return false end
    end
    return true
end

---@param vehicle number
---@return boolean eligible
---@return string? reason código curto, usado pelo debug
function World.isEligible(vehicle)
    if not DoesEntityExist(vehicle) then return false, 'gone' end
    if GetEntityType(vehicle) ~= 2 then return false, 'not_vehicle' end

    -- Sem rede não há netId, e sem netId o servidor não tem como validar o pedido.
    if not NetworkGetEntityIsNetworked(vehicle) then return false, 'not_networked' end

    if ELIGIBILITY.vehicleClassBlacklist[GetVehicleClass(vehicle)] then return false, 'class' end
    if blockedModels[normalizeModel(GetEntityModel(vehicle))] then return false, 'model' end

    if ELIGIBILITY.blockPlayerOwned then
        local state = Entity(vehicle).state
        for index = 1, #ELIGIBILITY.ownedStateBags do
            if state[ELIGIBILITY.ownedStateBags[index]] then return false, 'player_owned' end
        end
    end

    if ELIGIBILITY.blockOccupied and not isEmpty(vehicle) then return false, 'occupied' end
    if ELIGIBILITY.blockMoving and GetEntitySpeed(vehicle) > ELIGIBILITY.maxSpeed then
        return false, 'moving'
    end
    if ELIGIBILITY.blockDestroyed then
        if IsEntityDead(vehicle) then return false, 'destroyed' end
        if GetVehicleBodyHealth(vehicle) < ELIGIBILITY.minBodyHealth then return false, 'destroyed' end
    end

    return true
end

---@param vehicle number
---@return boolean
local function isTaken(vehicle)
    return Entity(vehicle).state[STATE] == 'claimed'
end

-- ---------------------------------------------------------------------------
-- Consulta ao servidor
-- ---------------------------------------------------------------------------

---Resposta já conhecida para um veículo.
---@param vehicle number
---@return table|false|nil loot  nil = ainda não perguntamos
function World.known(vehicle)
    local cached = evaluated[vehicle]
    if not cached then return nil end
    if cached.plate ~= Rules.normalizePlate(GetVehicleNumberPlateText(vehicle)) then
        -- Handle reciclado pelo jogo: é outro carro, a resposta antiga não vale.
        evaluated[vehicle] = nil
        return nil
    end
    return cached.loot
end

---Pergunta ao servidor sobre os veículos que ainda não têm resposta.
---
---A resposta tem três valores, e a diferença importa: tabela é "tem este objeto",
---`false` é "decidido, não tem nada", e AUSENTE é "não deu para responder agora".
---Só os dois primeiros são memorizados; o ausente volta na varredura seguinte.
---Tratar ausência como "não tem" congelaria uma recusa temporária (carro andando,
---longe, ocupado) até ele sair dos 120 m.
---@param candidates table<number, number> vehicle -> netId
local function survey(candidates)
    local netIds, byNetId = {}, {}
    for vehicle, netId in pairs(candidates) do
        netIds[#netIds + 1] = netId
        byNetId[netId] = vehicle
        if #netIds >= CrimeConfig.surveyBatchMax then break end
    end
    if #netIds == 0 then return end

    local answer = lib.callback.await(EVENT_SURVEY, CrimeConfig.callbackTimeout, netIds)

    -- Servidor recusou o lote inteiro (rate limit, desconectado).
    if type(answer) ~= 'table' then
        DebugPrint('consulta recusada; tentando de novo na próxima varredura')
        return
    end

    for index = 1, #netIds do
        local netId = netIds[index]
        local vehicle = byNetId[netId]
        local entry = answer[netId]
        if entry == nil then entry = answer[tostring(netId)] end

        if DoesEntityExist(vehicle) and entry ~= nil then
            evaluated[vehicle] = {
                plate = Rules.normalizePlate(GetVehicleNumberPlateText(vehicle)),
                loot = type(entry) == 'table' and (Rules.compose(entry.propKey, entry.seatKey) or false)
                    or false,
            }
        end
    end
end

-- ---------------------------------------------------------------------------
-- Prop
-- ---------------------------------------------------------------------------

---Modelo ausente no build do Enhanced derruba o cliente na thread de render, sem
---erro de script. Conferimos antes de pedir, sempre.
---@param hash number
---@return boolean
local function ensureModel(hash)
    if not IsModelValid(hash) or not IsModelInCdimage(hash) then return false end
    if HasModelLoaded(hash) then return true end

    -- lib.requestModel já carrega com timeout (§17.1). Ele levanta erro se o
    -- modelo não chegar, e aqui a falha é esperada o suficiente para não virar
    -- stack trace: o prop simplesmente não é desenhado.
    local ok = pcall(lib.requestModel, hash, 5000)
    return ok and HasModelLoaded(hash)
end

---@param entry table
---@return boolean
local function spawnProp(entry)
    if invalidProps[entry.loot.propKey] then return false end

    local hash = joaat(entry.loot.prop.model)
    if not ensureModel(hash) then
        invalidProps[entry.loot.propKey] = true
        lib.print.warn(('prop indisponível neste build: %s (%s)'):format(entry.loot.prop.model, entry.loot.propKey))
        return false
    end

    -- Objeto local, não networked: cada client desenha o seu. É o que torna o
    -- sistema barato — nenhuma entidade de servidor, nenhuma replicação de prop.
    -- A consistência entre jogadores vem da decisão determinística, não da rede.
    local prop = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    if prop == 0 or not DoesEntityExist(prop) then return false end

    SetEntityCollision(prop, false, false)
    SetEntityAsMissionEntity(prop, true, true)

    local boneIndex = GetEntityBoneIndexByName(entry.vehicle, entry.loot.seat.bone)
    -- Modelo sem o osso do banco (raro, mas existe): grudamos no centro do carro
    -- em vez de descartar o objeto. Índice 0 é a raiz da entidade.
    if boneIndex == -1 then
        boneIndex = 0
        DebugPrint('osso ausente, usando raiz:', entry.loot.seat.bone)
    end

    local offset, rotation = Rules.attachmentFor(entry.loot, overrideNames[entry.model])

    -- Preso ao osso, o prop acompanha o carro sozinho — inclusive se alguém sair
    -- dirigindo. Não há atualização de posição por frame em lugar nenhum daqui.
    AttachEntityToEntity(prop, entry.vehicle, boneIndex,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, false, false, false, 2, true)

    SetModelAsNoLongerNeeded(hash)

    entry.prop = prop
    Interaction.attach(entry)
    return true
end

---@param vehicle number
function World.release(vehicle)
    local entry = tracked[vehicle]
    if not entry then return end

    tracked[vehicle] = nil

    -- O alvo sai SEMPRE, e antes do prop: ele vive no veículo, que sobrevive ao
    -- prop. Condicionar a remoção à existência do prop deixaria "Quebrar vidro"
    -- pendurado no carro para sempre quando o objeto some primeiro.
    Interaction.detach(entry)

    if entry.prop and DoesEntityExist(entry.prop) then
        -- Soltar do osso antes de apagar, como o noir_graffiti faz aqui.
        DetachEntity(entry.prop, true, true)
        -- `DeleteObject`, e não `DeleteEntity`: o prop é um CObject, e este é o
        -- native específico para ele. O genérico estourava dentro do jogo
        -- ("exception at game RVA 0x1918"). O sd-phone, que também mantém props
        -- locais sincronizados por state bag, usa `DeleteObject` — e é o que 47
        -- arquivos deste servidor usam para objeto.
        DeleteObject(entry.prop)
    end
    entry.prop = nil
end

---@return table<number, table>
function World.tracked()
    return tracked
end

-- ---------------------------------------------------------------------------
-- Varredura
-- ---------------------------------------------------------------------------

---@param vehicle number
---@param distance number
---@param vehicle number
---@param distance number
---@param eligible boolean? já conferido nesta varredura
local function consider(vehicle, distance, eligible)
    if distance > CrimeConfig.renderDistance then return end
    if isTaken(vehicle) then return end

    -- `known` primeiro: é um lookup de tabela, e a maioria dos carros já é
    -- conhecida como sem objeto. Rodar a elegibilidade antes gastaria uma dúzia
    -- de natives por carro para chegar à mesma conclusão.
    local loot = World.known(vehicle)
    if not loot then return end

    if not eligible and not World.isEligible(vehicle) then return end

    local entry = {
        vehicle = vehicle,
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        model = normalizeModel(GetEntityModel(vehicle)),
        loot = loot,
        windowIndex = loot.seat.window,
    }

    if not spawnProp(entry) then return end

    tracked[vehicle] = entry
    DebugPrint(('objeto em netId %s: %s no %s (janela %d)')
        :format(entry.netId, loot.propKey, loot.seatKey, entry.windowIndex))
end

---Um passo de varredura. Chamado pelo `init.lua` em intervalo, nunca por frame.
function World.scan()
    local playerCoords = GetEntityCoords(cache.ped)

    local nearby = {}
    local pool = GetGamePool('CVehicle')
    for index = 1, #pool do
        local vehicle = pool[index]
        local distance = #(playerCoords - GetEntityCoords(vehicle))
        if distance <= CrimeConfig.cleanupDistance then nearby[vehicle] = distance end
    end

    -- Limpeza primeiro, para que o prop de um carro que deixou de ser elegível
    -- (alguém entrou, saiu dirigindo, foi roubado) suma antes de qualquer coisa.
    local stale = {}
    for vehicle, entry in pairs(tracked) do
        local distance = nearby[vehicle]
        if not distance
            or distance > CrimeConfig.cleanupDistance
            or not DoesEntityExist(vehicle)
            or not DoesEntityExist(entry.prop)
            or isTaken(vehicle)
            or not World.isEligible(vehicle) then
            stale[#stale + 1] = vehicle
        end
    end
    for index = 1, #stale do World.release(stale[index]) end

    -- Some do cache o que saiu do alcance, senão a tabela cresce com o tempo.
    for vehicle in pairs(evaluated) do
        if not nearby[vehicle] then evaluated[vehicle] = nil end
    end

    -- Um passe só de elegibilidade, guardado para o `consider` reaproveitar.
    -- Antes ela rodava duas vezes por veículo na mesma varredura.
    local eligible = {}
    local candidates = {}
    -- Contagem por etapa. É o que responde "por que não acho nenhum": cada motivo
    -- de recusa fica separado, em vez de tudo virar um zero sem explicação.
    local stats = { pool = 0, alcance = 0, elegiveis = 0, perguntados = 0, comObjeto = 0, longe = 0, motivos = {} }
    for _ in pairs(nearby) do stats.pool = stats.pool + 1 end

    for vehicle, distance in pairs(nearby) do
        if not tracked[vehicle] and distance <= CrimeConfig.activationDistance then
            stats.alcance = stats.alcance + 1
            local known = World.known(vehicle)
            -- Só vale gastar a elegibilidade em quem ainda não tem resposta ou em
            -- quem tem objeto para desenhar.
            if known == nil or known then
                local ok, reason = World.isEligible(vehicle)
                eligible[vehicle] = ok
                if ok then
                    stats.elegiveis = stats.elegiveis + 1
                else
                    stats.motivos[reason] = (stats.motivos[reason] or 0) + 1
                end
                if known == nil and ok then
                    candidates[vehicle] = NetworkGetNetworkIdFromEntity(vehicle)
                    stats.perguntados = stats.perguntados + 1
                end
            elseif known then
                stats.comObjeto = stats.comObjeto + 1
            end
        end
    end
    if next(candidates) then survey(candidates) end

    for vehicle in pairs(candidates) do
        if World.known(vehicle) then stats.comObjeto = stats.comObjeto + 1 end
    end

    -- Quantos têm objeto mas estão fora do raio de desenho. É a diferença entre
    -- "o sorteio falhou" e "está tudo certo, só longe" — e sem separar as duas,
    -- um número baixo de desenhados não diz nada.
    for vehicle, distance in pairs(nearby) do
        if not tracked[vehicle] and World.known(vehicle) and distance > CrimeConfig.renderDistance then
            stats.longe = stats.longe + 1
        end
    end

    for vehicle, distance in pairs(nearby) do
        if not tracked[vehicle] then consider(vehicle, distance, eligible[vehicle]) end
    end

    local desenhados = 0
    for _ in pairs(tracked) do desenhados = desenhados + 1 end

    local motivos = {}
    for reason, count in pairs(stats.motivos) do
        motivos[#motivos + 1] = ('%s=%d'):format(reason, count)
    end
    table.sort(motivos)

    scanCount = scanCount + 1
    lastNearby = stats.pool
    DebugPrint(('varredura #%d: %d no pool | %d ao alcance | %d elegíveis | %d perguntados | %d com objeto | %d longe p/ desenhar | %d desenhados%s')
        :format(scanCount, stats.pool, stats.alcance, stats.elegiveis, stats.perguntados,
            stats.comObjeto, stats.longe, desenhados,
            #motivos > 0 and ('  [recusas: %s]'):format(table.concat(motivos, ' ')) or ''))
end


-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function World.start()
    for key, prop in pairs(CrimeConfig.props) do
        local hash = joaat(prop.model)
        if not IsModelValid(hash) or not IsModelInCdimage(hash) then
            invalidProps[key] = true
            lib.print.error(('prop "%s" não existe neste build: %s'):format(key, prop.model))
        end
    end

    -- Remoção instantânea quando o servidor marca o objeto como levado. A
    -- varredura também cobre isso, mas só no próximo ciclo — e "o outro jogador
    -- continuou vendo a mochila por um segundo e meio" é exatamente o que não
    -- pode acontecer.
    AddStateBagChangeHandler(STATE, nil, function(bagName, _, value)
        if value ~= 'claimed' then return end

        local netId = tonumber(bagName:match('^entity:(%d+)$'))
        if not netId then return end

        -- `SetTimeout(0)` de propósito: o handler de state bag roda por
        -- `CreateThreadNow`, dentro do processamento do próprio state bag, e
        -- destruir entidade ali reentra na gestão de entidades do jogo no meio
        -- dela. O adiamento cai no tick seguinte do scheduler — imperceptível
        -- para o jogador, e fora daquele contexto.
        SetTimeout(0, function()
            local vehicle = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or nil
            if vehicle and vehicle ~= 0 then World.release(vehicle) end
        end)
    end)
end

---Solta tudo sem desmontar o módulo. Usado quando o jogador entra num veículo: dali
---ele não interage com nada, e manter props presos a carros que vão ficar para trás
---só acumularia objeto órfão enquanto a varredura está parada.
function World.releaseAll()
    local vehicles = {}
    for vehicle in pairs(tracked) do vehicles[#vehicles + 1] = vehicle end
    for index = 1, #vehicles do World.release(vehicles[index]) end
end

function World.stop()
    local vehicles = {}
    for vehicle in pairs(tracked) do vehicles[#vehicles + 1] = vehicle end
    for index = 1, #vehicles do World.release(vehicles[index]) end
    tracked, evaluated = {}, {}
end

return World
