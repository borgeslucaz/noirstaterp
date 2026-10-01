-- PATCH NOIR: multa do MDT vira pendência no banco (Renewed-Banking, pelo bgrz_core).
--
-- O ps-mdt original tirava do banco na hora e o dinheiro sumia (não ia para conta nenhuma).
-- Aqui a multa é uma fatura bloqueante: a pessoa paga no banco ou no app Faturas, o valor cai
-- na conta do departamento de quem multou, e até lá ela não saca nem transfere. Como é
-- pendência, o multado não precisa estar online.

---@param officerSrc number
---@param citizenId string
---@param amount integer
---@param reportId any
---@return boolean ok, string message
function NoirIssueMdtFine(officerSrc, citizenId, amount, reportId)
    if GetResourceState('bgrz_core') ~= 'started' then
        return false, 'Banco indisponível'
    end
    local job = exports.bgrz_core:GetJob(officerSrc)
    if not job or not job.name then
        return false, 'Departamento do policial não encontrado'
    end

    local officerName = ps.getPlayerName(officerSrc) or 'Policial'
    local description = reportId and ('Relatório #%s, por %s'):format(tostring(reportId), officerName)
        or ('Por %s'):format(officerName)

    local id, err = exports.bgrz_core:CreateInvoice({
        recipientCid = citizenId,
        issuerSource = officerSrc,
        issuerAccount = job.name,
        issuerLabel = job.label or job.name,
        kind = 'fine',
        title = 'Multa (MDT)',
        description = description,
        amount = amount,
    })
    if not id then
        return false, ('Multa não registrada no banco (%s)'):format(tostring(err))
    end
    return true, id
end
