-- Rode de dentro de resources/[bgrz]/noir_fazenda:
--   lua5.4 tests/integration/feed_spec.lua
--
-- Prova a corrente inteira sem servidor de pé:
--   Renewed-Banking:noir:transaction  ->  bgrz_core (adapter)
--     ->  bgrz_core:bankMovement      ->  noir_fazenda (bridge)
--       ->  ledger service            ->  storage
--
-- É o teste que importa porque os dois resources conversam por evento: cada lado
-- pode estar certo sozinho e a ponta não encaixar.

local Test = dofile('tests/testlib.lua')

--------------------------------------------------------------------------------
-- Stubs do runtime CFX
--------------------------------------------------------------------------------

local handlers = {}
local invokingResource = nil

-- No CFX, `GetInvokingResource()` dentro de um handler devolve quem disparou
-- AQUELE evento -- não quem começou a cadeia. Um stub que devolvesse sempre a
-- origem faria o teste reprovar código correto, então o dono de cada evento é
-- explícito aqui.
local eventOwner = {
    ['Renewed-Banking:noir:transaction'] = 'Renewed-Banking',
    ['Renewed-Banking:noir:ready'] = 'Renewed-Banking',
    ['bgrz_core:bankMovement'] = 'bgrz_core',
    ['bgrz_core:bankingReady'] = 'bgrz_core',
}
local spoofedInvoker = nil

function AddEventHandler(name, callback)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = callback
end

function TriggerEvent(name, ...)
    local previous = invokingResource
    invokingResource = spoofedInvoker or eventOwner[name]
    spoofedInvoker = nil
    for _, callback in ipairs(handlers[name] or {}) do callback(...) end
    invokingResource = previous
end

function GetInvokingResource() return invokingResource end
function GetCurrentResourceName() return 'noir_fazenda' end
function GetResourceState() return 'started' end
function StopResource() end

