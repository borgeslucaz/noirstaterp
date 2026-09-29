NoirFazenda = NoirFazenda or {}
NoirFazenda.Services = NoirFazenda.Services or {}
NoirFazenda.Services.Assessment = {}

local Constants = NoirFazenda.Constants
local Rules = NoirFazenda.Rules
local Storage = NoirFazenda.Storage
local Service = NoirFazenda.Services.Assessment

---Fecha um período e calcula o imposto de cada sujeito com base tributável.
---
---Com `Tax.collectionEnabled = false` a apuração é gravada com status
---'simulated': o número existe, aparece no comando de admin e no export, mas não
---é dívida e ninguém é cobrado. É o modo em que o sistema nasce, de propósito --
---dá para rodar algumas semanas e ver a curva real de renda do servidor antes de
---escolher alíquota. Alíquota escolhida no escuro é como se quebra economia de RP.
---@param periodKey? string padrão: o período anterior ao corrente
---@return table summary
function Service.closePeriod(periodKey, options)
    options = options or {}
    local config = NoirFazenda.Config
    local now = os.time()

    periodKey = periodKey or Rules.previousPeriodKey(now, config)
    local periodStart, periodEnd = Rules.periodBounds(periodKey, config)
    if not periodStart then
        return NoirFazenda.error(Constants.errors.invalidPeriod, { periodKey = periodKey })
    end

    -- Fechar o período corrente contaria movimentação que ainda está entrando, e
    -- o total mudaria depois de cobrado.
    if periodEnd > now and not options.force then
        return NoirFazenda.error(Constants.errors.invalidPeriod, {
            periodKey = periodKey,
            reason = 'period_still_open',
        })
    end

    local collecting = config.Tax.collectionEnabled == true
    local status = collecting and Constants.status.assessed or Constants.status.simulated
    local dueAt = collecting
        and (periodEnd + math.floor((config.Tax.dueAfterHours or 0) * 3600))
        or nil

    local subjects = Storage.periodSubjects(periodKey, Constants.subject.player)
    local closed, assessedTotal = 0, 0

    for i = 1, #subjects do
        local subject = subjects[i]
        local taxableBase = math.floor(tonumber(subject.taxable_base) or 0)
        local assessed, effectiveRate = Rules.computeTax(taxableBase, config)

        local ok, writeError = pcall(Storage.upsertAssessment, {
            subjectType = Constants.subject.player,
            subjectId = subject.subject_id,
            periodKey = periodKey,
            periodStart = periodStart,
            periodEnd = periodEnd,
            taxableBase = taxableBase,
            exemptBase = math.floor(tonumber(subject.exempt_base) or 0),
            entryCount = math.floor(tonumber(subject.entry_count) or 0),
            assessed = assessed,
            effectiveRate = effectiveRate,
            -- Quem apurou zero não vira devedor, mesmo com a cobrança ligada.
            status = assessed > 0 and status or Constants.status.simulated,
            dueAt = assessed > 0 and dueAt or nil,
        })

        if ok then
            closed = closed + 1
            assessedTotal = assessedTotal + assessed
        else
            NoirFazenda.Logger.error('assessment_write_failed', {
                subjectId = subject.subject_id,
                periodKey = periodKey,
                error = tostring(writeError),
            })
        end
    end

    local summary = {
        ok = true,
        periodKey = periodKey,
        periodStart = periodStart,
        periodEnd = periodEnd,
        subjects = closed,
        assessedTotal = assessedTotal,
        collecting = collecting,
        status = status,
    }
    NoirFazenda.Logger.info('period_closed', summary)
    return summary
end

---Marca como vencidas as apurações que passaram do prazo.
---@return integer affected
function Service.refreshOverdue()
    if NoirFazenda.Config.Tax.collectionEnabled ~= true then return 0 end
    local ok, affected = pcall(Storage.markOverdue, os.time())
    if not ok then
        NoirFazenda.Logger.error('overdue_refresh_failed', { error = tostring(affected) })
        return 0
    end
    if affected > 0 then
        NoirFazenda.Logger.info('assessments_overdue', { affected = affected })
    end
    return affected
end

---Total em aberto de um cidadão.
---
---É esta função que um sistema de cobrança consome. A intenção é que imposto não
---pago vire acusação no MDT e seja cobrado pela máquina de multa que JÁ existe --
---não por uma cobrança paralela construída aqui.
---@param citizenId string
---@return table outstanding
function Service.outstanding(citizenId)
    if type(citizenId) ~= 'string' or citizenId == '' then
        return NoirFazenda.error(Constants.errors.invalidSubject)
    end

    local assessments = Storage.openAssessments(Constants.subject.player, citizenId)
    local total, overdue = 0, 0
    for i = 1, #assessments do
        local row = assessments[i]
        local balance = math.floor((tonumber(row.assessed) or 0) - (tonumber(row.paid) or 0))
        total = total + balance
        if row.status == Constants.status.overdue then overdue = overdue + balance end
    end

    return {
        ok = true,
        citizenId = citizenId,
        total = total,
        overdue = overdue,
        periods = assessments,
    }
end
