-- Rode de dentro de resources/[bgrz]/noir_fazenda:
--   lua5.4 tests/unit/rules_spec.lua

local Test = dofile('tests/testlib.lua')

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('shared/rules.lua')

local Rules = NoirFazenda.Rules
local Constants = NoirFazenda.Constants

local function config(overrides)
    local base = {
        Period = { mode = 'weekly', timezoneOffsetHours = -3 },
        Ledger = { minimumAmount = 1, maximumAmount = 100000000, recordNonTaxable = true, recordOrganizations = true },
        Tax = {
            minAssessment = 50,
            brackets = {
                { upTo = 25000, rate = 0.00 },
                { upTo = 100000, rate = 0.05 },
                { upTo = false, rate = 0.12 },
            },
        },
    }
    for key, value in pairs(overrides or {}) do base[key] = value end
    return base
end

--------------------------------------------------------------------------------
-- Calendário
--------------------------------------------------------------------------------

-- Ida e volta em datas conhecidas: se a aritmética estiver errada, todo período
-- fiscal do servidor sai errado junto.
Test.equal(Rules.daysFromCivil(1970, 1, 1), 0, 'epoch')
Test.equal(Rules.daysFromCivil(2000, 3, 1), 11017, '2000-03-01')
Test.equal(Rules.daysFromCivil(2026, 9, 20), 20716, '2026-09-20')

local y, m, d = Rules.civilFromDays(20716)
Test.equal(('%d-%d-%d'):format(y, m, d), '2026-9-20', 'civilFromDays volta a mesma data')

for _, day in ipairs({ -1, 0, 1, 10000, 18000, 20716, 25000 }) do
    local yy, mm, dd = Rules.civilFromDays(day)
    Test.equal(Rules.daysFromCivil(yy, mm, dd), day, 'roundtrip dia ' .. day)
end

-- 2026-09-20 é um domingo; a semana fiscal dele abre na segunda, 2026-09-14.
local sunday = 20716 * 86400 + 12 * 3600
Test.equal(Rules.periodKey(sunday, config()), 'W2026-09-14', 'domingo cai na semana da segunda anterior')

-- Meia-noite de Brasília é 03:00 UTC. Às 02:00 UTC de segunda ainda é domingo
-- para o jogador, então o lançamento pertence à semana que está terminando.
local mondayUtc = Rules.daysFromCivil(2026, 9, 21) * 86400 + 2 * 3600
Test.equal(Rules.periodKey(mondayUtc, config()), 'W2026-09-14',
    '02:00 UTC de segunda ainda é a semana anterior no fuso do jogador')
Test.equal(Rules.periodKey(mondayUtc + 2 * 3600, config()), 'W2026-09-21',
    '04:00 UTC de segunda já abriu a semana nova')

local dailyConfig = config({ Period = { mode = 'daily', timezoneOffsetHours = -3 } })
Test.equal(Rules.periodKey(sunday, dailyConfig), 'D2026-09-20', 'modo diário')

-- A chave carrega o modo, então bounds não depende da config vigente.
local startTimestamp, endTimestamp = Rules.periodBounds('W2026-09-14', config())
Test.equal(endTimestamp - startTimestamp, 7 * 86400, 'semana tem 7 dias')
Test.equal(Rules.periodKey(startTimestamp, config()), 'W2026-09-14', 'início pertence ao próprio período')
Test.equal(Rules.periodKey(endTimestamp - 1, config()), 'W2026-09-14', 'último segundo ainda é do período')
Test.equal(Rules.periodKey(endTimestamp, config()), 'W2026-09-21', 'fim é exclusivo')

local dailyStart, dailyEnd = Rules.periodBounds('D2026-09-20', config())
Test.equal(dailyEnd - dailyStart, 86400, 'chave diária tem 1 dia mesmo com config semanal')

Test.falsy(Rules.periodBounds('lixo', config()), 'chave inválida não vira período')
Test.falsy(Rules.periodBounds(nil, config()), 'nil não vira período')

Test.equal(Rules.previousPeriodKey(sunday, config()), 'W2026-09-07', 'período anterior')

--------------------------------------------------------------------------------
-- Classificação
--------------------------------------------------------------------------------

local function movement(overrides)
    local base = {
        provider = 'Renewed-Banking',
        transactionId = 'abc123',
        subjectType = 'player',
        subjectId = 'NOIR00001',
        direction = 'in',
        amount = 5000,
        issuer = 'Fulano',
        receiver = 'Fulano',
        isTransferLeg = false,
        occurredAt = sunday,
    }
    for key, value in pairs(overrides or {}) do base[key] = value end
    return base
end

