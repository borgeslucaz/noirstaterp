-- Preferências por personagem: quais alertas chegam no telefone e até onde o feed foi limpo.
-- O filtro vale só para o alerta empurrado; dentro do app o histórico continua completo.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Settings = Service

local config = require 'config.server'
local Log = NoirOutposts.Log
local Repositories = NoirOutposts.Repositories

---@type table<string, { clearedAt: integer, alerts: table<string, boolean> }>
local cache = {}

---@return table<string, boolean>
local function defaultAlerts()
    local alerts = {}
    for index = 1, #config.alerts.categories do
        alerts[config.alerts.categories[index]] = true
    end
    return alerts
end

---Só categorias conhecidas entram, e o valor é sempre booleano.
---@param value any
---@return table<string, boolean>
local function sanitizeAlerts(value)
    local alerts = defaultAlerts()
    if type(value) ~= 'table' then return alerts end
    for index = 1, #config.alerts.categories do
        local category = config.alerts.categories[index]
        if value[category] ~= nil then alerts[category] = value[category] == true end
    end
    return alerts
end

Service.sanitizeAlerts = sanitizeAlerts

---@param citizenId string
---@return { clearedAt: integer, alerts: table<string, boolean> }
function Service.get(citizenId)
    if type(citizenId) ~= 'string' or citizenId == '' then
        return { clearedAt = 0, alerts = defaultAlerts() }
    end
    local entry = cache[citizenId]
    if entry then return entry end

    local row = Repositories.Settings.get(citizenId)
    entry = {
        clearedAt = row and tonumber(row.feed_cleared_at) or 0,
        alerts = sanitizeAlerts(row and row.alerts or nil),
    }
    cache[citizenId] = entry
    return entry
end

---Um alerta só é entregue se o jogador o quiser. O feed ignora isto de propósito.
---@param citizenId string
---@param category string
---@return boolean
function Service.allows(citizenId, category)
    if not category then return true end
    return Service.get(citizenId).alerts[category] ~= false
end

---@param actor OutpostActor
---@param alerts table
---@return table result
function Service.setAlerts(actor, alerts)
    local sanitized = sanitizeAlerts(alerts)
    if not Repositories.Settings.setAlerts(actor.citizenId, sanitized) then
        return { ok = false, code = 'internal_error' }
    end
    local entry = Service.get(actor.citizenId)
    entry.alerts = sanitized
    Log.debug('alerts_updated', { citizenId = actor.citizenId })
    return { ok = true, data = { alerts = sanitized } }
end

---Limpa o feed do jogador marcando até quando ele já viu. Nada é apagado do ledger.
---@param actor OutpostActor
---@return table result
function Service.clearFeed(actor)
    local now = os.time()
    if not Repositories.Settings.setClearedAt(actor.citizenId, now) then
        return { ok = false, code = 'internal_error' }
    end
    local entry = Service.get(actor.citizenId)
    entry.clearedAt = now
    Log.debug('feed_cleared', { citizenId = actor.citizenId })
    return { ok = true, data = { clearedAt = now } }
end

---@param actor OutpostActor
---@return table result
function Service.snapshot(actor)
    local entry = Service.get(actor.citizenId)
    local categories = {}
    for index = 1, #config.alerts.categories do
        local category = config.alerts.categories[index]
        categories[index] = { id = category, enabled = entry.alerts[category] ~= false }
    end
    return { ok = true, data = { categories = categories, clearedAt = entry.clearedAt } }
end

---@param citizenId string
function Service.forget(citizenId)
    if type(citizenId) == 'string' then cache[citizenId] = nil end
end

function Service.clear()
    cache = {}
end
