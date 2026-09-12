-- Integração dos serviços de domínio contra repositórios e providers falsos.
-- Cobre depósito com compensação, venda atômica, coleta idempotente e roubo.
local T = dofile('tests/testlib.lua')

-- Runtime -------------------------------------------------------------------------------

local Vector = {}
Vector.__index = Vector
Vector.__sub = function(a, b)
    return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, Vector)
end
Vector.__len = function(self)
    return math.floor(math.sqrt(self.x ^ 2 + self.y ^ 2 + self.z ^ 2))
end

function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, Vector) end
function vector4(x, y, z, w) return setmetatable({ x = x, y = y, z = z, w = w }, Vector) end

local gameTimer = 100000
GetGameTimer = function() return gameTimer end

local pedCoords = {}
GetPlayerPed = function(source) return source > 0 and source * 10 or 0 end
GetEntityCoords = function(ped) return pedCoords[ped] or vector3(0.0, 0.0, 0.0) end
GetEntityRoutingBucket = function() return 0 end
GetPlayerRoutingBucket = function() return 0 end
DoesEntityExist = function(entity) return entity ~= nil and entity ~= 0 end
GetEntityType = function() return 1 end
GetEntityModel = function() return 1234 end
IsPlayerAceAllowed = function() return false end
TriggerClientEvent = function() end
TriggerEvent = function() end
AddEventHandler = function() end
GetResourceState = function() return 'started' end
GetPlayers = function() return {} end

lib = { print = { debug = function() end, info = function() end, warn = function() end, error = function() end } }
locale = function(key) return key end
json = { encode = function() return '{}' end, decode = function() return {} end }

local N = T.loadShared()
local C = N.Constants

local serverConfig = T.loadConfig('config/server.lua')
local sharedConfig = T.loadConfig('config/shared.lua')
package.loaded['config.server'] = serverConfig
package.loaded['config.shared'] = sharedConfig
require = function(name) return package.loaded[name] end

dofile('server/log.lua')

-- Repositórios falsos, preservando as mesmas invariantes do SQL -----------------------------

local db = {
    outposts = {},
    dealers = {},
    stock = {},
    operations = {},
    organizations = {},
    dealerSequence = 0,
}

local function outpostRow(id)
    return db.outposts[id]
end

N.Repositories = {}

