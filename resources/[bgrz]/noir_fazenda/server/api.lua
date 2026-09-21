NoirFazenda = NoirFazenda or {}

-- Superfície pública do resource. Tudo que outro script precisa saber sobre a
-- Receita passa por aqui; nada aqui expõe SQL nem estrutura interna.

local Constants = NoirFazenda.Constants
local Rules = NoirFazenda.Rules
local Services = NoirFazenda.Services

local function ready()
    return NoirFazenda.Ready == true
end

local function validCitizen(citizenId)
    return type(citizenId) == 'string' and citizenId ~= '' and #citizenId <= 64
end

---@return boolean
exports('IsReady', ready)

---Chave do período fiscal corrente.
---@return string periodKey
exports('CurrentPeriodKey', function()
    return Rules.periodKey(os.time(), NoirFazenda.Config)
end)

---Início e fim (unix) de um período.
---@param periodKey string
---@return integer? startTimestamp
---@return integer? endTimestamp
exports('PeriodBounds', function(periodKey)
    return Rules.periodBounds(periodKey, NoirFazenda.Config)
end)

---Declara renda que não passou pela interface do banco.
---
---O feed bancário só enxerga depósito, saque e transferência feitos no banco.
---Salário, pagamento de job e liquidação de atividade creditados direto na
---carteira são invisíveis para ele -- este export é como esses produtores
---entram no ledger.
---
---Forneça `eventId` sempre que houver um id estável da operação: é ele que
---impede que um retry vire base de imposto em dobro.
---@param payload { subjectId: string, amount: integer, subjectType?: 'player'|'org', category?: string, counterparty?: string, reference?: string, eventId?: string, occurredAt?: integer, taxable?: boolean, metadata?: table }
---@return boolean ok
---@return string? errorCode
exports('RecordIncome', function(payload)
    if not ready() then return false, Constants.errors.notReady end
    local caller = GetInvokingResource and GetInvokingResource() or nil
    return Services.Ledger.recordIncome(payload, caller)
end)

---Base tributável acumulada de um cidadão num período.
---@param citizenId string
---@param periodKey? string padrão: período corrente
---@return table result
exports('GetTaxableBase', function(citizenId, periodKey)
    if not ready() then return NoirFazenda.error(Constants.errors.notReady) end
    if not validCitizen(citizenId) then
        return NoirFazenda.error(Constants.errors.invalidSubject)
    end
    local totals = Services.Ledger.totals(Constants.subject.player, citizenId, periodKey)
    totals.ok = true
    totals.citizenId = citizenId
    return totals
end)

---Extrato do ledger de um cidadão.
---@param citizenId string
---@param limit? integer 1..200, padrão 25
---@param periodKey? string
---@return table result
exports('GetStatement', function(citizenId, limit, periodKey)
    if not ready() then return NoirFazenda.error(Constants.errors.notReady) end
    if not validCitizen(citizenId) then
        return NoirFazenda.error(Constants.errors.invalidSubject)
    end
    return {
        ok = true,
        citizenId = citizenId,
        entries = NoirFazenda.Storage.statement(
            Constants.subject.player, citizenId, limit, periodKey),
    }
end)

---Apuração de um cidadão num período fechado.
---@param citizenId string
---@param periodKey? string padrão: período anterior
---@return table result
exports('GetAssessment', function(citizenId, periodKey)
    if not ready() then return NoirFazenda.error(Constants.errors.notReady) end
    if not validCitizen(citizenId) then
        return NoirFazenda.error(Constants.errors.invalidSubject)
    end
    periodKey = periodKey or Rules.previousPeriodKey(os.time(), NoirFazenda.Config)
    local assessment = NoirFazenda.Storage.getAssessment(
        Constants.subject.player, citizenId, periodKey)
    if not assessment then
        return NoirFazenda.error(Constants.errors.invalidPeriod, { periodKey = periodKey })
    end
    assessment.ok = true
    return assessment
end)

---Quanto um cidadão deve de imposto, somando todos os períodos em aberto.
---
---É o gancho para a cobrança: a ideia é imposto vencido virar acusação no MDT e
---ser cobrado pela máquina de multa que já existe, em vez de uma cobrança
---paralela construída aqui.
---@param citizenId string
---@return table result
exports('GetOutstanding', function(citizenId)
    if not ready() then return NoirFazenda.error(Constants.errors.notReady) end
    return Services.Assessment.outstanding(citizenId)
end)

---Fecha um período e calcula as apurações.
---Com `Tax.collectionEnabled = false` o resultado é simulação: grava o número,
---não cria dívida.
---@param periodKey? string
---@return table summary
exports('ClosePeriod', function(periodKey)
    if not ready() then return NoirFazenda.error(Constants.errors.notReady) end
    return Services.Assessment.closePeriod(periodKey)
end)

---Quita imposto devido debitando da conta bancária do jogador.
---@param source number
---@param amount? integer nil = quitar tudo
---@return table result
exports('SettleTax', function(source, amount)
    if not ready() then return NoirFazenda.error(Constants.errors.notReady) end
    return Services.Payment.settle(source, amount)
end)

---@return integer? balance
exports('GetTreasuryBalance', function()
    if not ready() then return nil end
    return Services.Treasury.balance()
end)
