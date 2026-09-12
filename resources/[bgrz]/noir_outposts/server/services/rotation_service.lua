-- Seleção persistida dos outposts ativos por ciclo. Restart no mesmo ciclo restaura a rotação.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Rotation = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Entities = NoirOutposts.Entities
local Sessions = NoirOutposts.Sessions
local Repositories = NoirOutposts.Repositories

local currentRotation = nil

---@param now integer
---@return string cycleKey, integer startsAt, integer endsAt
local function cycleFor(now)
    local durationSeconds = config.rotation.durationHours * 3600
    local index = math.floor(now / durationSeconds)
    local startsAt = index * durationSeconds
    return ('cycle:%d'):format(index), startsAt, startsAt + durationSeconds
end

local function shuffled(list)
    local copy = {}
    for index = 1, #list do copy[index] = list[index] end
    for index = #copy, 2, -1 do
        local pick = math.random(index)
        copy[index], copy[pick] = copy[pick], copy[index]
    end
    return copy
end

---Sorteia os ativos: um `drug` obrigatório, `money` opcional, sem repetir local.
---@return table state { assignments = { [id] = type } }
local function draw()
    local drugCandidates, moneyCandidates = {}, {}
    for id, definition in pairs(shared.outposts) do
        for index = 1, #definition.typePool do
            if definition.typePool[index] == C.OperationType.DRUG then drugCandidates[#drugCandidates + 1] = id end
            if definition.typePool[index] == C.OperationType.MONEY then moneyCandidates[#moneyCandidates + 1] = id end
        end
    end
    table.sort(drugCandidates)
    table.sort(moneyCandidates)

    local assignments = {}
    local used = {}
    local drugs = shuffled(drugCandidates)
    for index = 1, #drugs do
        if #used >= config.rotation.activeDrugOutposts then break end
        local id = drugs[index]
        if not assignments[id] then
            assignments[id] = C.OperationType.DRUG
            used[#used + 1] = id
        end
    end

    local moneyAssigned = 0
    local moneys = shuffled(moneyCandidates)
    for index = 1, #moneys do
        if moneyAssigned >= config.rotation.activeMoneyOutposts then break end
        local id = moneys[index]
        if not assignments[id] then
            assignments[id] = C.OperationType.MONEY
            moneyAssigned = moneyAssigned + 1
        end
    end

    return { assignments = assignments }
end

---Desativa um outpost: encerra sessões, remove dealers/estoque e zera a carteira.
---@param outpostId string
local function deactivate(outpostId)
    local entry = State.get(outpostId)
    if entry and entry.row.owner_organization_id and entry.row.purse_available > 0
        and config.rotation.forfeitPurseOnDeactivate then
        Repositories.Operation.insert({
            id = NoirOutposts.Services.Rotation.uuid(),
            type = C.OperationKind.FORFEIT,
            outpostId = outpostId,
            organizationId = entry.row.owner_organization_id,
            net = entry.row.purse_available,
            status = C.OperationStatus.COMMITTED,
            createdAt = os.time(),
            committedAt = os.time(),
        })
    end
    Sessions.abortForOutpost(outpostId, 'outpost_inactive')
    Entities.despawnOutpost(outpostId)
    Repositories.Dealer.deleteByOutpost(outpostId)
    Repositories.Stock.clearByOutpost(outpostId)
    Repositories.Outpost.deactivate(outpostId)
    State.reload(outpostId)
end

---@param outpostId string
---@param operationType string
---@param rotationId integer
local function activate(outpostId, operationType, rotationId)
    Sessions.abortForOutpost(outpostId, 'outpost_rotated')
    Entities.despawnOutpost(outpostId)
    Repositories.Dealer.deleteByOutpost(outpostId)
    Repositories.Stock.clearByOutpost(outpostId)
    Repositories.Outpost.activate(outpostId, operationType, rotationId)
    Repositories.Stock.ensureProducts(outpostId, State.productIds)
    State.reload(outpostId)
end

local uuidCounter = 0

---@return string
function Service.uuid()
    uuidCounter = uuidCounter + 1
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(character)
        local value = character == 'x' and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(value)
    end))
end

---Aplica a rotação do ciclo atual, restaurando a persistida quando já existe.
---@return table? rotation
function Service.apply()
    local now = os.time()
    local cycleKey, startsAt, endsAt = cycleFor(now)

    local row = Repositories.Rotation.getByCycle(cycleKey)
    if not row then
        local state = draw()
        Repositories.Rotation.insert(cycleKey, startsAt, endsAt, state)
        row = Repositories.Rotation.getByCycle(cycleKey)
        if not row then
            Log.error('rotation_persist_failed', { cycleKey = cycleKey })
            return nil
        end
        Log.info('rotation_created', { cycleKey = cycleKey, assignments = state.assignments })
    end

    local assignments = type(row.state) == 'table' and row.state.assignments or {}
    if type(assignments) ~= 'table' then assignments = {} end

    for id in pairs(shared.outposts) do
        local entry = State.get(id)
        local desired = assignments[id]
        local current = entry and entry.row or nil
        local isActive = current ~= nil and current.status ~= C.OutpostStatus.INACTIVE
        if desired and (not isActive or current.rotation_id ~= row.id) then
            activate(id, desired, row.id)
        elseif not desired and isActive then
            deactivate(id)
        end
    end

    currentRotation = { id = row.id, cycleKey = cycleKey, startsAt = startsAt, endsAt = endsAt, assignments = assignments }
    Entities.syncAll()
    return currentRotation
end

---@return table? rotation
function Service.current()
    return currentRotation
end

---@return boolean expired
function Service.isCycleExpired()
    if not currentRotation then return true end
    return os.time() >= currentRotation.endsAt
end

---Rotaciona os dealers entre corners livres (ambiência, não afeta economia).
---@param outpostId string
function Service.rotateCorners(outpostId)
    local entry = State.get(outpostId)
    if not entry or entry.row.status ~= C.OutpostStatus.CONTROLLED then return end
    local definition = shared.outposts[outpostId]
    local total = #definition.dealerCorners
    local dealers = State.sortedDealers(outpostId)
    if #dealers == 0 or total <= #dealers then return end

    local available = {}
    for index = 1, total do available[#available + 1] = index end
    available = shuffled(available)

    local assigned = {}
    for index = 1, #dealers do
        local dealer = dealers[index]
        local target = available[index]
        if target and target ~= dealer.corner_index and not assigned[target] then
            assigned[target] = true
            if Repositories.Dealer.setCorner(dealer.id, target) then
                dealer.corner_index = target
                Entities.spawnDealer(outpostId, dealer)
            end
        end
    end
    Repositories.Outpost.setCornerRotation(outpostId, os.time())
    State.reload(outpostId)
end

---Libera o controle de um outpost expirado, mantendo-o disponível no ciclo.
---@param outpostId string
function Service.releaseExpired(outpostId)
    local entry = State.get(outpostId)
    if not entry then return end
    local organizationId = entry.row.owner_organization_id
    Sessions.abortForOutpost(outpostId, 'owner_expired')
    Entities.despawnOutpost(outpostId)
    Repositories.Dealer.deleteByOutpost(outpostId)
    Repositories.Stock.clearByOutpost(outpostId)
    Repositories.Outpost.release(outpostId)
    Repositories.Stock.ensureProducts(outpostId, State.productIds)
    State.reload(outpostId)
    Log.info('outpost_released', { outpostId = outpostId, organizationId = organizationId })
    return organizationId
end
