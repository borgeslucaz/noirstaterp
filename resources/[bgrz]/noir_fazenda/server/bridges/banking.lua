NoirFazenda = NoirFazenda or {}
NoirFazenda.Bridges = NoirFazenda.Bridges or {}
NoirFazenda.Bridges.Banking = {}

-- O único ponto do resource que fala com o mundo bancário, e mesmo assim ele não
-- conhece o banco: escuta o evento neutro do `bgrz_core` e chama os exports do
-- bridge. O nome 'Renewed-Banking' não aparece em lugar nenhum do noir_fazenda.
--
-- É o §2.1 do SCRIPT_GOOD_PRACTICES, e aqui ele é literal: este servidor já trocou
-- de banco duas vezes.

local Constants = NoirFazenda.Constants
local Bridge = NoirFazenda.Bridges.Banking

AddEventHandler('bgrz_core:bankMovement', function(movement)
    local invoker = GetInvokingResource and GetInvokingResource()
    if invoker and invoker ~= 'bgrz_core' then return end
    NoirFazenda.Services.Ledger.recordBankMovement(movement)
end)

-- O banco carrega as contas DEPOIS de publicar "Started resource". Criar a conta
-- da Receita nessa janela dá Duplicate entry, porque o cache dele ainda está
-- vazio e ele não vê a conta que já existe no banco de dados.
--
-- Por isso a criação não acontece no nosso start: ela reage a este evento.
AddEventHandler('bgrz_core:bankingReady', function()
    local invoker = GetInvokingResource and GetInvokingResource()
    if invoker and invoker ~= 'bgrz_core' then return end
    if not NoirFazenda.Ready then return end
    NoirFazenda.Services.Treasury.ensureAccount()
end)

---Provider de par e com o cache de contas já carregado.
---@return boolean ready
function Bridge.isReady()
    if GetResourceState('bgrz_core') ~= 'started' then return false end
    local ok, ready = pcall(function()
        return exports.bgrz_core:IsBankingReady()
    end)
    return ok and ready == true
end

---@return boolean available
function Bridge.isAvailable()
    if GetResourceState('bgrz_core') ~= 'started' then return false end
    local ok, available = pcall(function()
        return exports.bgrz_core:IsBankingAvailable()
    end)
    return ok and available == true
end

---@param accountId string
---@param label string
---@return boolean ok
---@return string? errorCode
function Bridge.ensureAccount(accountId, label)
    if not Bridge.isReady() then return false, Constants.errors.bankingUnavailable end
    local ok, result, errorCode = pcall(function()
        return exports.bgrz_core:EnsureOrgAccount(accountId, label, 0)
    end)
    if not ok then return false, Constants.errors.bankingUnavailable end
    if result ~= true then return false, errorCode or Constants.errors.bankingUnavailable end
    return true
end

---@param accountId string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function Bridge.credit(accountId, amount)
    if not Bridge.isAvailable() then return false, Constants.errors.bankingUnavailable end
    local ok, result = pcall(function()
        return exports.bgrz_core:AddOrgMoney(accountId, amount)
    end)
    if not ok or result ~= true then return false, Constants.errors.bankingUnavailable end
    return true
end

---@param accountId string
---@return integer? balance
function Bridge.balance(accountId)
    if not Bridge.isAvailable() then return nil end
    local ok, result = pcall(function()
        return exports.bgrz_core:GetOrgMoney(accountId)
    end)
    if not ok then return nil end
    return tonumber(result)
end
