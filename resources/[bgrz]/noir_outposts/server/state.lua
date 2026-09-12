-- Cache em memória do domínio (fonte de verdade é o banco; toda mutação recarrega o agregado)
-- e construtores de snapshot JSON-safe para client, painel e telefone.
NoirOutposts = NoirOutposts or {}

local State = {}
NoirOutposts.State = State

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local V = NoirOutposts.Validators
local Repositories = NoirOutposts.Repositories

State.outposts = {}
State.dealersById = {}
State.profiles = {}
State.productIds = {}

for index = 1, #shared.dealerProfiles do
    local profile = shared.dealerProfiles[index]
    State.profiles[profile.key] = profile
end

for index = 1, #shared.products do
    local product = shared.products[index]
    if config.products[product.id] then State.productIds[#State.productIds + 1] = product.id end
end

local function newEntry(row)
    return {
        row = row,
        dealers = {},
        stock = {},
        dispatchUntil = 0,
        lowStockNotified = false,
        emptyNotified = false,
    }
end

local function indexDealers(entry, rows)
    for dealerId in pairs(entry.dealers) do State.dealersById[dealerId] = nil end
    entry.dealers = {}
    for index = 1, #rows do
        local dealer = rows[index]
        entry.dealers[dealer.id] = dealer
        State.dealersById[dealer.id] = dealer
    end
end

local function indexStock(entry, rows)
    entry.stock = {}
    for index = 1, #rows do
        entry.stock[rows[index].item_name] = tonumber(rows[index].quantity) or 0
    end
end

function State.load()
    State.outposts = {}
    State.dealersById = {}
    local rows = Repositories.Outpost.getAll()
    for index = 1, #rows do
        local row = rows[index]
        if shared.outposts[row.id] then State.outposts[row.id] = newEntry(row) end
    end
    local dealers = Repositories.Dealer.listAll()
    local byOutpost = {}
    for index = 1, #dealers do
        local dealer = dealers[index]
        byOutpost[dealer.outpost_id] = byOutpost[dealer.outpost_id] or {}
        table.insert(byOutpost[dealer.outpost_id], dealer)
    end
    local stock = Repositories.Stock.listAll()
    local stockByOutpost = {}
    for index = 1, #stock do
        local row = stock[index]
        stockByOutpost[row.outpost_id] = stockByOutpost[row.outpost_id] or {}
        table.insert(stockByOutpost[row.outpost_id], row)
    end
    for id, entry in pairs(State.outposts) do
        indexDealers(entry, byOutpost[id] or {})
        indexStock(entry, stockByOutpost[id] or {})
    end
end

---Recarrega um outpost (linha, dealers e estoque) preservando flags transitórias.
---@param outpostId string
---@return table? entry
function State.reload(outpostId)
    local row = Repositories.Outpost.get(outpostId)
    if not row then return nil end
    local entry = State.outposts[outpostId]
    if not entry then
        entry = newEntry(row)
        State.outposts[outpostId] = entry
    else
        entry.row = row
    end
    indexDealers(entry, Repositories.Dealer.listByOutpost(outpostId))
    indexStock(entry, Repositories.Stock.listByOutpost(outpostId))
    if State.stockTotal(outpostId) > config.notifications.lowStockThreshold then
        entry.lowStockNotified = false
    end
    if State.stockTotal(outpostId) > 0 then entry.emptyNotified = false end
    return entry
end

---@param outpostId string
---@return table? entry
function State.get(outpostId)
    return State.outposts[outpostId]
end

---@param dealerId integer
---@return table? dealer
function State.dealer(dealerId)
    return State.dealersById[dealerId]
end

---@param outpostId string
---@return integer
function State.stockTotal(outpostId)
    local entry = State.outposts[outpostId]
    if not entry then return 0 end
    local total = 0
    for _, quantity in pairs(entry.stock) do total = total + quantity end
    return total
end

---@param outpostId string
---@return integer
function State.dealerCount(outpostId)
    local entry = State.outposts[outpostId]
    if not entry then return 0 end
    local count = 0
    for _ in pairs(entry.dealers) do count = count + 1 end
    return count
end

---@param outpostId string
---@return integer[] free corner indexes
function State.freeCorners(outpostId)
    local definition = shared.outposts[outpostId]
    local entry = State.outposts[outpostId]
    local used = {}
    if entry then
        for _, dealer in pairs(entry.dealers) do
            if dealer.corner_index then used[dealer.corner_index] = true end
        end
    end
    local free = {}
    for index = 1, #definition.dealerCorners do
        if not used[index] then free[#free + 1] = index end
    end
    return free
end

---@param outpostId string
---@return table[] dealers ordenados por id
function State.sortedDealers(outpostId)
    local entry = State.outposts[outpostId]
    local list = {}
    if not entry then return list end
    for _, dealer in pairs(entry.dealers) do list[#list + 1] = dealer end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

---@param profileKey string
---@return integer seconds
function State.intervalFor(profileKey)
    local profile = State.profiles[profileKey]
    local speed = profile and profile.stats.speed or 0
    return V.saleInterval(config.sales.baseIntervalSeconds, config.sales.minimumIntervalSeconds, speed)
end

---Nome de rua do corredor. Sorteado na contratação e gravado com ele, então não muda se o
---config mudar. Linhas anteriores ao sorteio caem no nome do arquétipo.
---@param dealer table?
---@return string?
function State.dealerName(dealer)
    if type(dealer) ~= 'table' then return nil end
    if type(dealer.display_name) == 'string' and dealer.display_name ~= '' then
        return dealer.display_name
    end
    local profile = State.profiles[dealer.profile_key]
    return profile and profile.name or dealer.profile_key
end

---Modelo de ped do corredor, com a mesma regra de herança do nome.
---@param dealer table?
---@return string?
function State.dealerModel(dealer)
    if type(dealer) ~= 'table' then return nil end
    if type(dealer.ped_model) == 'string' and dealer.ped_model ~= '' then return dealer.ped_model end
    local profile = State.profiles[dealer.profile_key]
    return profile and profile.model or nil
end

-- Snapshots ------------------------------------------------------------------------

local function dealerPublic(dealer)
    return {
        id = dealer.id,
        profileKey = dealer.profile_key,
        name = State.dealerName(dealer),
        status = dealer.status,
        cornerIndex = dealer.corner_index,
    }
end

---Snapshot público enviado a todos os clients: sem owner, estoque ou carteira.
---@return table[]
function State.publicSnapshot()
    local list = {}
    local ids = {}
    for id in pairs(shared.outposts) do ids[#ids + 1] = id end
    table.sort(ids)
    for index = 1, #ids do
        local id = ids[index]
        local entry = State.outposts[id]
        local row = entry and entry.row or nil
        local dealers = {}
        if entry then
            local sorted = State.sortedDealers(id)
            for dealerIndex = 1, #sorted do dealers[dealerIndex] = dealerPublic(sorted[dealerIndex]) end
        end
        list[#list + 1] = {
            id = id,
            label = shared.outposts[id].label,
            status = row and row.status or C.OutpostStatus.INACTIVE,
            operationType = row and row.operation_type or nil,
            ownerOrganizationId = row and row.owner_organization_id or nil,
            dealers = dealers,
        }
    end
    return list
end

local function historyEntry(op)
    return {
        id = op.operation_id,
        type = op.operation_type,
        dealerId = op.dealer_id,
        item = op.item_name,
        quantity = op.quantity,
        gross = op.gross_amount,
        net = op.net_amount,
        at = op.created_at,
    }
end

---@param entry table
---@param actor OutpostActor
---@param permissions table<string, boolean>
---@param extra table { online, police, cooldownUntil, carried = table<string, integer>, history }
---@return table snapshot
function State.panelSnapshot(entry, actor, permissions, extra)
    local row = entry.row
    local definition = shared.outposts[row.id]
    local organization = actor.organization
    local isOwner = organization ~= nil and row.owner_organization_id == organization.id
    local now = os.time()

    local snapshot = {
        serverTime = now,
        outpost = {
            id = row.id,
            label = definition.label,
            status = row.status,
            operationType = row.operation_type,
            claimedAt = row.claimed_at,
            expiresAt = row.expires_at,
            owner = row.owner_organization_id and {
                id = isOwner and row.owner_organization_id or nil,
                label = isOwner and organization.label or nil,
                isMine = isOwner,
            } or nil,
        },
        viewer = {
            organizationId = organization and organization.id or nil,
            organizationLabel = organization and organization.label or nil,
            grade = organization and organization.grade or nil,
            permissions = permissions,
            isOwner = isOwner,
        },
        claim = {
            available = row.status == C.OutpostStatus.AVAILABLE,
            canClaim = row.status == C.OutpostStatus.AVAILABLE and permissions.claim == true
                and (extra.cooldownUntil or 0) <= now,
            requirements = {
                minOnlinePlayers = config.claim.minOnlinePlayers,
                minPolice = config.claim.minPolice,
                online = extra.online or 0,
                police = extra.police or 0,
                cooldownUntil = extra.cooldownUntil,
                durationMs = config.claim.durationMs,
                controlHours = config.claim.ownerDurationHours,
            },
        },
        limits = {
            maxDealers = config.limits.maxDealersPerOutpost,
            maxStockTotal = config.limits.maxStockTotal,
            maxStockPerDeposit = config.limits.maxStockPerDeposit,
        },
        market = { profiles = {}, hiredCount = State.dealerCount(row.id) },
    }

    local hiredByProfile = {}
    for _, dealer in pairs(entry.dealers) do hiredByProfile[dealer.profile_key] = dealer end
    for index = 1, #shared.dealerProfiles do
        local profile = shared.dealerProfiles[index]
        local hired = hiredByProfile[profile.key]
        snapshot.market.profiles[index] = {
            key = profile.key,
            name = profile.name,
            description = profile.description,
            stats = profile.stats,
            hirePrice = config.dealerHirePrice[profile.key] or 0,
            intervalSeconds = State.intervalFor(profile.key),
            hired = hired ~= nil and isOwner,
            dealerId = hired and isOwner and hired.id or nil,
        }
    end

    if isOwner then
        local dealers = {}
        local sorted = State.sortedDealers(row.id)
        for index = 1, #sorted do
            local dealer = sorted[index]
            local profile = State.profiles[dealer.profile_key]
            dealers[index] = {
                id = dealer.id,
                profileKey = dealer.profile_key,
                name = State.dealerName(dealer),
                profileName = profile and profile.name or dealer.profile_key,
                status = dealer.status,
                cornerIndex = dealer.corner_index,
                nextSaleAt = dealer.next_sale_at,
                robbedUntil = dealer.robbed_until,
                lifetimeSales = dealer.lifetime_sales,
                lifetimeGross = dealer.lifetime_gross,
                intervalSeconds = State.intervalFor(dealer.profile_key),
                split = profile and profile.stats.split or 0,
            }
        end
        local stock = {}
        for index = 1, #shared.products do
            local product = shared.products[index]
            if config.products[product.id] then
                stock[#stock + 1] = {
                    id = product.id,
                    label = product.label,
                    quantity = entry.stock[product.id] or 0,
                    carried = extra.carried and extra.carried[product.id] or 0,
                }
            end
        end
        local history = {}
        for index = 1, #(extra.history or {}) do history[index] = historyEntry(extra.history[index]) end
        snapshot.runners = {
            dealers = dealers,
            stock = stock,
            stockTotal = State.stockTotal(row.id),
            purse = permissions.collect and {
                available = row.purse_available,
                pending = row.purse_pending,
            } or nil,
            history = history,
        }
    end

    return snapshot
end

---Snapshot do telefone: lista dos outposts com detalhes apenas para a própria organização.
---@param actor OutpostActor
---@param permissions table<string, boolean>
---@return table
function State.phoneSnapshot(actor, permissions)
    local organization = actor.organization
    local list = {}
    local ids = {}
    for id in pairs(shared.outposts) do ids[#ids + 1] = id end
    table.sort(ids)
    for index = 1, #ids do
        local id = ids[index]
        local entry = State.outposts[id]
        local row = entry and entry.row or nil
        local definition = shared.outposts[id]
        local isMine = organization ~= nil and row ~= nil and row.owner_organization_id == organization.id
        local item = {
            id = id,
            label = definition.label,
            status = row and row.status or C.OutpostStatus.INACTIVE,
            operationType = row and row.operation_type or nil,
            isMine = isMine,
            controlled = row ~= nil and row.owner_organization_id ~= nil,
            coords = { x = definition.entrance.x, y = definition.entrance.y, z = definition.entrance.z },
        }
        if isMine then
            item.dealers = State.dealerCount(id)
            item.expiresAt = row.expires_at
            if permissions.stock then item.stockTotal = State.stockTotal(id) end
            if permissions.collect then item.purse = row.purse_available end
        end
        list[#list + 1] = item
    end
    return {
        serverTime = os.time(),
        organization = organization and { id = organization.id, label = organization.label } or nil,
        permissions = permissions,
        outposts = list,
    }
end