local written = {}
MySQL = {
    update = { await = function(_, parameters)
        written[#written + 1] = parameters
        return 1
    end },
    insert = { await = function() return 1 end },
    query = { await = function() return {} end },
    scalar = { await = function() return 1 end },
    ready = function() end,
}

json = { encode = function() return '{}' end }

-- `exports` no CFX é chamável (registrar) e indexável (consumir). Precisa das
-- duas caras aqui: os dois resources registram exports ao carregar.
local registered = {}

-- Banco falso que reproduz a parte que importa do Renewed: `cachedAccounts` só
-- existe depois da carga, e `CreateJobAccount` chamado antes disso não vê a conta
-- que já está no banco de dados -- tenta INSERT e estoura em Duplicate entry.
local bank = { loaded = false, rows = {}, accounts = {}, createCalls = 0 }

function bank.load()
    bank.loaded = true
    for id, amount in pairs(bank.rows) do bank.accounts[id] = amount end
end

local bankExports = {
    CreateJobAccount = function(_, job, initialBalance)
        bank.createCalls = bank.createCalls + 1
        if bank.accounts[job.name] then return { id = job.name } end
        if bank.rows[job.name] then
            -- é exatamente o que o Renewed faz: MySQL.insert sem await devolve nil,
            -- `success` é nil e ele levanta error()
            error('Database error: nil')
        end
        bank.rows[job.name] = initialBalance or 0
        bank.accounts[job.name] = initialBalance or 0
        return { id = job.name }
    end,
    getAccountMoney = function(_, id) return bank.accounts[id] or false end,
    addAccountMoney = function(_, id, amount)
        if not bank.accounts[id] then return false end
        bank.accounts[id] = bank.accounts[id] + amount
        return true
    end,
}

local bgrzExports = setmetatable({}, {
    __index = function(_, name)
        return function(_self, ...)
            if registered[name] then return registered[name](...) end
        end
    end,
})

exports = setmetatable({}, {
    __call = function(_, name, callback) registered[name] = callback end,
    __index = function(_, resourceName)
        if resourceName == 'Renewed-Banking' then return bankExports end
        return bgrzExports
    end,
})

--------------------------------------------------------------------------------
-- Carrega os dois lados
--------------------------------------------------------------------------------

local BGRZ_PATH = '../bgrz_core/'
BGRZ = {}
dofile(BGRZ_PATH .. 'shared/config.lua')
dofile(BGRZ_PATH .. 'shared/provider.lua')
dofile(BGRZ_PATH .. 'server/banking.lua')

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('shared/rules.lua')
dofile('server/logger.lua')
dofile('server/storage.lua')
dofile('server/bridges/banking.lua')
dofile('server/services/ledger_service.lua')
dofile('server/services/treasury_service.lua')

NoirFazenda.Ready = true

--------------------------------------------------------------------------------
-- Cenários
--------------------------------------------------------------------------------

local function fireBank(account, kind, transaction, linkedId)
    written = {}
    TriggerEvent('Renewed-Banking:noir:transaction', account, kind, transaction, linkedId)
end

local function lastRow()
    local row = written[#written]
    if not row then return nil end
    -- ordem dos parâmetros do INSERT em storage.lua
    return {
        eventId = row[1], subjectType = row[2], subjectId = row[3],
        direction = row[4], category = row[5], taxable = row[6],
        amount = row[7], counterparty = row[8], provider = row[9],
        periodKey = row[11], reference = row[12], occurredAt = row[14],
    }
end

local now = 1789916400 -- 2026-09-20 15:00 UTC (domingo; semana fiscal abre em 14/09)

-- 1. depósito do próprio dinheiro: chega como 'deposit', SEM perna ligada
fireBank('NOIR1', 'player', {
    trans_id = 'tx1', trans_type = 'deposit', amount = 9000,
    issuer = 'Fulano', receiver = 'Fulano', title = 't', message = 'm', time = now,
}, nil)
local row = lastRow()
Test.truthy(row, '1. depósito próprio chegou ao storage')
Test.equal(row.category, 'deposito_proprio', '1. classificado como depósito próprio')
Test.equal(row.taxable, 0, '1. NÃO tributado -- é o mesmo dinheiro mudando de bolso')
Test.equal(row.subjectId, 'NOIR1', '1. sujeito certo')
Test.equal(row.amount, 9000, '1. valor certo')

-- 2. transferência recebida: chega como 'deposit' COM a perna da origem
fireBank('NOIR1', 'player', {
    trans_id = 'tx2', trans_type = 'deposit', amount = 40000,
    issuer = 'Sicrano', receiver = 'Fulano', title = 't', message = 'm', time = now,
}, 'tx2')
row = lastRow()
Test.equal(row.category, 'transferencia_recebida', '2. classificado como transferência recebida')
Test.equal(row.taxable, 1, '2. TRIBUTADO -- alguém pagou o sujeito')
Test.equal(row.counterparty, 'Sicrano', '2. contraparte é quem pagou')

-- 3. a perna de saída da MESMA transferência
fireBank('NOIR2', 'player', {
    trans_id = 'tx2', trans_type = 'withdraw', amount = 40000,
    issuer = 'Sicrano', receiver = 'Fulano', title = 't', message = 'm', time = now,
}, nil)
local outRow = lastRow()
Test.equal(outRow.direction, 'out', '3. saída')
Test.equal(outRow.taxable, 0, '3. saída não é tributada -- tributamos só entradas')

-- 4. as duas pernas precisam de eventId distinto, senão a segunda é descartada
--    como duplicata e quem recebeu nunca é tributado
fireBank('NOIR1', 'player', {
    trans_id = 'tx2', trans_type = 'deposit', amount = 40000,
    issuer = 'Sicrano', receiver = 'Fulano', title = 't', message = 'm', time = now,
}, 'tx2')
Test.truthy(lastRow().eventId ~= outRow.eventId, '4. pernas da mesma transferência não colidem')

-- 5. conta de organização entra, mas nunca tributada
fireBank('police', 'org', {
    trans_id = 'tx3', trans_type = 'deposit', amount = 5000,
    issuer = 'Fulano', receiver = 'police', title = 't', message = 'm', time = now,
}, 'tx3')
row = lastRow()
Test.equal(row.subjectType, 'org', '5. organização registrada')
Test.equal(row.taxable, 0, '5. organização não é pessoa física')

-- 6. o período é calculado na escrita, no fuso da config (-3)
Test.equal(row.periodKey, 'W2026-09-14', '6. período gravado junto do lançamento')

-- 7. payload lixo não derruba nem grava
for _, bad in ipairs({
    { account = 'NOIR1', kind = 'player', tx = { trans_type = 'deposit', amount = 100 } },
    { account = 'NOIR1', kind = 'player', tx = { trans_id = 'x', trans_type = 'foo', amount = 100 } },
    { account = 'NOIR1', kind = 'player', tx = { trans_id = 'x', trans_type = 'deposit', amount = 0 } },
    { account = '',      kind = 'player', tx = { trans_id = 'x', trans_type = 'deposit', amount = 10 } },
    { account = 'NOIR1', kind = 'alien',  tx = { trans_id = 'x', trans_type = 'deposit', amount = 10 } },
    { account = 'NOIR1', kind = 'player', tx = 'nem é tabela' },
}) do
    fireBank(bad.account, bad.kind, bad.tx, nil)
    Test.equal(#written, 0, '7. payload inválido não vira lançamento')
end

-- 8. evento vindo de outro resource é ignorado: o feed tem dono
written = {}
spoofedInvoker = 'algum_resource_qualquer'
TriggerEvent('Renewed-Banking:noir:transaction', 'NOIR1', 'player', {
    trans_id = 'tx9', trans_type = 'deposit', amount = 999999, time = now,
}, 'tx9')
Test.equal(#written, 0, '8. só o provider configurado alimenta o feed')

--------------------------------------------------------------------------------
-- Prontidão do banco
--------------------------------------------------------------------------------
--
-- Regressão do bug que derrubou a criação da conta da Receita em produção:
-- "Started resource Renewed-Banking" é publicado ANTES de o banco carregar as
-- contas. Criar conta nessa janela bate em Duplicate entry, porque o cache dele
-- ainda está vazio e ele não enxerga a linha que já existe no banco de dados.

-- a conta já existe no banco de dados, de um boot anterior
bank.rows['fazenda'] = 0

Test.falsy(NoirFazenda.Bridges.Banking.isReady(), '9. banco não está pronto antes de carregar')

-- tentar criar agora é o erro que aconteceu de verdade
local tooEarly = NoirFazenda.Services.Treasury.ensureAccount()
Test.falsy(tooEarly, '9. criação antes da carga é recusada, não estoura')
Test.equal(bank.createCalls, 0, '9. nem chegou a chamar o banco')

-- o banco termina a carga e avisa
bank.load()
TriggerEvent('Renewed-Banking:noir:ready')

Test.truthy(NoirFazenda.Bridges.Banking.isReady(), '10. prontidão propagou até o consumidor')
Test.truthy(NoirFazenda.Services.Treasury.isEnsured(), '10. conta garantida ao receber o aviso')
Test.equal(bank.createCalls, 1, '10. chamou o banco uma vez')
Test.equal(bank.accounts['fazenda'], 0, '10. reusou a conta existente em vez de duplicar')

-- e o crédito, que depende da conta, funciona
Test.truthy(NoirFazenda.Services.Treasury.credit(500, 'teste'), '11. crédito na Receita')
Test.equal(NoirFazenda.Services.Treasury.balance(), 500, '11. saldo subiu')

-- 12. restart do banco: a prontidão precisa cair junto, senão o consumidor acha
--     que a conta continua garantida enquanto o cache do banco já morreu
TriggerEvent('onResourceStop', 'Renewed-Banking')
bank.loaded, bank.rows, bank.accounts, bank.createCalls = false, {}, {}, 0

Test.falsy(NoirFazenda.Bridges.Banking.isReady(), '12. prontidão caiu com o banco')
Test.falsy(NoirFazenda.Services.Treasury.isEnsured(), '12. conta deixou de ser dada como garantida')

-- 13. primeiro boot da vida: conta não existe em lugar nenhum e é criada
bank.load()
TriggerEvent('Renewed-Banking:noir:ready')
Test.equal(bank.accounts['fazenda'], 0, '13. primeiro boot cria a conta')
Test.equal(bank.createCalls, 1, '13. uma única chamada de criação')

print('feed_spec: ok')
