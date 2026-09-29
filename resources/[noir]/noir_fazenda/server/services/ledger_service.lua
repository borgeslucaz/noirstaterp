NoirFazenda = NoirFazenda or {}
NoirFazenda.Services = NoirFazenda.Services or {}
NoirFazenda.Services.Ledger = {}

local Constants = NoirFazenda.Constants
local Rules = NoirFazenda.Rules
local Storage = NoirFazenda.Storage

local Service = NoirFazenda.Services.Ledger

local function isFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

---Grava um lançamento já classificado.
---@param entry table
---@return boolean ok
---@return string? errorCode
function Service.write(entry)
    if type(entry) ~= 'table' then return false, Constants.errors.invalidArgument end
    if type(entry.subjectId) ~= 'string' or entry.subjectId == '' or #entry.subjectId > 64 then
        return false, Constants.errors.invalidSubject
    end
    if not isFiniteNumber(entry.amount) or entry.amount <= 0 then
        return false, Constants.errors.invalidAmount
    end

    if entry.occurredAt == nil or not isFiniteNumber(entry.occurredAt) or entry.occurredAt <= 0 then
        entry.occurredAt = os.time()
    end
    entry.periodKey = entry.periodKey or Rules.periodKey(entry.occurredAt, NoirFazenda.Config)

    local ok, result = pcall(Storage.insertEntry, entry)
    if not ok then
        NoirFazenda.Logger.error('ledger_write_failed', {
            subjectId = entry.subjectId,
            category = entry.category,
            error = tostring(result),
        })
        return false, Constants.errors.storageFailed
    end

    NoirFazenda.Logger.debug('ledger_write', {
        subjectId = entry.subjectId,
        category = entry.category,
        amount = entry.amount,
        taxable = entry.taxable,
        periodKey = entry.periodKey,
        inserted = result,
    })

    -- `result == false` significa que o lançamento já existia. Isso é sucesso, não
    -- falha: é a idempotência funcionando.
    return true
end

---Consome um movimento bancário normalizado vindo do bridge.
---@param movement table
function Service.recordBankMovement(movement)
    if not NoirFazenda.Ready then return end

    local entry = Rules.classifyBankMovement(movement, NoirFazenda.Config)
    if not entry then return end

    Service.write(entry)
end

---Produtor genérico: qualquer resource pode declarar renda que não passa pelo
---banco (salário, pagamento de job, venda ilegal liquidada em espécie).
---
---Existe porque o feed bancário, sozinho, é cego para isso: `handleTransaction`
---só enxerga o que passa pela interface do banco. Dinheiro creditado direto na
---carteira por outro script nunca aparece lá.
---@param payload table
---@param callerResource? string
---@return boolean ok
---@return string? errorCode
function Service.recordIncome(payload, callerResource)
    if type(payload) ~= 'table' then return false, Constants.errors.invalidArgument end

    local subjectType = payload.subjectType or Constants.subject.player
    if subjectType ~= Constants.subject.player and subjectType ~= Constants.subject.org then
        return false, Constants.errors.invalidSubject
    end

    local ledgerConfig = NoirFazenda.Config.Ledger
    local amount = tonumber(payload.amount)
    if not isFiniteNumber(amount)
        or amount < (ledgerConfig.minimumAmount or 1)
        or amount > (ledgerConfig.maximumAmount or math.huge) then
        return false, Constants.errors.invalidAmount
    end
    amount = math.floor(amount)

    local source = callerResource or 'unknown'
    -- Sem `eventId` não há idempotência, e recompensa duplicada vira base de
    -- imposto duplicada. Quando o chamador não fornece um, derivamos um id do
    -- conteúdo -- não é perfeito, mas evita que um replay do mesmo instante
    -- entre duas vezes.
    local eventId = type(payload.eventId) == 'string' and payload.eventId ~= ''
        and payload.eventId
        or ('%s:%s:%s:%s'):format(source, payload.subjectId or '?', amount, os.time())

    -- Organização não é pessoa física: entra no ledger, nunca tributada hoje.
    local taxable = subjectType == Constants.subject.player
    if payload.taxable == false then taxable = false end

    return Service.write({
        eventId = eventId:sub(1, 160),
        subjectType = subjectType,
        subjectId = payload.subjectId,
        direction = Constants.direction.inbound,
        category = payload.category or Constants.category.declaredIncome,
        taxable = taxable,
        amount = amount,
        counterparty = type(payload.counterparty) == 'string'
            and payload.counterparty:sub(1, 128) or nil,
        provider = source,
        sourceResource = source:sub(1, 64),
        reference = type(payload.reference) == 'string' and payload.reference:sub(1, 64) or nil,
        metadata = type(payload.metadata) == 'table' and payload.metadata or nil,
        occurredAt = tonumber(payload.occurredAt),
    })
end

---@param subjectType string
---@param subjectId string
---@param periodKey? string
---@return table totals
function Service.totals(subjectType, subjectId, periodKey)
    periodKey = periodKey or Rules.periodKey(os.time(), NoirFazenda.Config)
    local totals = Storage.periodTotals(subjectType, subjectId, periodKey)
    totals.periodKey = periodKey
    return totals
end
