NoirFazenda = NoirFazenda or {}
NoirFazenda.Rules = {}

-- Módulo puro: sem SQL, sem natives, sem estado global mutável.
-- Tudo aqui é função de entrada -> saída, e é isso que torna a regra fiscal
-- testável sem servidor de pé (§22.1). Os testes vivem em tests/unit/rules_spec.lua.

local Constants = NoirFazenda.Constants
local floor = math.floor

local function isFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

--------------------------------------------------------------------------------
-- Calendário
--------------------------------------------------------------------------------

-- Conversão data <-> dia absoluto pelo algoritmo de Howard Hinnant.
--
-- Poderia usar os.date/os.time, mas os.time interpreta a tabela no fuso do
-- processo, e o processo roda em UTC enquanto o jogador pensa em Brasília. Isso
-- faria a semana fiscal virar em hora errada, e pior: viraria em hora DIFERENTE
-- dependendo de onde o servidor estivesse hospedado. Aritmética pura não tem
-- fuso, então o único fuso do sistema é o que está na config.

---@param y integer
---@param m integer
---@param d integer
---@return integer days dias desde 1970-01-01
function NoirFazenda.Rules.daysFromCivil(y, m, d)
    y = m <= 2 and y - 1 or y
    local era = floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

---@param z integer dias desde 1970-01-01
---@return integer year, integer month, integer day
function NoirFazenda.Rules.civilFromDays(z)
    z = z + 719468
    local era = floor(z / 146097)
    local doe = z - era * 146097
    local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
    local mp = floor((5 * doy + 2) / 153)
    local d = doy - floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end

local function offsetSeconds(config)
    local hours = config and config.Period and config.Period.timezoneOffsetHours or 0
    return isFiniteNumber(hours) and floor(hours * 3600) or 0
end

---Chave do período a que um instante pertence.
---O prefixo carrega o modo ('W'/'D'), então a chave se interpreta sozinha mesmo
---que a config mude depois -- período já gravado não muda de tamanho.
---@param timestamp integer unix
---@param config table
---@return string periodKey
function NoirFazenda.Rules.periodKey(timestamp, config)
    if not isFiniteNumber(timestamp) then timestamp = 0 end
    local mode = config and config.Period and config.Period.mode or 'weekly'
    local shifted = floor(timestamp) + offsetSeconds(config)
    local day = floor(shifted / 86400)

    local prefix = Constants.periodPrefix.daily
    if mode == 'weekly' then
        prefix = Constants.periodPrefix.weekly
        -- 1970-01-01 foi quinta. (day + 3) % 7 dá 0 na segunda, então subtrair
        -- isso recua para a segunda que abre a semana.
        day = day - ((day + 3) % 7)
    end

    local y, m, d = NoirFazenda.Rules.civilFromDays(day)
    return ('%s%04d-%02d-%02d'):format(prefix, y, m, d)
end

