NoirFazenda = NoirFazenda or {}
NoirFazenda.Services = NoirFazenda.Services or {}
NoirFazenda.Services.Payment = {}

local Constants = NoirFazenda.Constants
local Storage = NoirFazenda.Storage
local Service = NoirFazenda.Services.Payment

-- Lock por cidadão. Todo await abaixo é uma janela em que um segundo clique do
-- mesmo jogador entraria no mesmo fluxo e pagaria duas vezes (§13.1).
local locks = {}

local function acquire(citizenId)
    if locks[citizenId] then return false end
    locks[citizenId] = true
    return true
end

local function release(citizenId)
    locks[citizenId] = nil
end

local function removeBankMoney(source, amount, reason)
    local ok, result = pcall(function()
        return exports.bgrz_core:RemoveMoney(source, 'bank', amount, reason)
    end)
    return ok and result == true
end

local function refundBankMoney(source, amount, reason)
    local ok, result = pcall(function()
        return exports.bgrz_core:AddMoney(source, 'bank', amount, reason)
    end)
    return ok and result == true
end

---Quita imposto devido, do período mais antigo para o mais novo.
---@param source number
---@param requestedAmount? integer nil = quitar tudo que estiver em aberto
---@return table result
function Service.settle(source, requestedAmount)
    if NoirFazenda.Config.Tax.collectionEnabled ~= true then
        return NoirFazenda.error(Constants.errors.collectionDisabled)
    end
    if type(source) ~= 'number' or source <= 0 then
        return NoirFazenda.error(Constants.errors.invalidArgument)
    end

    -- A identidade vem do runtime pelo bridge, nunca do payload (§7.1): o jogador
    -- pede para pagar, não diz de quem é a dívida.
    local ok, citizenId = pcall(function()
        return exports.bgrz_core:GetCitizenId(source)
    end)
    if not ok or type(citizenId) ~= 'string' or citizenId == '' then
        return NoirFazenda.error(Constants.errors.invalidSubject)
    end

    if not acquire(citizenId) then
        return NoirFazenda.error(Constants.errors.invalidArgument, { reason = 'busy' })
    end

    -- pcall obrigatório: sem ele, um erro lá dentro deixaria o lock preso e o
    -- jogador nunca mais conseguiria pagar imposto nesta sessão do servidor.
    local ok, result = pcall(Service.settleLocked, source, citizenId, requestedAmount)
    release(citizenId)

    if not ok then
        NoirFazenda.Logger.error('settle_failed', {
            citizenId = citizenId, error = tostring(result),
        })
        return NoirFazenda.error(Constants.errors.storageFailed)
    end
    return result
end

---@private
function Service.settleLocked(source, citizenId, requestedAmount)
    local assessments = Storage.openAssessments(Constants.subject.player, citizenId)
    if #assessments == 0 then return NoirFazenda.error(Constants.errors.nothingDue) end

    local outstanding = 0
    for i = 1, #assessments do
        outstanding = outstanding
            + math.floor((tonumber(assessments[i].assessed) or 0)
                - (tonumber(assessments[i].paid) or 0))
    end
    if outstanding <= 0 then return NoirFazenda.error(Constants.errors.nothingDue) end

    local amount = math.floor(tonumber(requestedAmount) or outstanding)
    if amount <= 0 then return NoirFazenda.error(Constants.errors.invalidAmount) end
    if amount > outstanding then amount = outstanding end

    local reason = ('noir_fazenda:imposto:pagamento:%s'):format(citizenId)

    -- Conferir o banco ANTES de tirar dinheiro de alguém. Depois do débito toda
    -- falha vira estorno, e estorno é onde erro de contabilidade nasce.
    if not NoirFazenda.Services.Treasury.ensureAccount() then
        return NoirFazenda.error(Constants.errors.bankingUnavailable)
    end

    if not removeBankMoney(source, amount, reason) then
        return NoirFazenda.error(Constants.errors.invalidAmount, { reason = 'insufficient_funds' })
    end

    -- Daqui em diante o dinheiro JÁ saiu do jogador.
    local remaining, applied = amount, {}
    for i = 1, #assessments do
        if remaining <= 0 then break end
        local row = assessments[i]
        local balance = math.floor((tonumber(row.assessed) or 0) - (tonumber(row.paid) or 0))
        if balance > 0 then
            local slice = math.min(balance, remaining)
            row.subjectType, row.subjectId = Constants.subject.player, citizenId
            -- `applyPayment` devolve false quando o guard do UPDATE não casou, ou
            -- seja, quando a dívida mudou entre a leitura e agora. Só descontamos
            -- de `remaining` o que realmente foi abatido -- o resto sobra e é
            -- devolvido ao jogador no fim.
            local ok, written = pcall(Storage.applyPayment, row, slice, 'bank', citizenId, reason)
            if ok and written then
                remaining = remaining - slice
                applied[#applied + 1] = { periodKey = row.period_key, amount = slice }
            else
                NoirFazenda.Logger.error('settle_apply_failed', {
                    citizenId = citizenId, periodKey = row.period_key, amount = slice,
                    error = ok and 'guard_mismatch' or tostring(written),
                })
            end
        end
    end

    local settled = amount - remaining

    -- Sobra quer dizer que tiramos do jogador mais do que conseguimos abater.
    -- Devolver é obrigatório: o contrário é o servidor ficando com dinheiro por
    -- uma dívida que não baixou.
    if remaining > 0 then
        refundBankMoney(source, remaining, reason .. ':estorno_parcial')
        NoirFazenda.Logger.warn('settle_partial_refund', {
            citizenId = citizenId, refunded = remaining,
        })
    end

    -- A Receita recebe o que foi ABATIDO, nunca o que foi debitado: creditar o
    -- valor cheio e estornar a sobra ao jogador criaria dinheiro do nada na conta
    -- do governo.
    --
    -- Este crédito vem depois das apurações de propósito. O débito do jogador e o
    -- abatimento da dívida já aconteceram, então a alternativa -- creditar antes e
    -- estornar tudo se algo falhar -- exigiria desfazer pagamento já aplicado. Se
    -- o crédito falhar aqui, o jogador está quite (que é o que importa para ele) e
    -- fica um buraco contábil, alto no log.
    if settled > 0 then
        local credited, creditError = NoirFazenda.Services.Treasury.credit(settled, citizenId)
        if not credited then
            NoirFazenda.Logger.error('treasury_credit_gap', {
                citizenId = citizenId, settled = settled, error = creditError,
            })
        end

        -- O pagamento entra no ledger como saída para o extrato da Receita contar
        -- a mesma história que o extrato do banco.
        NoirFazenda.Services.Ledger.write({
            eventId = ('noir_fazenda:pagamento:%s:%s'):format(citizenId, os.time()),
            subjectType = Constants.subject.player,
            subjectId = citizenId,
            direction = Constants.direction.outbound,
            category = Constants.category.taxPayment,
            taxable = false,
            amount = settled,
            counterparty = NoirFazenda.Config.Treasury.accountLabel,
            provider = Constants.resource,
            sourceResource = Constants.resource,
            occurredAt = os.time(),
        })
    end

    NoirFazenda.Logger.info('tax_settled', {
        citizenId = citizenId,
        paid = settled,
        unapplied = remaining,
        periods = applied,
    })

    return {
        ok = true,
        citizenId = citizenId,
        paid = settled,
        periods = applied,
        outstanding = outstanding - settled,
    }
end
