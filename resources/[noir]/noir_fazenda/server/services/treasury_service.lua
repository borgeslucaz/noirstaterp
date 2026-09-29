NoirFazenda = NoirFazenda or {}
NoirFazenda.Services = NoirFazenda.Services or {}
NoirFazenda.Services.Treasury = {}

local Constants = NoirFazenda.Constants
local Bridge = NoirFazenda.Bridges.Banking
local Service = NoirFazenda.Services.Treasury

local ensured = false

---Garante a conta de organização que recebe a arrecadação.
---
---Não existe job de governo no qbx_core, e não vamos criar um: o banco expõe
---criação de conta de organização, então a Receita tem conta sem que nenhum
---resource de core seja editado (§25, "editar qbx_core para atender um único
---script" é anti-padrão).
---@return boolean ok
---@return string? errorCode
function Service.ensureAccount()
    local treasury = NoirFazenda.Config.Treasury
    if ensured then return true end

    local ok, errorCode = Bridge.ensureAccount(treasury.accountId, treasury.accountLabel)
    if not ok then
        NoirFazenda.Logger.warn('treasury_account_pending', {
            accountId = treasury.accountId,
            error = errorCode,
        })
        return false, errorCode
    end

    ensured = true
    NoirFazenda.Logger.info('treasury_account_ready', {
        accountId = treasury.accountId,
        balance = Bridge.balance(treasury.accountId),
    })
    return true
end

---@return boolean ok
---@return string? errorCode
function Service.credit(amount, reference)
    local treasury = NoirFazenda.Config.Treasury
    if not treasury.creditCollections then return true end
    if type(amount) ~= 'number' or amount <= 0 then return false, Constants.errors.invalidAmount end

    if not ensured and not Service.ensureAccount() then
        return false, Constants.errors.bankingUnavailable
    end

    local ok, errorCode = Bridge.credit(treasury.accountId, math.floor(amount))
    if not ok then
        NoirFazenda.Logger.error('treasury_credit_failed', {
            amount = amount, reference = reference, error = errorCode,
        })
        return false, errorCode
    end
    return true
end

---@return boolean ensured
function Service.isEnsured()
    return ensured
end

---@return integer? balance
function Service.balance()
    return Bridge.balance(NoirFazenda.Config.Treasury.accountId)
end

-- Quem dispara a criação é o evento de prontidão do banco, assinado em
-- server/bridges/banking.lua. Não há laço esperando nem tentativa no nosso start:
-- o banco avisa quando o cache de contas dele existe, e é só aí que criar conta
-- tem significado.
AddEventHandler('onResourceStop', function(resourceName)
    if GetResourceState('bgrz_core') ~= 'started' then return end
    local ok, provider = pcall(function() return exports.bgrz_core:GetBankingProvider() end)
    if ok and resourceName == provider then ensured = false end
end)
