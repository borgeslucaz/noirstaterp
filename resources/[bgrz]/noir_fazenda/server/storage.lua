NoirFazenda = NoirFazenda or {}
NoirFazenda.Storage = {}

-- Todo SQL do resource mora aqui (§12.2). As camadas de cima chamam funções de
-- domínio e não sabem que existe banco.
--
-- Nenhuma query deste arquivo toca tabela de outro resource. O ledger é
-- alimentado por evento, nunca lendo `bank_accounts_new` ou `players` (§12.1).

local Constants = NoirFazenda.Constants

-- Unix timestamp -> DATETIME UTC, sem depender do fuso da sessão MySQL.
--
-- `FROM_UNIXTIME` resolveria em uma palavra, mas converte usando `@@time_zone` da
-- conexão. Isso significa que a mesma linha gravaria hora diferente conforme a
-- configuração do MySQL -- e a comparação com o período, que é calculado em Lua,
-- passaria a depender de um fuso invisível. O offset explícito não tem esse risco.
local UTC = "DATE_ADD('1970-01-01 00:00:00', INTERVAL ? SECOND)"

local function rows(sql, parameters)
    return MySQL.query.await(sql, parameters or {}) or {}
end

-- SUM/COUNT voltam como DECIMAL, que o oxmysql entrega em float. `math.tointeger`
-- devolve nil para float não-inteiro, e o `or 0` seguinte zeraria o número sem
-- avisar. `floor` sobre `tonumber` não tem esse buraco.
local function toInt(value)
    return math.floor(tonumber(value) or 0)
end

--------------------------------------------------------------------------------
-- Ledger
--------------------------------------------------------------------------------

---Grava um lançamento. Idempotente pela unique em `event_id`.
---@param entry table
---@return boolean inserted false quando o lançamento já existia
function NoirFazenda.Storage.insertEntry(entry)
    -- `update` e não `insert` de propósito: o helper `insert` do oxmysql devolve
    -- `insertId`, e o que interessa aqui é se a linha entrou. Num INSERT IGNORE
    -- descartado os dois voltam 0 hoje, mas só `affectedRows` continua correto se
    -- a tabela algum dia perder o AUTO_INCREMENT.
    local affected = MySQL.update.await(([[
        INSERT IGNORE INTO noir_fazenda_ledger
            (event_id, subject_type, subject_id, direction, category, taxable,
             amount, counterparty, provider, source_resource, period_key,
             reference, metadata, occurred_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, %s)
    ]]):format(UTC), {
        entry.eventId,
        entry.subjectType,
        entry.subjectId,
        entry.direction,
        entry.category,
        entry.taxable and 1 or 0,
        entry.amount,
        entry.counterparty,
        entry.provider,
        entry.sourceResource,
        entry.periodKey,
        entry.reference,
        entry.metadata and json.encode(entry.metadata) or nil,
        entry.occurredAt,
    })
    return (tonumber(affected) or 0) > 0
end

---Base tributável e isenta de um sujeito num período.
---@return table totals
function NoirFazenda.Storage.periodTotals(subjectType, subjectId, periodKey)
    local result = rows([[
        SELECT
            COALESCE(SUM(CASE WHEN taxable = 1 THEN amount ELSE 0 END), 0) AS taxable_base,
            COALESCE(SUM(CASE WHEN taxable = 0 AND direction = 'in' THEN amount ELSE 0 END), 0) AS exempt_base,
            COALESCE(SUM(CASE WHEN direction = 'out' THEN amount ELSE 0 END), 0) AS outflow,
            COUNT(*) AS entry_count
        FROM noir_fazenda_ledger
        WHERE subject_type = ? AND subject_id = ? AND period_key = ?
    ]], { subjectType, subjectId, periodKey })[1]

    return {
        taxableBase = toInt(result and result.taxable_base),
        exemptBase = toInt(result and result.exempt_base),
        outflow = toInt(result and result.outflow),
        entryCount = toInt(result and result.entry_count),
    }
end