N.Repositories.Outpost = {
    get = function(id)
        local row = outpostRow(id)
        if not row then return nil end
        local copy = {}
        for key, value in pairs(row) do copy[key] = value end
        return copy
    end,
    getAll = function()
        local rows = {}
        for id in pairs(db.outposts) do rows[#rows + 1] = N.Repositories.Outpost.get(id) end
        return rows
    end,
    movePurseToPending = function(id, organizationId, amount)
        local row = outpostRow(id)
        if not row or row.status ~= C.OutpostStatus.CONTROLLED then return 0 end
        if row.owner_organization_id ~= organizationId then return 0 end
        if row.purse_available < amount then return 0 end
        row.purse_available = row.purse_available - amount
        row.purse_pending = row.purse_pending + amount
        return 1
    end,
    settlePending = function(id, amount)
        local row = outpostRow(id)
        if row.purse_pending < amount then return 0 end
        row.purse_pending = row.purse_pending - amount
        return 1
    end,
    restorePending = function(id, amount)
        local row = outpostRow(id)
        if row.purse_pending < amount then return 0 end
        row.purse_pending = row.purse_pending - amount
        row.purse_available = row.purse_available + amount
        return 1
    end,
    restorePurse = function(id, amount)
        outpostRow(id).purse_available = outpostRow(id).purse_available + amount
        return 1
    end,
    getOrganization = function(organizationId) return db.organizations[organizationId] end,
    setOrganizationCooldown = function(organizationId, until_)
        db.organizations[organizationId] = { claim_cooldown_until = until_ }
        return 1
    end,
    setCornerRotation = function() return 1 end,
    setExpiryWarned = function() return 1 end,
    startClaim = function(id, sessionId, organizationId, now)
        local row = outpostRow(id)
        if not row or row.status ~= C.OutpostStatus.AVAILABLE then return 0 end
        row.status = C.OutpostStatus.CLAIMING
        row.claim_session_id = sessionId
        row.claim_organization_id = organizationId
        row.claim_started_at = now
        return 1
    end,
    cancelClaim = function(id, sessionId)
        local row = outpostRow(id)
        if not row or row.status ~= C.OutpostStatus.CLAIMING then return 0 end
        if row.claim_session_id ~= sessionId then return 0 end
        row.status = C.OutpostStatus.AVAILABLE
        row.claim_session_id, row.claim_organization_id, row.claim_started_at = nil, nil, nil
        return 1
    end,
    completeClaim = function(id, sessionId, organizationId, citizenId, now, expiresAt, dealerRoster)
        local row = outpostRow(id)
        if not row or row.status ~= C.OutpostStatus.CLAIMING then return 0 end
        if row.claim_session_id ~= sessionId then return 0 end
        row.status = C.OutpostStatus.CONTROLLED
        row.owner_organization_id = organizationId
        row.kingpin_citizenid = citizenId
        row.claimed_at, row.expires_at = now, expiresAt
        row.claim_session_id, row.claim_organization_id, row.claim_started_at = nil, nil, nil
        row.purse_available, row.purse_pending = 0, 0
        row.dealer_roster = dealerRoster
        return 1
    end,
}

N.Repositories.Dealer = {
    listAll = function()
        local rows = {}
        for _, dealer in pairs(db.dealers) do rows[#rows + 1] = dealer end
        table.sort(rows, function(a, b) return a.id < b.id end)
        return rows
    end,
    listByOutpost = function(outpostId)
        local rows = {}
        for _, dealer in pairs(db.dealers) do
            if dealer.outpost_id == outpostId then rows[#rows + 1] = dealer end
        end
        table.sort(rows, function(a, b) return a.id < b.id end)
        return rows
    end,
    get = function(id) return db.dealers[id] end,
    insert = function(dealer, maxDealers)
        local count = 0
        for _, row in pairs(db.dealers) do
            if row.outpost_id == dealer.outpostId then
                count = count + 1
                if row.profile_key == dealer.profileKey then return nil end
            end
        end
        if count >= maxDealers then return nil end
        db.dealerSequence = db.dealerSequence + 1
        db.dealers[db.dealerSequence] = {
            id = db.dealerSequence,
            outpost_id = dealer.outpostId,
            profile_key = dealer.profileKey,
            display_name = dealer.displayName,
            ped_model = dealer.pedModel,
            status = C.DealerStatus.DEPLOYED,
            corner_index = dealer.cornerIndex,
            hired_by_citizenid = dealer.hiredBy,
            hired_at = dealer.hiredAt,
            next_sale_at = dealer.nextSaleAt,
            robbed_until = nil,
            lifetime_sales = 0,
            lifetime_gross = 0,
            version = 0,
        }
        return db.dealerSequence
    end,
    delete = function(id)
        if not db.dealers[id] then return 0 end
        db.dealers[id] = nil
        return 1
    end,
    deleteByOutpost = function(outpostId)
        for id, dealer in pairs(db.dealers) do
            if dealer.outpost_id == outpostId then db.dealers[id] = nil end
        end
        return 1
    end,
    setCorner = function(id, corner)
        db.dealers[id].corner_index = corner
        return 1
    end,
    reschedule = function(id, nextSaleAt)
        db.dealers[id].next_sale_at = nextSaleAt
        return 1
    end,
    recover = function(id, now, nextSaleAt)
        local dealer = db.dealers[id]
        if not dealer or dealer.status ~= C.DealerStatus.RECOVERING then return 0 end
        if not dealer.robbed_until or dealer.robbed_until > now then return 0 end
        dealer.status = C.DealerStatus.DEPLOYED
        dealer.next_sale_at = nextSaleAt
        dealer.version = dealer.version + 1
        return 1
    end,
    expireRecovery = function(dealerId, now)
        local dealer = db.dealers[dealerId]
        if not dealer or dealer.status ~= C.DealerStatus.RECOVERING then return false end
        dealer.robbed_until = now - 1
        return true
    end,
    markDown = function(dealerId, dealerVersion, downUntil, nextSaleAt, fromStatus)
        local dealer = db.dealers[dealerId]
        if not dealer or dealer.status ~= (fromStatus or C.DealerStatus.DEPLOYED) then return false end
        if dealer.version ~= dealerVersion then return false end
        dealer.status = C.DealerStatus.RECOVERING
        dealer.robbed_until = downUntil
        dealer.next_sale_at = nextSaleAt
        dealer.version = dealer.version + 1
        return true
    end,
    applySale = function(sale)
        local dealer = db.dealers[sale.dealerId]
        local row = outpostRow(sale.outpostId)
        local stock = db.stock[sale.outpostId] and db.stock[sale.outpostId][sale.item]
        if not dealer or not row or stock == nil then return false end
        if dealer.status ~= C.DealerStatus.DEPLOYED or dealer.version ~= sale.dealerVersion then return false end
        if row.status ~= C.OutpostStatus.CONTROLLED then return false end
        if row.owner_organization_id ~= sale.organizationId then return false end
        if row.expires_at and row.expires_at <= sale.now then return false end
        if stock < sale.quantity then return false end

        db.stock[sale.outpostId][sale.item] = stock - sale.quantity
        row.purse_available = row.purse_available + sale.net
        dealer.next_sale_at = sale.nextSaleAt
        dealer.lifetime_sales = dealer.lifetime_sales + 1
        dealer.lifetime_gross = dealer.lifetime_gross + sale.gross
        dealer.version = dealer.version + 1
        return true
    end,
    applyRobbery = function(robbery)
        local dealer = db.dealers[robbery.dealerId]
        local row = outpostRow(robbery.outpostId)
        if not dealer or not row then return false end
        if dealer.status ~= C.DealerStatus.DEPLOYED or dealer.version ~= robbery.dealerVersion then return false end
        if row.status ~= C.OutpostStatus.CONTROLLED then return false end
        if row.purse_available < robbery.purseLoot then return false end
        if robbery.item and robbery.stockLoot > 0 then
            local stock = db.stock[robbery.outpostId][robbery.item] or 0
            if stock < robbery.stockLoot then return false end
            db.stock[robbery.outpostId][robbery.item] = stock - robbery.stockLoot
        end
        row.purse_available = row.purse_available - robbery.purseLoot
        dealer.status = C.DealerStatus.RECOVERING
        dealer.robbed_until = robbery.robbedUntil
        dealer.next_sale_at = robbery.nextSaleAt
        dealer.version = dealer.version + 1
        return true
    end,
}

N.Repositories.Stock = {
    listByOutpost = function(outpostId)
        local rows = {}
        for item, quantity in pairs(db.stock[outpostId] or {}) do
            rows[#rows + 1] = { item_name = item, quantity = quantity }
        end
        table.sort(rows, function(a, b) return a.item_name < b.item_name end)
        return rows
    end,
    listAll = function()
        local rows = {}
        for outpostId, items in pairs(db.stock) do
            for item, quantity in pairs(items) do
                rows[#rows + 1] = { outpost_id = outpostId, item_name = item, quantity = quantity }
            end
        end
        return rows
    end,
    ensureProducts = function(outpostId, items)
        db.stock[outpostId] = db.stock[outpostId] or {}
        for index = 1, #items do
            db.stock[outpostId][items[index]] = db.stock[outpostId][items[index]] or 0
        end
    end,
    deposit = function(outpostId, item, amount, maxTotal)
        local items = db.stock[outpostId]
        if not items or items[item] == nil then return false end
        local total = 0
        for _, quantity in pairs(items) do total = total + quantity end
        if total + amount > maxTotal then return false end
        items[item] = items[item] + amount
        return true
    end,
    restore = function(outpostId, item, amount)
        db.stock[outpostId][item] = (db.stock[outpostId][item] or 0) + amount
        return 1
    end,
    clearByOutpost = function(outpostId) db.stock[outpostId] = nil end,
}

local settingsRows = {}
N.Repositories.Settings = {
    get = function(citizenId) return settingsRows[citizenId] end,
    setAlerts = function(citizenId, alerts)
        settingsRows[citizenId] = settingsRows[citizenId] or { citizenid = citizenId, feed_cleared_at = 0 }
        settingsRows[citizenId].alerts = alerts
        return true
    end,
    setClearedAt = function(citizenId, clearedAt)
        settingsRows[citizenId] = settingsRows[citizenId] or { citizenid = citizenId }
        settingsRows[citizenId].feed_cleared_at = clearedAt
        return true
    end,
}

N.Repositories.Operation = {
    insert = function(op)
        db.operations[op.id] = op
        return true
    end,
    setStatus = function(id, status, committedAt, payload)
        local op = db.operations[id]
        if not op then return 0 end
        op.status = status
        op.committedAt = committedAt
        op.payload = payload or op.payload
        return 1
    end,
    recent = function() return {} end,
    feed = function(organizationId, limit, cursor, since)
        local rows = {}
        for _, op in pairs(db.operations) do
            local committed = op.status == C.OperationStatus.COMMITTED
                or op.status == C.OperationStatus.PAID
            local afterClear = not since or since == 0 or op.createdAt > since
            if op.organizationId == organizationId and committed and afterClear then
                rows[#rows + 1] = {
                    operation_id = op.id,
                    operation_type = op.type,
                    outpost_id = op.outpostId,
                    dealer_id = op.dealerId,
                    item_name = op.item,
                    quantity = op.quantity,
                    gross_amount = op.gross,
                    net_amount = op.net,
                    payload = op.payload,
                    created_at = op.createdAt,
                }
            end
        end
        table.sort(rows, function(a, b)
            if a.created_at == b.created_at then return a.operation_id > b.operation_id end
            return a.created_at > b.created_at
        end)
        local page = {}
        for index = 1, #rows do
            local row = rows[index]
            local after = cursor == nil
                or row.created_at < cursor.at
                or (row.created_at == cursor.at and row.operation_id < cursor.id)
            if after then
                page[#page + 1] = row
                if #page > limit then break end
            end
        end
        return page
    end,
    findByRequest = function(citizenId, requestId)
        for _, op in pairs(db.operations) do
            if op.citizenId == citizenId and op.requestId == requestId then return op end
        end
        return nil
    end,
    prune = function() return 0 end,
}

-- Estado e serviços stubados ------------------------------------------------------------------

dofile('server/state.lua')
dofile('server/sessions.lua')

N.Entities = {
    spawned = {},
    dead = {},
    spawnDealer = function(_, dealer)
        N.Entities.spawned[dealer.id] = true
        N.Entities.dead[dealer.id] = nil
        N.Entities.corpses[dealer.id] = nil
    end,
    despawnDealer = function(dealerId)
        N.Entities.spawned[dealerId] = nil
        N.Entities.dead[dealerId] = nil
        N.Entities.corpses[dealerId] = nil
    end,
    corpses = {},
    isAlive = function(dealerId)
        return N.Entities.spawned[dealerId] == true and not N.Entities.dead[dealerId]
    end,
    -- Leitura do servidor, e não a alegação de quem avisou: só devolve verdadeiro para ped que
    -- está mesmo caído.
    readDown = function(dealerId)
        return N.Entities.spawned[dealerId] == true and N.Entities.dead[dealerId] == true
    end,
    markCorpse = function(dealerId) N.Entities.corpses[dealerId] = true end,
    deadDealers = function()
        local list = {}
        for dealerId in pairs(N.Entities.dead) do list[#list + 1] = dealerId end
        table.sort(list)
        return list
    end,
    despawnOutpost = function() end,
    despawnAll = function() end,
    setState = function() end,
    resolve = function(dealerId)
        if not N.Entities.spawned[dealerId] then return nil end
        return dealerId * 100, dealerId * 1000
    end,
    validate = function(dealerId, netId)
        if netId ~= dealerId * 1000 then return nil end
        return dealerId * 100
    end,
    syncAll = function() end,
}

N.Services = {}
N.Services.Notification = {
    sales = 0,
    dispatches = 0,
    notifyOrganization = function() end,
    queueSale = function(_, _, _) N.Services.Notification.sales = N.Services.Notification.sales + 1 end,
    flush = function() end,
    clear = function() end,
    maybeDispatch = function()
        N.Services.Notification.dispatches = N.Services.Notification.dispatches + 1
        return true
    end,
    broadcastPublicSnapshot = function() end,
    sendPublicSnapshot = function() end,
    refreshPanels = function() end,
    checkStockAlerts = function() end,
}

local uuidCounter = 0
N.Services.Rotation = {
    uuid = function()
        uuidCounter = uuidCounter + 1
        return ('00000000-0000-4000-8000-%012d'):format(uuidCounter)
    end,
}

-- Providers falsos -----------------------------------------------------------------------------

local players = {}
local inventoryFull = false
-- Presença da gang dona. É o que liga e desliga a proteção de posto sem ninguém online.
local ownerOnline = true
-- Chamados enviados à polícia, para o teste conferir quem acorda quem.
local dispatches = {}

N.Integration = {
    getCharacter = function(source)
        return players[source] and players[source].character or nil
    end,
    getOrganization = function(source)
        return players[source] and players[source].organization or nil
    end,
    organizationFrom = function(character)
        return character and character.organization or nil
    end,
    addItem = function(source, item, amount)
        if inventoryFull then return false, 'inventory_full' end
        local inventory = players[source].inventory
        inventory[item] = (inventory[item] or 0) + amount
        return true
    end,
    removeItem = function(source, item, amount)
        local inventory = players[source].inventory
        if (inventory[item] or 0) < amount then return false, 'not_enough_items' end
        inventory[item] = inventory[item] - amount
        return true
    end,
    getItemCount = function(source, item) return players[source].inventory[item] or 0 end,
    canCarryItem = function() return not inventoryFull end,
    addMoney = function(source, _, amount)
        players[source].cash = players[source].cash + amount
        return true
    end,
    removeMoney = function(source, _, amount)
        if players[source].cash < amount then return false end
        players[source].cash = players[source].cash - amount
        return true
    end,
    notify = function() end,
    sendPhoneNotification = function() return true end,
    sendDispatch = function(payload) dispatches[#dispatches + 1] = payload return true end,
    onlinePlayerCount = function() return 10 end,
    onDutyPoliceCount = function() return 3 end,
    hasOnlineMember = function() return ownerOnline end,
    onlineMembers = function() return { 1 } end,
    onlineMembersWithGrade = function() return { 1 } end,
    refreshPlayer = function() end,
    removePlayer = function() end,
    rebuildMembers = function() end,
}

dofile('server/security.lua')
dofile('server/services/claim_service.lua')
dofile('server/services/dealer_service.lua')
dofile('server/services/stock_service.lua')
dofile('server/services/sale_service.lua')
dofile('server/services/holdup_service.lua')
dofile('server/services/robbery_service.lua')
dofile('server/services/settings_service.lua')
dofile('server/services/feed_service.lua')

local Services = N.Services
local Security = N.Security
local State = N.State

-- Cenário -----------------------------------------------------------------------------------------

local OUTPOST = 'docks'
local computer = sharedConfig.outposts[OUTPOST].computer

local function addPlayer(source, citizenId, organizationId, grade)
    local organization = organizationId
        and { id = organizationId, label = organizationId, grade = grade }
        or nil
    players[source] = {
        character = {
            citizenId = citizenId,
            status = { dead = false, handcuffed = false, jailTime = 0 },
            organization = organization,
        },
        organization = organization,
        inventory = {},
        cash = 100000,
    }
    pedCoords[source * 10] = vector3(computer.x, computer.y, computer.z)
end

local function actorFor(source)
    local actor = assert(Security.resolveActor(source))
    return actor
end

local function resetRateLimits()
    gameTimer = gameTimer + 60000
end

db.outposts[OUTPOST] = {
    id = OUTPOST,
    status = C.OutpostStatus.CONTROLLED,
    operation_type = C.OperationType.DRUG,
    rotation_id = 1,
    owner_organization_id = 'ballas',
    kingpin_citizenid = 'LEADER01',
    claimed_at = os.time(),
    expires_at = os.time() + 86400,
    purse_available = 0,
    purse_pending = 0,
    version = 0,
}
N.Repositories.Stock.ensureProducts(OUTPOST, State.productIds)
State.load()

addPlayer(1, 'LEADER01', 'ballas', 4)
addPlayer(2, 'MEMBER02', 'ballas', 1)
addPlayer(3, 'RIVAL003', 'vagos', 4)

local leader = actorFor(1)
local member = actorFor(2)
local rival = actorFor(3)

-- Permissões ---------------------------------------------------------------------------------------

T.equal(Security.permissionMap(leader).collect, true, 'leader can collect')
T.equal(Security.permissionMap(member).collect, false, 'member cannot collect')
T.equal(Security.permissionMap(member).stock, true, 'member can stock')
T.equal(Security.isOwner(rival, db.outposts[OUTPOST]), false, 'rival is not the owner')

-- Tomada -------------------------------------------------------------------------------------------

-- O cenário começa controlado; volta para disponível só para exercitar o claim.
db.outposts[OUTPOST].status = C.OutpostStatus.AVAILABLE
db.outposts[OUTPOST].owner_organization_id = nil
db.outposts[OUTPOST].expires_at = nil
State.reload(OUTPOST)

resetRateLimits()
local memberClaim = Services.Claim.start(member, OUTPOST)
T.equal(memberClaim.ok, false, 'member cannot claim')
T.equal(memberClaim.code, 'insufficient_grade', 'member claim code')
T.equal(db.outposts[OUTPOST].status, C.OutpostStatus.AVAILABLE, 'refused claim leaves the state alone')

resetRateLimits()
local claim = Services.Claim.start(leader, OUTPOST)
T.equal(claim.ok, true, 'leader starts the claim')
T.equal(db.outposts[OUTPOST].status, C.OutpostStatus.CLAIMING, 'claim locks the outpost')

resetRateLimits()
local rivalClaim = Services.Claim.start(rival, OUTPOST)
T.equal(rivalClaim.ok, false, 'a second organization cannot claim at the same time')
T.equal(rivalClaim.code, 'claim_in_progress', 'concurrent claim code')

resetRateLimits()
local instant = Services.Claim.complete(leader, claim.data.sessionId)
T.equal(instant.ok, false, 'completing instantly is refused')
T.equal(db.outposts[OUTPOST].status, C.OutpostStatus.AVAILABLE, 'the cheated claim released the lock')

resetRateLimits()
local second = Services.Claim.start(leader, OUTPOST)
T.equal(second.ok, true, 'leader starts again')
gameTimer = gameTimer + serverConfig.claim.durationMs + 10

local completed = Services.Claim.complete(leader, second.data.sessionId)
T.equal(completed.ok, true, 'claim completes after the full duration')
T.equal(db.outposts[OUTPOST].status, C.OutpostStatus.CONTROLLED, 'outpost is controlled')
T.equal(db.outposts[OUTPOST].owner_organization_id, 'ballas', 'owner recorded')
T.equal(db.outposts[OUTPOST].kingpin_citizenid, 'LEADER01', 'kingpin recorded')
T.truthy(db.organizations.ballas.claim_cooldown_until > os.time(), 'organization is on cooldown')

local claimRoster = db.outposts[OUTPOST].dealer_roster
T.truthy(claimRoster, 'claim draws and persists the dealer identity roster')
local rosterNames, rosterModels = {}, {}
for index = 1, #sharedConfig.dealerProfiles do
    local profileKey = sharedConfig.dealerProfiles[index].key
    local identity = claimRoster[profileKey]
    T.truthy(identity, 'claim draws an identity for profile ' .. profileKey)
    T.equal(rosterNames[identity.name], nil, 'claim roster names do not repeat')
    T.equal(rosterModels[identity.model], nil, 'claim roster peds do not repeat')
    rosterNames[identity.name] = true
    rosterModels[identity.model] = true
end

local claimOperation
for _, op in pairs(db.operations) do
    if op.type == C.OperationKind.CLAIM then claimOperation = op end
end
T.truthy(claimOperation, 'claim was written to the ledger')

resetRateLimits()
local again = Services.Claim.start(leader, OUTPOST)
T.equal(again.ok, false, 'a controlled outpost cannot be claimed')
T.equal(again.code, 'invalid_state', 'controlled claim code')

-- Contratação -------------------------------------------------------------------------------------

resetRateLimits()
local hire = Services.Dealer.hire(leader, OUTPOST, 'smokey', 'req-hire-0001')
T.equal(hire.ok, true, 'leader hires a dealer')
local dealerId = hire.data.dealerId
T.equal(N.Entities.spawned[dealerId], true, 'dealer entity spawned')
T.equal(players[1].cash, 100000 - serverConfig.dealerHirePrice.smokey, 'hire price charged')

resetRateLimits()
local duplicate = Services.Dealer.hire(leader, OUTPOST, 'smokey', 'req-hire-0002')
T.equal(duplicate.ok, false, 'same profile cannot be hired twice')
T.equal(duplicate.code, 'already_hired', 'duplicate hire code')

resetRateLimits()
local replay = Services.Dealer.hire(leader, OUTPOST, 'ghost', 'req-hire-0001')
T.equal(replay.ok, false, 'replayed request id is refused')
T.equal(replay.code, 'already_processed', 'replayed hire code')

resetRateLimits()
local unauthorized = Services.Dealer.hire(member, OUTPOST, 'ghost', 'req-hire-0003')
T.equal(unauthorized.ok, false, 'member cannot hire')
T.equal(unauthorized.code, 'insufficient_grade', 'member hire code')

resetRateLimits()
local foreign = Services.Dealer.hire(rival, OUTPOST, 'ghost', 'req-hire-0004')
T.equal(foreign.ok, false, 'rival cannot hire on a foreign outpost')
T.equal(foreign.code, 'not_owner', 'rival hire code')

for index = 1, serverConfig.limits.maxDealersPerOutpost - 1 do
    resetRateLimits()
    local extra = Services.Dealer.hire(leader, OUTPOST, ({ 'ghost', 'trigger', 'mule' })[index], 'req-fill-000' .. index)
    T.equal(extra.ok, true, 'filling the dealer roster ' .. index)
end
resetRateLimits()
local overflow = Services.Dealer.hire(leader, OUTPOST, 'silk', 'req-hire-0009')
T.equal(overflow.ok, false, 'dealer limit enforced')
T.equal(overflow.code, 'dealer_limit', 'dealer limit code')
T.equal(State.dealerCount(OUTPOST), serverConfig.limits.maxDealersPerOutpost, 'roster is full')

-- Nome e ped vêm do elenco sorteado na tomada e não mudam durante este domínio.
local identities = sharedConfig.dealerIdentities
local nameSet, modelSet = {}, {}
for index = 1, #identities.names do nameSet[identities.names[index]] = true end
for index = 1, #identities.models do modelSet[identities.models[index]] = true end

local usedNames, usedModels = {}, {}
for _, dealer in pairs(State.get(OUTPOST).dealers) do
    T.equal(nameSet[dealer.display_name], true, 'the drawn name comes from the list')
    T.equal(modelSet[dealer.ped_model], true, 'the drawn ped comes from the list')
    T.equal(dealer.display_name, claimRoster[dealer.profile_key].name,
        'hiring uses the name reserved when the outpost was claimed')
    T.equal(dealer.ped_model, claimRoster[dealer.profile_key].model,
        'hiring uses the ped reserved when the outpost was claimed')
    T.equal(usedNames[dealer.display_name], nil, 'no two runners share a name at one outpost')
    T.equal(usedModels[dealer.ped_model], nil, 'no two runners share a ped at one outpost')
    usedNames[dealer.display_name] = true
    usedModels[dealer.ped_model] = true

    T.equal(State.dealerName(dealer), dealer.display_name, 'the drawn name is what gets shown')
    T.equal(State.dealerModel(dealer), dealer.ped_model, 'the drawn ped is what gets spawned')
end

-- Linha antiga, anterior ao sorteio: o arquétipo volta a valer em vez de ficar sem nome.
T.equal(State.dealerName({ profile_key = 'smokey' }), 'Smokey', 'a runner with no drawn name falls back')
T.equal(State.dealerModel({ profile_key = 'smokey' }), 'g_m_y_famdnf_01', 'a runner with no drawn ped falls back')

-- Depósito -----------------------------------------------------------------------------------------

players[2].inventory.weed_brick = 50

resetRateLimits()
local deposit = Services.Stock.deposit(member, OUTPOST, 'weed_brick', 20, 'req-dep-00001')
T.equal(deposit.ok, true, 'member deposits stock')
T.equal(players[2].inventory.weed_brick, 30, 'exactly the deposited items were removed')
T.equal(db.stock[OUTPOST].weed_brick, 20, 'stock increased by the deposit')

resetRateLimits()
local depositReplay = Services.Stock.deposit(member, OUTPOST, 'weed_brick', 20, 'req-dep-00001')
T.equal(depositReplay.ok, false, 'replayed deposit is refused')
T.equal(depositReplay.code, 'already_processed', 'replayed deposit code')
T.equal(players[2].inventory.weed_brick, 30, 'replay did not remove items again')

resetRateLimits()
local tooMuch = Services.Stock.deposit(member, OUTPOST, 'weed_brick', 500, 'req-dep-00002')
T.equal(tooMuch.ok, false, 'oversized deposit refused')
T.equal(tooMuch.code, 'amount_too_large', 'oversized deposit code')

resetRateLimits()
local missing = Services.Stock.deposit(member, OUTPOST, 'meth', 5, 'req-dep-00003')
T.equal(missing.ok, false, 'cannot deposit items the player lacks')
T.equal(missing.code, 'not_enough_items', 'missing item code')

-- Compensação: o SQL recusa depois do item já ter saído do inventário.
local realDeposit = N.Repositories.Stock.deposit
N.Repositories.Stock.deposit = function() return false end
resetRateLimits()
local compensated = Services.Stock.deposit(member, OUTPOST, 'weed_brick', 10, 'req-dep-00004')
N.Repositories.Stock.deposit = realDeposit
T.equal(compensated.ok, false, 'failed deposit reports an error')
T.equal(compensated.code, 'stock_full', 'failed deposit code')
T.equal(players[2].inventory.weed_brick, 30, 'inventory compensated after the failure')
T.equal(db.stock[OUTPOST].weed_brick, 20, 'stock unchanged after the failure')

-- Venda passiva ---------------------------------------------------------------------------------------

local dealer = State.dealer(dealerId)
local stockBefore = db.stock[OUTPOST].weed_brick
local sold, reason = Services.Sale.process(dealer)
T.equal(sold, true, 'dealer sells from the stock: ' .. tostring(reason))
T.truthy(db.stock[OUTPOST].weed_brick < stockBefore, 'stock decreased after the sale')
T.truthy(db.stock[OUTPOST].weed_brick >= 0, 'stock never goes negative')
T.truthy(db.outposts[OUTPOST].purse_available > 0, 'purse received the net amount')

local saleOperation
for _, op in pairs(db.operations) do
    if op.type == C.OperationKind.SALE then saleOperation = op end
end
T.truthy(saleOperation, 'sale was written to the ledger')
T.equal(saleOperation.net + saleOperation.payload.commission, saleOperation.gross, 'commission closes the gross')
T.truthy(saleOperation.net < saleOperation.gross, 'the dealer keeps a commission')
T.equal(N.Services.Notification.sales, 1, 'the sale was queued for notification')

-- Estoque zerado não gera dinheiro.
db.stock[OUTPOST].weed_brick = 0
State.reload(OUTPOST)
local purseBefore = db.outposts[OUTPOST].purse_available
local emptySold, emptyReason = Services.Sale.process(State.dealer(dealerId))
T.equal(emptySold, false, 'no stock means no sale')
T.equal(emptyReason, 'no_stock', 'empty stock reason')
T.equal(db.outposts[OUTPOST].purse_available, purseBefore, 'purse unchanged without stock')

-- Owner expirado não vende.
db.stock[OUTPOST].weed_brick = 50
db.outposts[OUTPOST].expires_at = os.time() - 10
State.reload(OUTPOST)
local expiredSold, expiredReason = Services.Sale.process(State.dealer(dealerId))
T.equal(expiredSold, false, 'expired control stops sales')
T.equal(expiredReason, 'expired', 'expired reason')
db.outposts[OUTPOST].expires_at = os.time() + 86400
State.reload(OUTPOST)

-- Coleta ------------------------------------------------------------------------------------------------

db.outposts[OUTPOST].purse_available = 5000
State.reload(OUTPOST)

resetRateLimits()
local memberCollect = Services.Stock.collect(member, OUTPOST, 'req-col-00001')
T.equal(memberCollect.ok, false, 'member cannot collect')
T.equal(memberCollect.code, 'insufficient_grade', 'member collect code')

resetRateLimits()
local collect = Services.Stock.collect(leader, OUTPOST, 'req-col-00002')
T.equal(collect.ok, true, 'leader collects the purse')
T.equal(collect.data.amount, 5000, 'collected the full purse')
T.equal(players[1].inventory.black_money, 5000, 'payout delivered as dirty money')
T.equal(db.outposts[OUTPOST].purse_available, 0, 'purse is empty after the collection')
T.equal(db.outposts[OUTPOST].purse_pending, 0, 'nothing is left pending')

resetRateLimits()
local collectReplay = Services.Stock.collect(leader, OUTPOST, 'req-col-00002')
T.equal(collectReplay.ok, false, 'replayed collection is refused')
T.equal(collectReplay.code, 'already_processed', 'replayed collection code')
T.equal(players[1].inventory.black_money, 5000, 'replay did not pay twice')

resetRateLimits()
local emptyCollect = Services.Stock.collect(leader, OUTPOST, 'req-col-00003')
T.equal(emptyCollect.ok, false, 'empty purse refuses collection')
T.equal(emptyCollect.code, 'empty_purse', 'empty purse code')

-- Falha de entrega restaura a carteira.
db.outposts[OUTPOST].purse_available = 900
State.reload(OUTPOST)
inventoryFull = true
resetRateLimits()
local blocked = Services.Stock.collect(leader, OUTPOST, 'req-col-00004')
inventoryFull = false
T.equal(blocked.ok, false, 'full inventory blocks the collection')
T.equal(db.outposts[OUTPOST].purse_available, 900, 'purse restored after the failure')
T.equal(db.outposts[OUTPOST].purse_pending, 0, 'no pending amount left behind')

-- Roubo ---------------------------------------------------------------------------------------------------

db.stock[OUTPOST].weed_brick = 100
State.reload(OUTPOST)
local netId = dealerId * 1000

resetRateLimits()
local ownerRobbery = Services.Robbery.start(leader, dealerId, netId)
T.equal(ownerRobbery.ok, false, 'owner cannot rob their own dealer')
T.equal(ownerRobbery.code, 'own_outpost', 'owner robbery code')

resetRateLimits()
local badEntity = Services.Robbery.start(rival, dealerId, 999999)
T.equal(badEntity.ok, false, 'a foreign net id is refused')
T.equal(badEntity.code, 'invalid_entity', 'foreign net id code')

pedCoords[3 * 10] = vector3(computer.x, computer.y, computer.z)

---@param targetDealerId integer
---@return table corner
local function cornerOf(targetDealerId)
    local dealer = assert(State.dealer(targetDealerId), 'dealer sem estado')
    return sharedConfig.outposts[OUTPOST].dealerCorners[dealer.corner_index]
end

-- Onde cada ped aparece para o servidor. `nil` significa parado na própria esquina de spawn,
-- que é o que uma sincronização quebrada devolveria.
local dealerReading = {}

local function readsAt(targetDealerId, coords) dealerReading[targetDealerId] = coords end

local function standAt(actor, coords)
    pedCoords[actor.source * 10] = vector3(coords.x, coords.y, coords.z)
end

local function standAtCorner(actor, targetDealerId)
    standAt(actor, cornerOf(targetDealerId))
end

standAtCorner(rival, dealerId)

GetEntityCoords = function(entity)
    if type(entity) == 'number' and entity >= 100 and entity % 100 == 0 and State.dealer(entity // 100) then
        local id = entity // 100
        if dealerReading[id] then return dealerReading[id] end
        local corner = cornerOf(id)
        return vector3(corner.x, corner.y, corner.z)
    end
    return pedCoords[entity] or vector3(0.0, 0.0, 0.0)
end

-- Sem rendição não há revista, mesmo com tudo o mais válido.
resetRateLimits()
local unsurrendered = Services.Robbery.start(rival, dealerId, netId)
T.equal(unsurrendered.ok, false, 'searching without a surrender is refused')
T.equal(unsurrendered.code, 'not_surrendered', 'not surrendered code')

-- Posição do corredor ------------------------------------------------------------------------
-- Enquanto toda leitura cai em cima da esquina de spawn, o servidor não tem prova de que
-- enxerga o ped. Aí a medida é contra a esquina e paga o raio de caminhada como folga.
T.equal(Services.Dealer.positionSyncProven(), false, 'the sync starts unproven')

-- O cooldown de abordagem tem teste próprio; aqui ele só atrapalharia a bateria de distâncias.
local holdupCooldown = serverConfig.holdup.cooldownSeconds
serverConfig.holdup.cooldownSeconds = 0

local corner = cornerOf(dealerId)
local slack = sharedConfig.dealerWander.radius

standAt(rival, { x = corner.x + 10.0, y = corner.y, z = corner.z })
resetRateLimits()
local loose = Services.Holdup.start(rival, dealerId, netId)
T.equal(loose.ok, true, 'without a trusted position the corner reach covers the wander radius')
Services.Holdup.release(dealerId)

standAt(rival, { x = corner.x + slack + 20.0, y = corner.y, z = corner.z })
resetRateLimits()
local beyondSlack = Services.Holdup.start(rival, dealerId, netId)
T.equal(beyondSlack.ok, false, 'even the loose reach stops at the outpost area')
T.equal(beyondSlack.code, 'too_far', 'out of the loose reach code')

-- Agora o ped aparece longe da esquina. Ninguém o moveu no servidor, então esse deslocamento
-- só pode ter vindo da sincronização: a partir daqui a leitura vale como posição real.
local wandered = { x = corner.x + 30.0, y = corner.y, z = corner.z }
readsAt(dealerId, vector3(wandered.x, wandered.y, wandered.z))

standAtCorner(rival, dealerId)
resetRateLimits()
local staleCorner = Services.Holdup.start(rival, dealerId, netId)
T.equal(staleCorner.ok, false, 'a trusted position is measured against the ped, not the corner')
T.equal(staleCorner.code, 'too_far', 'standing at an empty corner is out of reach')
T.equal(Services.Dealer.positionSyncProven(), true, 'a moved reading proves the sync works')
T.equal(Services.Dealer.positionSyncProven(dealerId), true, 'the proof belongs to the runner that moved')

-- A prova é de um corredor só. Um vizinho cuja leitura ainda é a esquina de spawn continua no
-- alcance frouxo: tratá-lo como confiável mediria 2,5 m contra um ponto que pode estar a
-- dezenas de metros do ped de verdade, e recusaria quem está encostado nele.
T.equal(Services.Dealer.positionSyncProven(3), false, 'one runner proving sync does not vouch for another')
local neighbourCoords, neighbourTrusted =
    Services.Dealer.observedPosition(State.dealer(3), N.Entities.validate(3, 3 * 1000))
T.truthy(neighbourCoords, 'the neighbour still reports a position')
T.equal(neighbourTrusted, false, 'an unmoved neighbour reading is not trusted')

-- Reporte do dono de rede. É o que resolve o problema de raiz: o servidor deixa de adivinhar
-- e passa a saber onde o ped está, desde que a alegação caiba na área do posto.
local reportedSpot = vector3(corner.x + 10.0, corner.y, corner.z)
T.equal(Services.Dealer.reportPosition(dealerId, reportedSpot), true, 'a report inside the outpost is accepted')

local afterReport, reportTrusted =
    Services.Dealer.observedPosition(State.dealer(dealerId), N.Entities.validate(dealerId, netId))
T.equal(#(afterReport - reportedSpot), 0, 'the reported position wins over the server read')
T.equal(reportTrusted, true, 'a reported position needs no trust heuristic')

-- Salto impossível é mentira ou bug, e não substitui o que já havia.
T.equal(Services.Dealer.reportPosition(dealerId, vector3(corner.x + 400.0, corner.y, corner.z)), false,
    'a teleport-sized jump is refused')
local afterBadReport = Services.Dealer.observedPosition(State.dealer(dealerId), N.Entities.validate(dealerId, netId))
T.equal(#(afterBadReport - reportedSpot), 0, 'the refused report did not overwrite the good one')

-- Fuga: o corredor assustado sai da área dele e a âncora acompanha, um passo plausível por vez.
-- Prender a âncora à esquina tornaria impossível assaltar exatamente quem correu.
local fleeing = reportedSpot
for _ = 1, 12 do
    gameTimer = gameTimer + 1000
    fleeing = vector3(fleeing.x + 10.0, fleeing.y, fleeing.z)
    T.equal(Services.Dealer.reportPosition(dealerId, fleeing), true, 'a fleeing runner keeps being tracked')
end
T.truthy(#(fleeing - corner) > sharedConfig.dealerWander.radius * 4,
    'the runner ended far outside his own wander area')

local afterFlight = Services.Dealer.observedPosition(State.dealer(dealerId), N.Entities.validate(dealerId, netId))
T.equal(#(afterFlight - fleeing), 0, 'the anchor followed the runner out of the outpost')

-- Mas o passo continua limitado: ninguém arrasta a âncora para o próprio colo de uma vez.
gameTimer = gameTimer + 1000
T.equal(Services.Dealer.reportPosition(dealerId, vector3(fleeing.x + 300.0, fleeing.y, fleeing.z)), false,
    'one second does not buy three hundred metres')

Services.Dealer.forgetReportedPosition(dealerId)
T.equal(Services.Dealer.reportPosition(dealerId, reportedSpot), true, 'the anchor reseeds at the corner')

-- Reporte vencido: o servidor volta a se virar com a leitura própria.
local ttl = serverConfig.validation.reportedPositionTtlSeconds
serverConfig.validation.reportedPositionTtlSeconds = -1
local afterExpiry = Services.Dealer.observedPosition(State.dealer(dealerId), N.Entities.validate(dealerId, netId))
T.equal(#(afterExpiry - vector3(wandered.x, wandered.y, wandered.z)), 0,
    'an expired report falls back to the server read')
serverConfig.validation.reportedPositionTtlSeconds = ttl
Services.Dealer.forgetReportedPosition(dealerId)

standAt(rival, wandered)

-- Com a chance em 0 ele sempre se rende, então o teste é determinístico.
serverConfig.holdup.reactionChance = 0
resetRateLimits()
local holdup = Services.Holdup.start(rival, dealerId, netId)
T.equal(holdup.ok, true, 'rival holds the runner at gunpoint')
T.equal(holdup.data.reacted, false, 'zero chance always surrenders')
T.equal(Services.Holdup.isSurrendered(dealerId), true, 'runner is surrendered')

local anchor = Services.Holdup.surrenderAnchor(dealerId)
T.truthy(anchor, 'the surrender recorded a position')
T.equal(anchor.trusted, true, 'the recorded position is the one the server measured')
T.equal(#(anchor.coords - vector3(wandered.x, wandered.y, wandered.z)), 0,
    'the recorded position is where the runner put his hands up')

-- O ped some para o outro lado do posto. A revista continua medindo contra o ponto gravado,
-- senão bastaria arrastar o alvo para perto para roubar de longe.
readsAt(dealerId, vector3(corner.x + 120.0, corner.y, corner.z))
resetRateLimits()
local frozen = Services.Robbery.start(rival, dealerId, netId)
T.equal(frozen.ok, true, 'the search measures against the recorded position, not a fresh read')
Services.Robbery.cancel(rival, frozen.data.sessionId)

-- E o alcance gravado é o apertado: afastar-se poucos metros já barra.
standAt(rival, { x = wandered.x + 10.0, y = wandered.y, z = wandered.z })
resetRateLimits()
local walkedOff = Services.Robbery.start(rival, dealerId, netId)
T.equal(walkedOff.ok, false, 'walking away from the recorded position refuses the search')
T.equal(walkedOff.code, 'too_far', 'walked away code')
standAt(rival, wandered)

resetRateLimits()
local repeated = Services.Holdup.start(rival, dealerId, netId)
T.equal(repeated.ok, false, 'a runner already held up cannot be held again')
T.equal(repeated.code, 'holdup_in_progress', 'holdup in progress code')

-- Sob abordagem ele para de vender.
T.equal(Services.Sale.process(State.dealer(dealerId)), false, 'a runner under holdup does not sell')

resetRateLimits()
local robbery = Services.Robbery.start(rival, dealerId, netId)
T.equal(robbery.ok, true, 'rival starts the robbery')

local session = N.Sessions.get(robbery.data.sessionId)
T.truthy(session, 'robbery session exists')

resetRateLimits()
local tooFast = Services.Robbery.complete(rival, robbery.data.sessionId)
T.equal(tooFast.ok, false, 'completing instantly is refused')
T.equal(N.Sessions.get(robbery.data.sessionId), nil, 'the cheated session was aborted')

resetRateLimits()
local second = Services.Robbery.start(rival, dealerId, netId)
T.equal(second.ok, true, 'rival can start again')
gameTimer = gameTimer + serverConfig.robbery.durationMs + 10

local purseTarget = 4000
db.outposts[OUTPOST].purse_available = purseTarget
State.reload(OUTPOST)

-- Sem resetRateLimits: avançar o relógio já liberou o limite e a sessão ainda é válida.
local stolen = Services.Robbery.complete(rival, second.data.sessionId)
T.equal(stolen.ok, true, 'robbery completes after the full duration')
T.truthy(stolen.data.purse > 0, 'the rival took dirty money')
T.truthy(db.outposts[OUTPOST].purse_available < purseTarget, 'the purse was debited')
T.truthy(db.outposts[OUTPOST].purse_available > 0, 'the whole purse was not exposed')
T.equal(players[3].inventory.black_money, stolen.data.purse, 'loot delivered to the robber')
T.equal(State.dealer(dealerId).status, C.DealerStatus.RECOVERING, 'dealer is recovering')

local robberyOperation
for _, op in pairs(db.operations) do
    if op.type == C.OperationKind.ROBBERY then robberyOperation = op end
end
T.truthy(robberyOperation, 'robbery was written to the ledger')
T.equal(robberyOperation.status, C.OperationStatus.PAID, 'robbery ledger settled')

resetRateLimits()
local onCooldown = Services.Robbery.start(rival, dealerId, netId)
T.equal(onCooldown.ok, false, 'a recovering dealer cannot be robbed again')
T.equal(onCooldown.code, 'dealer_unavailable', 'recovering dealer code')

-- Dealer em recuperação não vende.
local recoveringSold, recoveringReason = Services.Sale.process(State.dealer(dealerId))
T.equal(recoveringSold, false, 'recovering dealer does not sell')

-- Reação armada: nada de revista.

Services.Holdup.release(3)
readsAt(dealerId, nil)
serverConfig.holdup.cooldownSeconds = holdupCooldown
serverConfig.holdup.reactionChance = 100
N.Sessions.abortForSource(rival.source, 'reset')
standAtCorner(rival, 3)
resetRateLimits()
local hostile = Services.Holdup.start(rival, 3, 3 * 1000)
T.equal(hostile.ok, true, 'holding up another runner works')
T.equal(hostile.data.reacted, true, 'full chance always reacts')
T.equal(Services.Holdup.isSurrendered(3), false, 'a reacting runner is not surrendered')

resetRateLimits()
local refused = Services.Robbery.start(rival, 3, 3 * 1000)
T.equal(refused.ok, false, 'a reacting runner cannot be searched')
T.equal(refused.code, 'not_surrendered', 'reacting runner refuses the search')
-- Abalado: encerrada a abordagem, o corredor não volta a caminhar enquanto o cooldown corre.
-- Ele fica agachado com medo, que é a única pista visível de que apontar a arma de novo agora não
-- vai dar em nada. É encenação: quem recusa a abordagem seguinte continua sendo o cooldown.
local published = {}
local realSetState = N.Entities.setState
N.Entities.setState = function(id, state) published[id] = state end

Services.Holdup.release(3)
T.equal(published[3], C.HoldupState.SHAKEN, 'a released runner stays shaken while the cooldown runs')

-- O cooldown vencido é que o levanta. Zerá-lo pela porta administrativa tem o mesmo efeito, e
-- sem isso ele ficaria agachado até o próximo restart.
T.truthy(Services.Holdup.clearCooldowns() > 0, 'the holdup cooldown was in force')
T.equal(published[3], C.DealerStatus.DEPLOYED, 'clearing the cooldown puts him back on his feet')

-- Sem cooldown a abordagem termina direto no estado real, sem passar pelo medo.
serverConfig.holdup.cooldownSeconds = 0
resetRateLimits()
T.equal(Services.Holdup.start(rival, 3, 3 * 1000).ok, true, 'a second holdup works without cooldown')
Services.Holdup.release(3)
T.equal(published[3], C.DealerStatus.DEPLOYED, 'without a cooldown there is nothing to be shaken about')
serverConfig.holdup.cooldownSeconds = holdupCooldown

-- Quem já reagiu responde "já foi abordado", e não "está sendo abordado": quem está levando tiro
-- dele não precisa ouvir que a abordagem está em curso.
resetRateLimits()
T.equal(Services.Holdup.start(rival, 3, 3 * 1000).ok, true, 'a holdup starts again after the reset')
resetRateLimits()
T.equal(Services.Holdup.start(rival, 3, 3 * 1000).code, 'holdup_done',
    'a runner that already reacted answers "already held up"')

-- Ped recriado não herda nada do anterior. Uma abordagem em curso que sobrevive ao ped recusaria
-- todas as seguintes até vencer sozinha, e era ela que fazia o "já está sendo abordado" aparecer
-- sem ninguém abordando. O cooldown de roubo não passa por aqui: é do corredor, não do ped.
Services.Holdup.resetDealer(3)
resetRateLimits()
T.equal(Services.Holdup.start(rival, 3, 3 * 1000).ok, true,
    'a recreated ped carries no holdup and no holdup cooldown')
Services.Holdup.resetDealer(3)

-- Gang dona offline --------------------------------------------------------------------------
-- Sem ninguém da organização dona online o corredor deixa de ser alvo, e a recusa é a mesma para
-- abordagem e assalto porque as duas passam por `rivalTarget`. A venda passiva já para sozinha
-- nesse período: sem esta trava, a madrugada seria ganho de graça de um lado e perda pura do
-- outro, contra quem não tem ninguém para reagir.
ownerOnline = false

resetRateLimits()
local offlineHoldup = Services.Holdup.start(rival, 3, 3 * 1000)
T.equal(offlineHoldup.ok, false, 'a runner of an offline crew cannot be held up')
T.equal(offlineHoldup.code, 'owner_offline', 'offline crew holdup code')

-- O assalto para no mesmo lugar, e antes do `not_surrendered` que este mesmo alvo devolvia com a
-- gang online: a trava precede a revista, não depende dela.
resetRateLimits()
local offlineRobbery = Services.Robbery.start(rival, 3, 3 * 1000)
T.equal(offlineRobbery.ok, false, 'a runner of an offline crew cannot be robbed')
T.equal(offlineRobbery.code, 'owner_offline', 'offline crew robbery code')

-- É a proteção que recusa, e não outra coisa em cima do mesmo alvo: desligada, com a gang ainda
-- offline, a abordagem volta a passar.
serverConfig.ownerOffline.protectDealers = false
resetRateLimits()
T.equal(Services.Holdup.start(rival, 3, 3 * 1000).ok, true,
    'with the protection off the same target is reachable again')
Services.Holdup.release(3)
Services.Holdup.resetDealer(3)
serverConfig.ownerOffline.protectDealers = true

-- Um membro voltando devolve o posto à disputa no mesmo instante.
ownerOnline = true
resetRateLimits()
T.equal(Services.Holdup.start(rival, 3, 3 * 1000).ok, true, 'one member back online reopens the runner')
Services.Holdup.release(3)
Services.Holdup.resetDealer(3)

N.Entities.setState = realSetState
serverConfig.holdup.reactionChance = 60
standAtCorner(rival, dealerId)

-- Morte do corredor -------------------------------------------------------------------------------

local victim = State.dealer(2)
T.equal(victim.status, C.DealerStatus.DEPLOYED, 'victim starts deployed')
T.equal(N.Entities.spawned[2], true, 'victim has a ped')

-- Chamado para a polícia. Sem ele, executar os corredores é a forma silenciosa de atacar um
-- posto: não rende loot, não acorda ninguém, e o dono só descobre pelo telefone.
local dispatchesBefore = #dispatches
State.get(OUTPOST).dispatchUntil = 0
local realKillDispatch = serverConfig.dealers.dispatchChance
serverConfig.dealers.dispatchChance = 100

N.Entities.dead[2] = true
local down = Services.Dealer.markDown(2)
T.equal(down, true, 'killing the runner takes him out of action')

T.equal(#dispatches, dispatchesBefore + 1, 'killing a runner calls the police')
local killCall = dispatches[#dispatches]
T.equal(killCall.code, serverConfig.dispatch.downCode, 'the call carries the homicide code')
T.equal(killCall.jobs[1], serverConfig.police.jobs[1], 'the call goes to the police')

-- E a chacina inteira vira uma ocorrência, não quatro: o cooldown de dispatch é por posto, e
-- matar o primeiro corredor já o arma para os seguintes.
T.truthy(State.get(OUTPOST).dispatchUntil > os.time(),
    'the first kill arms the per-outpost dispatch cooldown')
serverConfig.dealers.dispatchChance = realKillDispatch
T.equal(State.dealer(2).status, C.DealerStatus.RECOVERING, 'killed runner is recovering')
T.equal(N.Entities.corpses[2], true, 'the body stays where it fell')
T.equal(N.Entities.spawned[2], true, 'the corpse is not deleted on the spot')

local downOperation
for _, op in pairs(db.operations) do
    if op.type == C.OperationKind.DOWN then downOperation = op end
end
T.truthy(downOperation, 'the takedown was written to the ledger')
T.equal(downOperation.dealerId, 2, 'ledger points at the runner')

db.stock[OUTPOST].weed_brick = 50
State.reload(OUTPOST)
local downSold, downReason = Services.Sale.process(State.dealer(2))
T.equal(downSold, false, 'a downed runner stops selling')

T.equal(Services.Dealer.markDown(2), false, 'a runner already down cannot be downed again')

-- Morte limpa: prazo curto, para matar não virar o atalho de tirar um posto de operação.
local plainDown = db.dealers[2].robbed_until - os.time()
T.truthy(plainDown <= serverConfig.dealers.downCooldownSeconds
    and plainDown > serverConfig.dealers.downCooldownSeconds - 5,
    'a plain kill serves the short cooldown')
T.truthy(plainDown < serverConfig.robbery.cooldownSeconds,
    'a plain kill brings the runner back sooner than a robbery does')

-- Matar quem acabou de ser assaltado. O estado aqui é o do fluxo real: este corredor foi rendido
-- e roubado de verdade lá em cima, então ele já está em `recovering` e nada é ajustado à mão.
-- A versão anterior deste teste devolvia o corredor para `deployed` antes de carimbar o assalto,
-- montando um estado que o assalto nunca produz — e por isso passava enquanto a morte de um
-- corredor roubado era recusada em silêncio.
local robbedRunner = State.dealer(dealerId)
T.equal(robbedRunner.status, C.DealerStatus.RECOVERING, 'the robbed runner is still recovering')
local robberyDeadline = robbedRunner.robbed_until

local function countDowns()
    local total = 0
    for _, op in pairs(db.operations) do
        if op.type == C.OperationKind.DOWN then total = total + 1 end
    end
    return total
end
local downsBefore = countDowns()

N.Entities.dead[dealerId] = true
T.equal(Services.Dealer.markDown(dealerId), true, 'killing a robbed runner takes him out of action')

local killDeadline = State.dealer(dealerId).robbed_until
T.truthy(killDeadline - os.time() > serverConfig.robbery.cooldownSeconds,
    'the kill replaces the robbery window with the full execution cooldown')
T.truthy(killDeadline > robberyDeadline, 'the deadline only ever moves forward')
-- E é o prazo longo, não o da morte limpa: executar o rendido é o caminho caro dos dois.
T.truthy(killDeadline - os.time() > serverConfig.dealers.downCooldownSeconds,
    'executing a robbed runner costs more than a plain kill')
T.equal(N.Entities.corpses[dealerId], true, 'the body is marked so the engine can reclaim it')

-- Registro: o episódio é um só para a organização, e o alerta do roubo já saiu.
T.equal(countDowns(), downsBefore, 'a kill that follows a robbery opens no ledger row of its own')

-- O carimbo do assalto é consumido na primeira passagem. A varredura reencontra o mesmo corpo a
-- cada volta, e sem isso ela empurraria o prazo para sempre.
T.equal(Services.Dealer.markDown(dealerId), false, 'the same corpse is not marked down twice')
T.equal(State.dealer(dealerId).robbed_until, killDeadline, 'a refused re-mark leaves the deadline alone')

-- Recuperação: volta a operar e reaparece no posto.
db.dealers[2].robbed_until = os.time() - 1
State.reload(OUTPOST)
Services.Dealer.recoverDue()
T.equal(State.dealer(2).status, C.DealerStatus.DEPLOYED, 'the runner comes back after the cooldown')
T.equal(N.Entities.spawned[2], true, 'a fresh ped returns to the corner')
T.equal(N.Entities.dead[2], nil, 'the replacement is alive')
T.equal(N.Entities.corpses[2], nil, 'the corpse was cleared on recovery')

local backSold = Services.Sale.process(State.dealer(2))
T.equal(backSold, true, 'the recovered runner sells again')

-- Aviso do dono de rede. Ele diz apenas quando olhar; quem decide é a leitura do servidor, com a
-- mesma regra da varredura. Um client mentindo encontra um ped vivo e não derruba ninguém.
T.equal(State.dealer(2).status, C.DealerStatus.DEPLOYED, 'the runner is on duty')
T.equal(Services.Dealer.confirmDown(2), false, 'a client claim alone downs nobody')
N.Entities.dead[2] = true
T.equal(Services.Dealer.confirmDown(2), true, 'told to look, the server confirms the kill')
T.equal(State.dealer(2).status, C.DealerStatus.RECOVERING, 'the confirmed kill takes him out of action')
T.truthy(Services.Dealer.forceRecover(OUTPOST) > 0, 'and the admin command brings him back')
T.equal(State.dealer(2).status, C.DealerStatus.DEPLOYED, 'back on duty')

-- Matar e recuperar em seguida, sem passar por aviso nenhum. A morte só vira estado na varredura
-- de peds, que roda a cada `dealers.auditSeconds`; antes o comando chegava primeiro, encontrava o
-- corredor ainda em campo e respondia zero, como se não houvesse nada a recuperar.
N.Entities.dead[2] = true
T.equal(State.dealer(2).status, C.DealerStatus.DEPLOYED, 'the runner is on duty when he is killed')
T.truthy(Services.Dealer.forceRecover(OUTPOST) > 0, 'recovering right after a kill finds the body')
T.equal(State.dealer(2).status, C.DealerStatus.DEPLOYED, 'and puts a runner back on the corner')
T.equal(N.Entities.dead[2], nil, 'the replacement is alive')

-- Demissão -------------------------------------------------------------------------------------------------

resetRateLimits()
local fire = Services.Dealer.fire(leader, OUTPOST, dealerId, 'req-fire-0001')
T.equal(fire.ok, true, 'leader fires the dealer')
T.equal(N.Entities.spawned[dealerId], nil, 'dealer entity removed')
T.equal(State.dealer(dealerId), nil, 'dealer is gone from the state')

resetRateLimits()
local fireAgain = Services.Dealer.fire(leader, OUTPOST, dealerId, 'req-fire-0002')
T.equal(fireAgain.ok, false, 'firing a removed dealer fails')
T.equal(fireAgain.code, 'unknown_dealer', 'unknown dealer code')

-- Rate limit ------------------------------------------------------------------------------------------------

gameTimer = gameTimer + 60000
T.equal(Security.consumeRateLimit(1, 'deposit'), true, 'first call passes the rate limit')
T.equal(Security.consumeRateLimit(1, 'deposit'), false, 'immediate repeat is rate limited')
gameTimer = gameTimer + serverConfig.rateLimits.deposit + 1
T.equal(Security.consumeRateLimit(1, 'deposit'), true, 'rate limit clears after the interval')

-- Distância ----------------------------------------------------------------------------------------------------

pedCoords[2 * 10] = vector3(computer.x + 50.0, computer.y, computer.z)
resetRateLimits()
local farDeposit = Services.Stock.deposit(member, OUTPOST, 'weed_brick', 5, 'req-dep-00010')
T.equal(farDeposit.ok, false, 'a distant player cannot deposit')
T.equal(farDeposit.code, 'too_far', 'distance check code')

-- Feed de notificações --------------------------------------------------------------------------

local page = Services.Feed.page(leader, nil)
T.equal(page.ok, true, 'leader reads the feed')
T.truthy(#page.data.items > 0, 'the feed carries the ledger')

-- Mais recente primeiro.
for index = 2, #page.data.items do
    local previous, current = page.data.items[index - 1], page.data.items[index]
    T.truthy(previous.at > current.at or (previous.at == current.at and previous.id > current.id),
        'feed is ordered newest first')
end

T.equal(#page.data.items <= serverConfig.limits.feedPageSize, true, 'page respects the size limit')

-- Paginação por cursor não repete nem pula linhas.
local seen, pages = {}, 0
local cursor = nil
repeat
    local current = Services.Feed.page(leader, cursor)
    T.equal(current.ok, true, 'every page resolves')
    for _, item in ipairs(current.data.items) do
        T.equal(seen[item.id], nil, 'no item repeats across pages')
        seen[item.id] = true
    end
    cursor = current.data.nextCursor
    pages = pages + 1
until cursor == nil or pages > 20

T.equal(cursor, nil, 'pagination terminates')

local total = 0
for _, op in pairs(db.operations) do
    local committed = op.status == C.OperationStatus.COMMITTED or op.status == C.OperationStatus.PAID
    if op.organizationId == 'ballas' and committed then total = total + 1 end
end
local collected = 0
for _ in pairs(seen) do collected = collected + 1 end
T.equal(collected, total, 'every committed operation of the organization was delivered once')

-- Escopo: rival não vê o histórico alheio.
local rivalPage = Services.Feed.page(rival, nil)
T.equal(rivalPage.ok, true, 'rival gets a feed of their own')
T.equal(#rivalPage.data.items, 0, 'rival sees nothing from another organization')

-- Sem organização não há feed.
local nobody = { source = 9, citizenId = 'NOONE001', character = {}, organization = nil }
local denied = Services.Feed.page(nobody, nil)
T.equal(denied.ok, false, 'a player without an organization has no feed')
T.equal(denied.code, 'no_organization', 'no organization code')

-- Preferências de alerta e limpeza do feed --------------------------------------------------------

local snapshotSettings = Services.Settings.snapshot(leader)
T.equal(snapshotSettings.ok, true, 'settings load')
T.equal(#snapshotSettings.data.categories, #serverConfig.alerts.categories, 'every category is offered')
for _, category in ipairs(snapshotSettings.data.categories) do
    T.equal(category.enabled, true, 'categories start enabled')
end

T.equal(Services.Settings.allows(leader.citizenId, 'sales'), true, 'sales alerts allowed by default')

local saved = Services.Settings.setAlerts(leader, { sales = false, security = true })
T.equal(saved.ok, true, 'preferences saved')
T.equal(Services.Settings.allows(leader.citizenId, 'sales'), false, 'disabled category is refused')
T.equal(Services.Settings.allows(leader.citizenId, 'security'), true, 'the others stay on')
T.equal(Services.Settings.allows(leader.citizenId, 'stock'), true, 'omitted category keeps its default')

-- Categoria inventada não entra.
Services.Settings.setAlerts(leader, { invented = false })
T.equal(Services.Settings.allows(leader.citizenId, 'invented'), true, 'unknown category is ignored')

-- O filtro de alerta não pode encolher o feed.
local beforeClear = Services.Feed.page(leader, nil)
T.truthy(#beforeClear.data.items > 0, 'feed still complete with alerts disabled')
local hadSale = false
for _, item in ipairs(beforeClear.data.items) do
    if item.type == 'sale' then hadSale = true end
end
T.equal(hadSale, true, 'sales still show in the feed even with the sales alert off')

-- Limpar esconde o passado sem apagar o ledger.
local operationsBefore = 0
for _ in pairs(db.operations) do operationsBefore = operationsBefore + 1 end

local cleared = Services.Settings.clearFeed(leader)
T.equal(cleared.ok, true, 'feed cleared')

local afterClear = Services.Feed.page(leader, nil)
T.equal(#afterClear.data.items, 0, 'the feed is empty right after clearing')

local operationsAfter = 0
for _ in pairs(db.operations) do operationsAfter = operationsAfter + 1 end
T.equal(operationsAfter, operationsBefore, 'clearing never deletes ledger rows')

-- E o de outro membro não foi afetado: a limpeza é por personagem.
T.truthy(#Services.Feed.page(member, nil).data.items > 0, 'clearing is per character')

print('domain_spec: ok')