-- O caso que decide o sistema inteiro: depositar o próprio dinheiro em espécie e
-- receber um pagamento chegam os dois como 'deposit'. Tributar os dois seria
-- cobrar imposto de alguém por usar o banco.
local selfDeposit = Rules.classifyBankMovement(movement(), config())
Test.equal(selfDeposit.category, Constants.category.selfDeposit, 'depósito próprio')
Test.falsy(selfDeposit.taxable, 'depósito do próprio dinheiro não é renda')

local received = Rules.classifyBankMovement(
    movement({ isTransferLeg = true, linkedTransactionId = 'abc123', issuer = 'Sicrano' }), config())
Test.equal(received.category, Constants.category.transferIn, 'transferência recebida')
Test.truthy(received.taxable, 'pagamento recebido é renda')
Test.equal(received.counterparty, 'Sicrano', 'contraparte de entrada é quem pagou')

local outflow = Rules.classifyBankMovement(
    movement({ direction = 'out', isTransferLeg = true, receiver = 'Beltrano' }), config())
Test.equal(outflow.category, Constants.category.outflow, 'saída')
Test.falsy(outflow.taxable, 'saída nunca é tributada -- tributamos só entradas')
Test.equal(outflow.counterparty, 'Beltrano', 'contraparte de saída é quem recebeu')

-- As duas pernas de uma transferência compartilham o id da transação. Se o
-- eventId não separasse por sujeito e direção, a segunda perna seria descartada
-- como duplicata e o recebedor nunca seria tributado.
local legOut = Rules.classifyBankMovement(
    movement({ direction = 'out', subjectId = 'NOIR00002', isTransferLeg = true }), config())
Test.truthy(received.eventId ~= legOut.eventId, 'pernas da mesma transferência têm ids distintos')

local org = Rules.classifyBankMovement(
    movement({ subjectType = 'org', subjectId = 'police', isTransferLeg = true }), config())
Test.truthy(org, 'organização entra no ledger')
Test.falsy(org.taxable, 'organização não é pessoa física: nunca tributada hoje')

Test.falsy(Rules.classifyBankMovement(movement({ amount = 0 }), config()), 'valor zero é ignorado')
Test.falsy(Rules.classifyBankMovement(movement({ amount = 100000001, isTransferLeg = true }), config()),
    'valor acima do teto de sanidade não entra: seria imposto absurdo sobre bug de chamador')
Test.truthy(Rules.classifyBankMovement(movement({ amount = 100000000, isTransferLeg = true }), config()),
    'exatamente no teto ainda entra')
Test.falsy(Rules.classifyBankMovement(movement({ subjectType = 'alien' }), config()), 'sujeito inválido')
Test.falsy(Rules.classifyBankMovement(movement({ subjectId = '' }), config()), 'sujeito vazio')
Test.falsy(Rules.classifyBankMovement(nil, config()), 'nil é ignorado')

local lean = config({ Ledger = { minimumAmount = 1, recordNonTaxable = false, recordOrganizations = true } })
Test.falsy(Rules.classifyBankMovement(movement(), lean), 'recordNonTaxable=false descarta isento')
Test.truthy(Rules.classifyBankMovement(movement({ isTransferLeg = true }), lean),
    'recordNonTaxable=false mantém tributável')

--------------------------------------------------------------------------------
-- Cálculo do imposto
--------------------------------------------------------------------------------

Test.equal(Rules.computeTax(0, config()), 0, 'base zero')
Test.equal(Rules.computeTax(-500, config()), 0, 'base negativa')
Test.equal(Rules.computeTax(25000, config()), 0, 'dentro da faixa isenta')

-- Progressivo na margem: 30k paga 5% só sobre os 5k que passaram da isenção.
Test.equal(Rules.computeTax(30000, config()), 250, '30k paga sobre a margem, não sobre o total')
Test.equal(Rules.computeTax(100000, config()), 3750, 'teto da segunda faixa')
Test.equal(Rules.computeTax(150000, config()), 3750 + 6000, 'terceira faixa sem teto')

-- minAssessment: cobrar troco gera mais atrito de RP do que receita.
Test.equal(Rules.computeTax(25500, config()), 0, 'imposto abaixo do mínimo é dispensado')
Test.equal(Rules.computeTax(26000, config()), 50, 'imposto exatamente no mínimo é cobrado')

local _, effectiveRate = Rules.computeTax(150000, config())
Test.truthy(effectiveRate > 0.06 and effectiveRate < 0.07, 'alíquota efetiva fica abaixo da marginal')

Test.equal(Rules.computeTax(50000, config({ Tax = { minAssessment = 0, brackets = {} } })), 0,
    'sem faixas não há imposto')

local flat = config({ Tax = { minAssessment = 0, brackets = { { upTo = false, rate = 0.10 } } } })
Test.equal(Rules.computeTax(1000, flat), 100, 'faixa única sem teto')

print('rules_spec: ok')