---Todos os sujeitos com movimentação tributável num período.
---Uma query em lote em vez de uma por jogador (§12.3).
---@return table[] subjects
function NoirFazenda.Storage.periodSubjects(periodKey, subjectType)
    return rows([[
        SELECT
            subject_id,
            COALESCE(SUM(CASE WHEN taxable = 1 THEN amount ELSE 0 END), 0) AS taxable_base,
            COALESCE(SUM(CASE WHEN taxable = 0 AND direction = 'in' THEN amount ELSE 0 END), 0) AS exempt_base,
            COUNT(*) AS entry_count
        FROM noir_fazenda_ledger
        WHERE period_key = ? AND subject_type = ?
        GROUP BY subject_id
        HAVING taxable_base > 0
    ]], { periodKey, subjectType })
end

---@return table[] entries
function NoirFazenda.Storage.statement(subjectType, subjectId, limit, periodKey)
    limit = math.min(math.max(toInt(limit) > 0 and toInt(limit) or 25, 1), 200)
    if periodKey then
        return rows(([[
            SELECT direction, category, taxable, amount, counterparty, period_key,
                   reference, UNIX_TIMESTAMP(occurred_at) AS occurred_at
            FROM noir_fazenda_ledger
            WHERE subject_type = ? AND subject_id = ? AND period_key = ?
            ORDER BY occurred_at DESC, id DESC
            LIMIT %d
        ]]):format(limit), { subjectType, subjectId, periodKey })
    end
    return rows(([[
        SELECT direction, category, taxable, amount, counterparty, period_key,
               reference, UNIX_TIMESTAMP(occurred_at) AS occurred_at
        FROM noir_fazenda_ledger
        WHERE subject_type = ? AND subject_id = ?
        ORDER BY occurred_at DESC, id DESC
        LIMIT %d
    ]]):format(limit), { subjectType, subjectId })
end

---@return integer removed
function NoirFazenda.Storage.pruneLedger(retentionDays)
    if not retentionDays or retentionDays <= 0 then return 0 end
    local affected = MySQL.update.await([[
        DELETE FROM noir_fazenda_ledger
        WHERE occurred_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL ? DAY)
    ]], { toInt(retentionDays) })
    return toInt(affected)
end

--------------------------------------------------------------------------------
-- Apuração
--------------------------------------------------------------------------------

---Grava ou atualiza a apuração de um sujeito num período.
---Reapurar um período recalcula base e imposto, mas nunca mexe em `paid`: quem
---já pagou não volta a dever por causa de um reprocessamento.
function NoirFazenda.Storage.upsertAssessment(record)
    MySQL.insert.await(([[
        INSERT INTO noir_fazenda_assessments
            (subject_type, subject_id, period_key, period_start, period_end,
             taxable_base, exempt_base, entry_count, assessed, effective_rate,
             status, due_at)
        VALUES (?, ?, ?, %s, %s, ?, ?, ?, ?, ?, ?, %s)
        ON DUPLICATE KEY UPDATE
            taxable_base = VALUES(taxable_base),
            exempt_base = VALUES(exempt_base),
            entry_count = VALUES(entry_count),
            assessed = VALUES(assessed),
            effective_rate = VALUES(effective_rate),
            status = IF(status IN ('paid', 'waived', 'void'), status, VALUES(status)),
            due_at = VALUES(due_at)
    ]]):format(UTC, UTC, UTC), {
        record.subjectType,
        record.subjectId,
        record.periodKey,
        record.periodStart,
        record.periodEnd,
        record.taxableBase,
        record.exemptBase,
        record.entryCount,
        record.assessed,
        record.effectiveRate,
        record.status,
        record.dueAt,
    })
end

---@return table? assessment
function NoirFazenda.Storage.getAssessment(subjectType, subjectId, periodKey)
    return rows([[
        SELECT id, subject_type, subject_id, period_key, taxable_base, exempt_base,
               entry_count, assessed, paid, effective_rate, status,
               UNIX_TIMESTAMP(period_start) AS period_start,
               UNIX_TIMESTAMP(period_end) AS period_end,
               UNIX_TIMESTAMP(due_at) AS due_at
        FROM noir_fazenda_assessments
        WHERE subject_type = ? AND subject_id = ? AND period_key = ?
        LIMIT 1
    ]], { subjectType, subjectId, periodKey })[1]
