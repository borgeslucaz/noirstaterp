-- Notificações agregadas (telefone), dispatch com cooldown e push de snapshot aos painéis abertos.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Notification = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local State = NoirOutposts.State
local Integration = NoirOutposts.Integration

local pending = {}

---@param organizationId string
---@param payload table { title, body }
---@param minimumGrade? number
local function pushToOrganization(organizationId, payload, minimumGrade)
    local members = Integration.onlineMembersWithGrade(organizationId, minimumGrade)
    for index = 1, #members do
        Integration.sendPhoneNotification(members[index], {
            title = payload.title,
            body = payload.body,
        })
    end
end

---Evento importante: entregue imediatamente.
---@param organizationId string
---@param payload table
---@param minimumGrade? number
function Service.notifyOrganization(organizationId, payload, minimumGrade)
    if not organizationId then return end
    pushToOrganization(organizationId, payload, minimumGrade)
end

---Vendas: agregadas em janela para não inundar o telefone.
---@param outpostId string
---@param organizationId string
---@param net integer
function Service.queueSale(outpostId, organizationId, net)
    if not organizationId then return end
    local key = organizationId .. ':' .. outpostId
    local entry = pending[key]
    if not entry then
        entry = {
            organizationId = organizationId,
            outpostId = outpostId,
            count = 0,
            net = 0,
            firstAt = os.time(),
        }
        pending[key] = entry
    end
    entry.count = entry.count + 1
    entry.net = entry.net + net
end

function Service.flush()
    local now = os.time()
    local due = {}
    for key, entry in pairs(pending) do
        if entry.firstAt + config.notifications.aggregateWindowSeconds <= now then
            due[#due + 1] = key
        end
    end
    for index = 1, #due do
        local key = due[index]
        local entry = pending[key]
        pending[key] = nil
        local definition = shared.outposts[entry.outpostId]
        pushToOrganization(entry.organizationId, {
            title = locale('phone.sales_title'),
            body = locale('phone.sales_body', entry.count, definition and definition.label or entry.outpostId, entry.net),
        }, config.notifications.minGradeForSales)
    end
end

function Service.clear()
    pending = {}
end

-- Dispatch -----------------------------------------------------------------------------

local function approximate(coords)
    local range = config.dispatch.offset
    local distance = range.min + math.random() * (range.max - range.min)
    local angle = math.random() * math.pi * 2
    return {
        x = coords.x + math.cos(angle) * distance,
        y = coords.y + math.sin(angle) * distance,
        z = coords.z,
    }
end

---@param outpostId string
---@param kind 'sale'|'robbery'
---@param chance integer
---@return boolean sent
function Service.maybeDispatch(outpostId, kind, chance)
    local entry = State.get(outpostId)
    local definition = shared.outposts[outpostId]
    if not entry or not definition then return false end
    if math.random(100) > chance then return false end

    local now = os.time()
    if entry.dispatchUntil > now then return false end
    entry.dispatchUntil = now + config.sales.dispatchCooldownSeconds

    local isRobbery = kind == 'robbery'
    return Integration.sendDispatch({
        code = isRobbery and config.dispatch.robberyCode or config.dispatch.code,
        title = isRobbery and locale('dispatch.robbery_title') or locale('dispatch.sale_title'),
        message = definition.dispatch.label,
        coords = approximate(definition.entrance),
        jobs = config.police.jobs,
        duration = config.dispatch.duration,
        priority = config.dispatch.priority,
        radius = definition.dispatch.radius,
    })
end

-- Sincronização de clients ----------------------------------------------------------------

function Service.broadcastPublicSnapshot()
    TriggerClientEvent(C.Events.SYNC, -1, State.publicSnapshot())
end

---@param source number
function Service.sendPublicSnapshot(source)
    TriggerClientEvent(C.Events.SYNC, source, State.publicSnapshot())
end

---Reenvia o snapshot do painel a todos que estão com ele aberto neste outpost.
---@param outpostId string
function Service.refreshPanels(outpostId)
    local Api = NoirOutposts.Api
    if not Api or not Api.buildPanelSnapshot then return end
    local viewers = NoirOutposts.Sessions.panelViewers(outpostId)
    for index = 1, #viewers do
        local source = viewers[index]
        local snapshot = Api.buildPanelSnapshot(source, outpostId)
        if snapshot then
            TriggerClientEvent(C.Events.PANEL_UPDATE, source, snapshot)
        else
            NoirOutposts.Sessions.closePanel(source, 'unauthorized')
        end
    end
end

---Avisos automáticos de estoque baixo/zerado, um por transição.
---@param outpostId string
function Service.checkStockAlerts(outpostId)
    local entry = State.get(outpostId)
    if not entry or not entry.row.owner_organization_id then return end
    local total = State.stockTotal(outpostId)
    local definition = shared.outposts[outpostId]
    if total <= 0 then
        if entry.emptyNotified then return end
        entry.emptyNotified = true
        entry.lowStockNotified = true
        Service.notifyOrganization(entry.row.owner_organization_id, {
            title = locale('phone.stock_empty_title'),
            body = locale('phone.stock_empty_body', definition.label),
        }, config.permissions.stock)
        return
    end
    if total <= config.notifications.lowStockThreshold and not entry.lowStockNotified then
        entry.lowStockNotified = true
        Service.notifyOrganization(entry.row.owner_organization_id, {
            title = locale('phone.stock_low_title'),
            body = locale('phone.stock_low_body', definition.label, total),
        }, config.permissions.stock)
    end
end
