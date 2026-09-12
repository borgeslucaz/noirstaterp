-- Scheduler único: uma thread com Wait para vendas, expiração, corners e manutenção.
-- Sem thread por dealer e sem query por frame.
NoirOutposts = NoirOutposts or {}

local Scheduler = {}
NoirOutposts.Scheduler = Scheduler

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Entities = NoirOutposts.Entities
local Repositories = NoirOutposts.Repositories
local Services = NoirOutposts.Services

local running = false
local startupCatchup = {}
local lastExpiryCheck = 0
local lastEntityAudit = 0

---Dealers com venda vencida. Limita o catch-up após restart a uma venda por dealer.
---@param now integer
---@return table[] dealers
local function dueDealers(now)
    local due = {}
    for _, entry in pairs(State.outposts) do
        if entry.row.status == C.OutpostStatus.CONTROLLED then
            for _, dealer in pairs(entry.dealers) do
                if dealer.status == C.DealerStatus.DEPLOYED
                    and dealer.next_sale_at and dealer.next_sale_at <= now then
                    due[#due + 1] = dealer
                end
            end
        end
    end
    table.sort(due, function(a, b)
        local left = a.next_sale_at or 0
        local right = b.next_sale_at or 0
        if left == right then return a.id < b.id end
        return left < right
    end)
    return due
end

---@param now integer
local function processSales(now)
    local due = dueDealers(now)
    for index = 1, #due do
        local dealer = due[index]
        local allowance = startupCatchup[dealer.id]
        if allowance == nil then
            startupCatchup[dealer.id] = config.sales.maxStartupCatchupSalesPerDealer
            allowance = config.sales.maxStartupCatchupSalesPerDealer
        end

        local lateBy = now - (dealer.next_sale_at or now)
        local isLate = lateBy > State.intervalFor(dealer.profile_key)
        if isLate and allowance <= 0 then
            Services.Sale.defer(dealer, now)
        else
            local sold, reason = Services.Sale.process(dealer)
            if sold then
                if isLate then startupCatchup[dealer.id] = allowance - 1 end
            elseif reason ~= 'busy' and reason ~= 'conflict' then
                Services.Sale.defer(dealer, now)
            end
        end
    end
end

---Corredor morto sai de operação, e corredor sem ped recebe um novo.
---@param now integer
local function auditEntities(now)
    if now - lastEntityAudit < config.dealers.auditSeconds then return end
    lastEntityAudit = now

    local dead = Entities.deadDealers()
    for index = 1, #dead do Services.Dealer.markDown(dead[index]) end
    Entities.syncAll()
end

---Expiração de controle, aviso prévio e rotação de corners.
---@param now integer
local function processLifecycle(now)
    if now - lastExpiryCheck < config.scheduler.expiryCheckSeconds then return end
    lastExpiryCheck = now

    -- Dealers demitidos não precisam mais de cota de catch-up.
    for dealerId in pairs(startupCatchup) do
        if not State.dealer(dealerId) then startupCatchup[dealerId] = nil end
    end

    local ids = {}
    for id in pairs(State.outposts) do ids[#ids + 1] = id end
    table.sort(ids)

    for index = 1, #ids do
        local outpostId = ids[index]
        local entry = State.get(outpostId)
        if entry and entry.row.status == C.OutpostStatus.CONTROLLED then
            local row = entry.row
            local warningAt = (row.expires_at or 0) - config.rotation.expiryWarningMinutes * 60

            if row.expires_at and row.expires_at <= now then
                local organizationId = Services.Rotation.releaseExpired(outpostId)
                if organizationId then
                    Services.Notification.notifyOrganization(organizationId, {
                        title = locale('phone.expired_title'),
                        body = locale('phone.expired_body', shared.outposts[outpostId].label),
                    })
                end
                Services.Notification.broadcastPublicSnapshot()
                Services.Notification.refreshPanels(outpostId)
            elseif row.expires_at and now >= warningAt and not row.expiry_warned_at then
                Repositories.Outpost.setExpiryWarned(outpostId, now)
                Services.Notification.notifyOrganization(row.owner_organization_id, {
                    title = locale('phone.expiring_title'),
                    body = locale('phone.expiring_body',
                        shared.outposts[outpostId].label, config.rotation.expiryWarningMinutes),
                })
                State.reload(outpostId)
            else
                local rotateAfter = config.rotation.rotateDealersMinutes * 60
                if (row.last_corner_rotation_at or 0) + rotateAfter <= now then
                    Services.Rotation.rotateCorners(outpostId)
                end
            end
        end
    end

    if Services.Rotation.isCycleExpired() then
        Log.info('rotation_cycle_expired', {})
        Services.Rotation.apply()
        Services.Notification.broadcastPublicSnapshot()
    end
end

function Scheduler.start()
    if running then return end
    running = true
    CreateThread(function()
        while running do
            local ok, err = pcall(function()
                local now = os.time()
                Sessions.tick()
                Security.pruneRequestIds()
                Services.Dealer.recoverDue()
                auditEntities(now)
                processSales(now)
                processLifecycle(now)
                Services.Notification.flush()
            end)
            if not ok then Log.error('scheduler_tick_failed', { error = tostring(err) }) end
            Wait(config.scheduler.tickMs)
        end
    end)
end

function Scheduler.stop()
    running = false
    startupCatchup = {}
    lastEntityAudit = 0
end