---@param periodKey string
---@param config table
---@return integer? startTimestamp
---@return integer? endTimestamp exclusivo
function NoirFazenda.Rules.periodBounds(periodKey, config)
    if type(periodKey) ~= 'string' then return nil end
    local prefix, y, m, d = periodKey:match('^([WD])(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not prefix then return nil end

    local day = NoirFazenda.Rules.daysFromCivil(tonumber(y), tonumber(m), tonumber(d))
    local length = prefix == Constants.periodPrefix.weekly and 7 or 1
    local startTimestamp = day * 86400 - offsetSeconds(config)
    return startTimestamp, startTimestamp + length * 86400
end

---Período imediatamente anterior ao de um instante. É o período que se fecha,
---porque fechar o período corrente contaria movimentação que ainda está acontecendo.
---@param timestamp integer
---@param config table
---@return string periodKey
function NoirFazenda.Rules.previousPeriodKey(timestamp, config)
    local currentKey = NoirFazenda.Rules.periodKey(timestamp, config)
    local startTimestamp = NoirFazenda.Rules.periodBounds(currentKey, config)
    return NoirFazenda.Rules.periodKey(startTimestamp - 1, config)
end

--------------------------------------------------------------------------------
-- Classificação
--------------------------------------------------------------------------------

---Traduz um movimento bancário normalizado em um lançamento do ledger.
---
---A regra fiscal deste servidor é "tributar só ENTRADAS", e a parte difícil é que
---o banco não distingue entrada de renda de entrada de bolso: depositar o próprio
---dinheiro em espécie e receber um pagamento chegam os dois como 'deposit'.
---
---O que separa os dois é `isTransferLeg`: transferência gera duas pernas ligadas
---pelo mesmo id, depósito em espécie gera uma perna solta. Tributar sem essa
---distinção seria cobrar imposto de alguém por usar o banco, e é exatamente isso
---que faz jogador abandonar conta e andar com dinheiro no bolso.
---@param movement table payload de `bgrz_core:bankMovement`
---@param config table
---@return table? entry
function NoirFazenda.Rules.classifyBankMovement(movement, config)
    if type(movement) ~= 'table' then return nil end

    local subjectType = movement.subjectType
    if subjectType ~= Constants.subject.player and subjectType ~= Constants.subject.org then
        return nil
    end
    if type(movement.subjectId) ~= 'string' or movement.subjectId == '' then return nil end

    local amount = movement.amount
    if not isFiniteNumber(amount) then return nil end
    amount = floor(amount)

    local ledgerConfig = config and config.Ledger or {}
    if amount < (ledgerConfig.minimumAmount or 1) then return nil end
    if amount > (ledgerConfig.maximumAmount or math.huge) then return nil end

    if subjectType == Constants.subject.org and ledgerConfig.recordOrganizations == false then
        return nil
    end

    local category, taxable
    if movement.direction == Constants.direction.outbound then
        category, taxable = Constants.category.outflow, false
    elseif movement.isTransferLeg then
        category, taxable = Constants.category.transferIn, true
    else
        category, taxable = Constants.category.selfDeposit, false
    end

    -- Organização não é pessoa física. A linha entra no ledger para o dia em que
    -- houver imposto sobre empresa, mas nunca sai tributada hoje.
    if subjectType == Constants.subject.org then taxable = false end

    if not taxable and ledgerConfig.recordNonTaxable == false then return nil end

    local counterparty = movement.direction == Constants.direction.inbound
        and movement.issuer or movement.receiver

    return {
        eventId = NoirFazenda.Rules.bankEventId(movement),
        subjectType = subjectType,
        subjectId = movement.subjectId,
        direction = movement.direction,
        category = category,
        taxable = taxable,
        amount = amount,
        counterparty = type(counterparty) == 'string' and counterparty ~= ''
            and counterparty:sub(1, 128) or nil,
        provider = movement.provider or 'unknown',
        sourceResource = Constants.resource,
        reference = movement.transactionId,
        occurredAt = isFiniteNumber(movement.occurredAt) and floor(movement.occurredAt) or 0,
    }
end

---Identidade estável de um movimento bancário.
---As duas pernas de uma transferência compartilham `transactionId`, então o id
---precisa carregar também sujeito e direção -- senão a segunda perna seria
---descartada como duplicata da primeira.
---@param movement table
---@return string eventId
function NoirFazenda.Rules.bankEventId(movement)
    return ('%s:%s:%s:%s'):format(
        movement.provider or 'bank',
        movement.transactionId or 'unknown',
        movement.direction or 'x',
        movement.subjectId or 'unknown'):sub(1, 160)
end

--------------------------------------------------------------------------------
-- Cálculo do imposto
--------------------------------------------------------------------------------

---Imposto progressivo na margem sobre a base do período.
---@param base integer
---@param config table
---@return integer assessed
---@return number effectiveRate
function NoirFazenda.Rules.computeTax(base, config)
    if not isFiniteNumber(base) or base <= 0 then return 0, 0.0 end
    base = floor(base)

    local brackets = config and config.Tax and config.Tax.brackets
    if type(brackets) ~= 'table' or #brackets == 0 then return 0, 0.0 end

    local total, lower = 0.0, 0
    for i = 1, #brackets do
        local bracket = brackets[i]
        local cap = bracket.upTo
        if cap == false or cap == nil then cap = math.huge end

        local upper = base < cap and base or cap
        local slice = upper - lower
        if slice > 0 then
            total = total + slice * (tonumber(bracket.rate) or 0)
        end

        lower = cap
        if base <= cap then break end
    end

    local assessed = floor(total + 0.5)
    local minimum = config and config.Tax and config.Tax.minAssessment or 0
    if assessed < minimum then return 0, 0.0 end

    return assessed, assessed / base
end
