BGRZ = BGRZ or {}
BGRZ.Banking = BGRZ.Banking or {}

-- Adapter de banking.
--
-- O §12.1 do SCRIPT_GOOD_PRACTICES coloca banking na mesma categoria de Qbox,
-- inventário e veículos: o consumidor não fala com o provider, fala com a ponte.
-- Isso não é zelo teórico aqui -- o banco deste servidor já foi trocado duas vezes
-- (Renewed -> muhaddil -> Renewed). Cada consumidor que conhecesse o nome do
-- provider teria quebrado nas duas.
--
-- O que este arquivo faz:
--   1. escuta o feed cru do provider e reemite um evento neutro,
--      `bgrz_core:bankMovement`, com um payload que não menciona o provider;
--   2. expõe as operações de conta de organização que os consumidores precisam.
--
-- O que ele NÃO faz: decidir o que é renda, o que é isento ou o que é tributável.
-- Isso é domínio, e domínio mora no resource consumidor (§2.3, §27.1).

local RENEWED = 'Renewed-Banking'

local function isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

---@return string? resource
local function provider()
    return BGRZ.Provider.name('banking')
end

---@return boolean available
function BGRZ.Banking.IsAvailable()
    return BGRZ.Provider.isAvailable('banking')
end

---Nome do provider de banking em uso, para log e diagnóstico.
---@return string? resource
function BGRZ.Banking.GetProvider()
    return provider()
end

--------------------------------------------------------------------------------
-- Feed normalizado
--------------------------------------------------------------------------------

---@class BGRZBankMovement
---@field provider string          resource que originou o movimento
---@field transactionId string     id da transação no provider
---@field linkedTransactionId? string  id da perna oposta, quando o movimento faz parte de uma transferência
---@field isTransferLeg boolean    true quando o movimento é a perna de uma transferência entre contas
---@field subjectType 'player'|'org'
---@field subjectId string         citizenid, ou id da conta de organização
---@field direction 'in'|'out'
---@field amount integer           sempre positivo
---@field issuer string
---@field receiver string
---@field title string
---@field message string
---@field occurredAt integer       unix timestamp

local function emit(movement)
    TriggerEvent('bgrz_core:bankMovement', movement)
end

-- Tradução das particularidades do Renewed-Banking. Toda esquisitice do provider
-- termina aqui e não vaza para o consumidor:
--
--   * `trans_type` é 'deposit'/'withdraw' do ponto de vista DA CONTA, então vira
--     direction 'in'/'out';
--   * transferência gera DUAS chamadas com o mesmo `trans_id`; a segunda perna
--     (a que credita) recebe o id da primeira como argumento. É por isso que
--     `linkedTransactionId` existe: sem ele não há como distinguir "alguém me
--     pagou" de "eu depositei meu próprio dinheiro em espécie", porque as duas
--     coisas chegam como 'deposit'.
local directionByTransType = {
    deposit = 'in',
    withdraw = 'out',
}

local function onRenewedTransaction(accountId, accountKind, transaction, linkedTransactionId)
    local invoker = GetInvokingResource and GetInvokingResource()
    if invoker and invoker ~= RENEWED then return end

    if type(accountId) ~= 'string' or accountId == '' then return end
    if accountKind ~= 'player' and accountKind ~= 'org' then return end
    if type(transaction) ~= 'table' then return end

    local direction = directionByTransType[transaction.trans_type]
    if not direction then return end

    local amount = tonumber(transaction.amount)
    if not isFinite(amount) then return end
    amount = math.floor(math.abs(amount) + 0.5)
    if amount <= 0 then return end

    local transactionId = transaction.trans_id
    if type(transactionId) ~= 'string' or transactionId == '' then return end

    local occurredAt = tonumber(transaction.time)
    if not isFinite(occurredAt) or occurredAt <= 0 then occurredAt = os.time() end

    emit({
        provider = RENEWED,
        transactionId = transactionId,
        linkedTransactionId = type(linkedTransactionId) == 'string'
            and linkedTransactionId ~= '' and linkedTransactionId or nil,
        isTransferLeg = type(linkedTransactionId) == 'string' and linkedTransactionId ~= '',
        subjectType = accountKind,
        subjectId = accountId,
        direction = direction,
        amount = amount,
        issuer = tostring(transaction.issuer or ''),
        receiver = tostring(transaction.receiver or ''),
        title = tostring(transaction.title or ''),
        message = tostring(transaction.message or ''),
        occurredAt = math.floor(occurredAt),
    })
end

-- Evento local: o provider roda no mesmo servidor, então `AddEventHandler` basta
-- e nada disso vira tráfego de rede (§8.1).
AddEventHandler('Renewed-Banking:noir:transaction', onRenewedTransaction)

--------------------------------------------------------------------------------
-- Prontidão
--------------------------------------------------------------------------------

-- "Started resource <banco>" NÃO significa que dá para criar conta.
--
-- O Renewed publica o start, espera meio segundo e só então carrega as contas do
-- banco de dados. Entre uma coisa e outra, o cache dele está vazio: quem chamar
-- `CreateJobAccount` nessa janela não acha a conta existente, tenta INSERT e leva
-- Duplicate entry -- que o Renewed transforma em `error()` e derruba a chamada.
--
-- Por isso prontidão é um sinal próprio, emitido no fim da carga dele.
local ready = false

