-- Feed de notificações da organização, montado a partir do ledger de operações.
-- Paginado por cursor para o scroll infinito do telefone.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Feed = Service

local config = require 'config.server'
local shared = require 'config.shared'
local State = NoirOutposts.State
local Security = NoirOutposts.Security
local Repositories = NoirOutposts.Repositories

local productLabels = {}
for index = 1, #shared.products do
    productLabels[shared.products[index].id] = shared.products[index].label
end
productLabels[shared.payoutItem] = 'Dinheiro sujo'

---@param payload any coluna JSON crua
---@return table
local function decodePayload(payload)
    if type(payload) == 'table' then return payload end
    if type(payload) ~= 'string' or payload == '' then return {} end
    local ok, decoded = pcall(json.decode, payload)
    return ok and type(decoded) == 'table' and decoded or {}
end

---Nome do corredor: o dealer pode já não existir, então o que foi gravado na operação manda.
---Nomes são sorteados na tomada, e um corredor demitido leva o dele embora; sem a cópia
---no payload o histórico passaria a mostrar o nome do arquétipo em vez de quem estava lá.
---@param row table
---@param payload table
---@return string?
local function dealerName(row, payload)
    if type(payload.dealerName) == 'string' and payload.dealerName ~= '' then
        return payload.dealerName
    end

    if row.dealer_id then
        local dealer = State.dealer(row.dealer_id)
        local current = dealer and State.dealerName(dealer) or nil
        if current then return current end
    end

    local profileKey = payload.profileKey
    if not profileKey and row.dealer_id then
        local dealer = State.dealer(row.dealer_id)
        profileKey = dealer and dealer.profile_key or nil
    end
    if not profileKey then return nil end
    local profile = State.profiles[profileKey]
    return profile and profile.name or profileKey
end

---@param row table
---@return table item JSON-safe
local function toItem(row)
    local payload = decodePayload(row.payload)
    local definition = shared.outposts[row.outpost_id]
    return {
        id = row.operation_id,
        type = row.operation_type,
        outpostId = row.outpost_id,
        outpostLabel = definition and definition.label or row.outpost_id,
        dealer = dealerName(row, payload),
        item = row.item_name,
        itemLabel = row.item_name and productLabels[row.item_name] or nil,
        quantity = row.quantity and math.floor(row.quantity) or nil,
        gross = row.gross_amount and math.floor(row.gross_amount) or nil,
        net = row.net_amount and math.floor(row.net_amount) or nil,
        reacted = payload.reacted,
        at = math.floor(row.created_at),
    }
end

---Uma página do feed. O cursor aponta para a última linha entregue.
---@param actor OutpostActor
---@param cursor table? { at, id }
---@return table result { ok, code?, data? }
function Service.page(actor, cursor)
    if not actor.organization then return { ok = false, code = 'no_organization' } end
    local permissions = Security.permissionMap(actor)
    if not permissions.view then return { ok = false, code = 'insufficient_grade' } end

    local limit = config.limits.feedPageSize
    -- O recorte é só do que o jogador já limpou. Nenhuma preferência de alerta filtra
    -- o feed: dentro do app o histórico é sempre completo.
    local since = NoirOutposts.Services.Settings.get(actor.citizenId).clearedAt
    local rows = Repositories.Operation.feed(actor.organization.id, limit, cursor, since)

    local hasMore = #rows > limit
    local items = {}
    for index = 1, math.min(#rows, limit) do
        items[index] = toItem(rows[index])
    end

    local nextCursor
    if hasMore and #items > 0 then
        local last = items[#items]
        nextCursor = { at = last.at, id = last.id }
    end

    return {
        ok = true,
        data = {
            serverTime = os.time(),
            items = items,
            nextCursor = nextCursor,
        },
    }
end