end

---Apurações com saldo em aberto. É a consulta que um sistema de cobrança
---(multa, MDT, mandado) usa para saber se alguém está devendo.
---@return table[] assessments
function NoirFazenda.Storage.openAssessments(subjectType, subjectId)
    return rows([[
        SELECT id, period_key, assessed, paid, status,
               UNIX_TIMESTAMP(due_at) AS due_at
        FROM noir_fazenda_assessments
        WHERE subject_type = ? AND subject_id = ?
          AND status IN ('assessed', 'overdue')
          AND assessed > paid
        ORDER BY period_key ASC
    ]], { subjectType, subjectId })
end

---@return integer affected
function NoirFazenda.Storage.markOverdue(nowTimestamp)
    local affected = MySQL.update.await(([[
        UPDATE noir_fazenda_assessments
        SET status = 'overdue'
        WHERE status = 'assessed' AND assessed > paid
          AND due_at IS NOT NULL AND due_at < %s
    ]]):format(UTC), { nowTimestamp })
    return toInt(affected)
end

---Aplica um pagamento e fecha a apuração quando quitada.
---
---Duas escritas, deliberadamente FORA de uma transação SQL.
---
---A versão em transação parecia mais segura e era pior: `MySQL.transaction` só
---devolve se o commit deu certo, não quantas linhas mudaram. Com isso o guard
---`assessed - paid >= ?` podia não casar -- e o INSERT do pagamento entrava
---assim mesmo, gravando um recibo de uma dívida que não foi abatida. O jogador
---pagaria e continuaria devendo, com um comprovante dizendo o contrário.
---
---Na ordem abaixo o UPDATE é a verdade e responde quantas linhas pegou; o INSERT
---é auditoria. Se o processo morrer entre os dois, o saldo devedor está certo e
---falta uma linha de histórico -- que é o lado certo para errar, e fica logado.
---@return boolean applied
function NoirFazenda.Storage.applyPayment(assessment, amount, method, actor, reference)
    local subjectType = assessment.subject_type or assessment.subjectType
    local subjectId = assessment.subject_id or assessment.subjectId

    local affected = MySQL.update.await([[
        UPDATE noir_fazenda_assessments
        SET paid = paid + ?,
            status = IF(paid + ? >= assessed, 'paid', status)
        WHERE id = ? AND assessed - paid >= ?
    ]], { amount, amount, assessment.id, amount })

    if toInt(affected) < 1 then return false end

    local ok, insertError = pcall(MySQL.insert.await, [[
        INSERT INTO noir_fazenda_payments
            (assessment_id, subject_type, subject_id, amount, method, reference, actor)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { assessment.id, subjectType, subjectId, amount, method, reference, actor })

    if not ok then
        NoirFazenda.Logger.error('payment_audit_missing', {
            assessmentId = assessment.id,
            subjectId = subjectId,
            amount = amount,
            error = tostring(insertError),
        })
    end

    return true
end

--------------------------------------------------------------------------------
-- Diagnóstico
--------------------------------------------------------------------------------

---@return table stats
function NoirFazenda.Storage.stats()
    local ledger = rows([[
        SELECT COUNT(*) AS entries,
               COUNT(DISTINCT subject_id) AS subjects,
               COALESCE(SUM(CASE WHEN taxable = 1 THEN amount ELSE 0 END), 0) AS taxable_total
        FROM noir_fazenda_ledger
    ]])[1] or {}
    local assessments = rows([[
        SELECT COUNT(*) AS total,
               COALESCE(SUM(assessed), 0) AS assessed_total,
               COALESCE(SUM(paid), 0) AS paid_total
        FROM noir_fazenda_assessments
    ]])[1] or {}

    return {
        ledgerEntries = toInt(ledger.entries),
        ledgerSubjects = toInt(ledger.subjects),
        taxableTotal = toInt(ledger.taxable_total),
        assessments = toInt(assessments.total),
        assessedTotal = toInt(assessments.assessed_total),
        paidTotal = toInt(assessments.paid_total),
    }
end