---@return boolean ready
function BGRZ.Banking.IsReady()
    return ready and BGRZ.Provider.isAvailable('banking')
end

AddEventHandler('Renewed-Banking:noir:ready', function()
    local invoker = GetInvokingResource and GetInvokingResource()
    if invoker and invoker ~= RENEWED then return end
    ready = true
    TriggerEvent('bgrz_core:bankingReady')
end)

-- Se o provider cair, a prontidão cai junto: o cache dele morre com o resource.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == provider() then ready = false end
end)

--------------------------------------------------------------------------------
-- Contas de organização
--------------------------------------------------------------------------------

local function callProvider(method, ...)
    local resource = provider()
    if not BGRZ.Provider.isAvailable('banking') then return false, 'provider_unavailable' end

    local called, result = pcall(function(...)
        return exports[resource][method](exports[resource], ...)
    end, ...)
    if not called then return false, 'provider_unavailable' end
    return true, result
end

---Garante que uma conta de organização exista, criando-a se preciso.
---Idempotente: chamar de novo devolve a conta existente sem zerar saldo.
---@param accountId string
---@param label string
---@param initialBalance? integer
---@return boolean ok
---@return string? errorCode
function BGRZ.Banking.EnsureOrgAccount(accountId, label, initialBalance)
    if type(accountId) ~= 'string' or accountId == '' or #accountId > 64 then
        return false, 'invalid_account'
    end
    if type(label) ~= 'string' or label == '' then return false, 'invalid_label' end
    if initialBalance ~= nil and (not isFinite(initialBalance) or initialBalance < 0) then
        return false, 'invalid_amount'
    end

    local called, account = callProvider('CreateJobAccount',
        { name = accountId, label = label }, math.floor(initialBalance or 0))
    if not called then return false, account end
    if type(account) ~= 'table' then return false, 'operation_failed' end
    return true
end

---@param accountId string
---@return integer? balance
---@return string? errorCode
function BGRZ.Banking.GetOrgMoney(accountId)
    if type(accountId) ~= 'string' or accountId == '' then return nil, 'invalid_account' end
    local called, balance = callProvider('getAccountMoney', accountId)
    if not called then return nil, balance end
    if not isFinite(balance) then return nil, 'invalid_account' end
    return math.floor(balance)
end

---@param accountId string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function BGRZ.Banking.AddOrgMoney(accountId, amount)
    if type(accountId) ~= 'string' or accountId == '' then return false, 'invalid_account' end
    if not isFinite(amount) or amount <= 0 then return false, 'invalid_amount' end

    local called, ok = callProvider('addAccountMoney', accountId, math.floor(amount))
    if not called then return false, ok end
    if ok ~= true then return false, 'invalid_account' end
    return true
end

---@param accountId string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function BGRZ.Banking.RemoveOrgMoney(accountId, amount)
    if type(accountId) ~= 'string' or accountId == '' then return false, 'invalid_account' end
    if not isFinite(amount) or amount <= 0 then return false, 'invalid_amount' end

    local called, ok = callProvider('removeAccountMoney', accountId, math.floor(amount))
    if not called then return false, ok end
    if ok ~= true then return false, 'insufficient_funds' end
    return true
end

---Registra um lançamento no extrato de uma conta pelo provider. Não move saldo:
---quem move saldo é `AddOrgMoney`/`RemoveOrgMoney`. Serve para o extrato do
---jogador mostrar a mesma história que o ledger de quem consome este bridge.
---@param accountId string
---@param entry { title: string, amount: integer, message: string, issuer: string, receiver: string, direction: 'in'|'out' }
---@return boolean ok
---@return string? errorCode
function BGRZ.Banking.RecordStatementEntry(accountId, entry)
    if type(accountId) ~= 'string' or accountId == '' then return false, 'invalid_account' end
    if type(entry) ~= 'table' then return false, 'invalid_entry' end
    if not isFinite(entry.amount) or entry.amount <= 0 then return false, 'invalid_amount' end
    local transType = entry.direction == 'out' and 'withdraw' or 'deposit'

    local called, result = callProvider('handleTransaction',
        accountId,
        tostring(entry.title or ''),
        math.floor(entry.amount),
        tostring(entry.message or ''),
        tostring(entry.issuer or ''),
        tostring(entry.receiver or ''),
        transType)
    if not called then return false, result end
    if type(result) ~= 'table' then return false, 'operation_failed' end
    return true
end

exports('IsBankingAvailable', BGRZ.Banking.IsAvailable)
exports('IsBankingReady', BGRZ.Banking.IsReady)
exports('GetBankingProvider', BGRZ.Banking.GetProvider)
exports('EnsureOrgAccount', BGRZ.Banking.EnsureOrgAccount)
exports('GetOrgMoney', BGRZ.Banking.GetOrgMoney)
exports('AddOrgMoney', BGRZ.Banking.AddOrgMoney)
exports('RemoveOrgMoney', BGRZ.Banking.RemoveOrgMoney)
exports('RecordStatementEntry', BGRZ.Banking.RecordStatementEntry)
