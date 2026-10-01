-- Utilitários puros: validação de entrada, multa do radar e conferência da apreensão.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Utils = require 'shared.utils'

T.equal(Utils.intInRange(5, 1, 10), 5, 'inteiro na faixa')
T.equal(Utils.intInRange('7', 1, 10), 7, 'string numérica')
T.equal(Utils.intInRange(5.5, 1, 10), nil, 'fração recusada')
T.equal(Utils.intInRange(0 / 0, 1, 10), nil, 'NaN recusado')
T.equal(Utils.intInRange(math.huge, 1, 10), nil, 'infinito recusado')
T.equal(Utils.intInRange(11, 1, 10), nil, 'acima do teto')

T.equal(Utils.cleanText('  oi  ', 10), 'oi', 'apara espaços')
T.equal(Utils.cleanText('ab', 10, 3), nil, 'curto demais')
T.equal(Utils.cleanText(('x'):rep(11), 10), nil, 'longo demais')
T.equal(Utils.cleanText('a\nb', 10), 'a b', 'controle vira espaço')
T.equal(Utils.cleanText(42, 10), nil, 'não-texto')

local point = Utils.toVec3({ 1, 2, 3 })
T.equal(point.x, 1, 'array vira vetor')
T.equal(Utils.toVec3({ x = 1, y = 2, z = 0 / 0 }), nil, 'NaN no vetor')
T.equal(Utils.toVec3({ x = 99999, y = 0, z = 0 }), nil, 'fora do mapa')

local fines = { { over = 10, fine = 150 }, { over = 30, fine = 400 }, { over = 60, fine = 1000 } }
T.equal(Utils.radarFine(fines, 5), nil, 'abaixo da primeira faixa')
T.equal(Utils.radarFine(fines, 10), 150, 'primeira faixa')
T.equal(Utils.radarFine(fines, 45), 400, 'faixa do meio')
T.equal(Utils.radarFine(fines, 200), 1000, 'última faixa')

-- Conferência: o que chegou baixa a pendência; o que falta continua pendente.
local deposited = { { name = 'money', count = 500 }, { name = 'WEAPON_PISTOL', count = 1 } }
local pending = {
    { id = 1, item = 'money', count = 300 },
    { id = 2, item = 'money', count = 200 },
    { id = 3, item = 'WEAPON_PISTOL', count = 1 },
    { id = 4, item = 'black_money', count = 1000 },
}
local matched, leftover = Utils.matchPending(deposited, pending)
T.equal(#matched, 3, 'três pendências baixadas')
T.equal(matched[3], 3, 'arma baixada')
T.equal(leftover.money, 0, 'dinheiro todo usado')

matched, leftover = Utils.matchPending({ { name = 'money', count = 250 } }, pending)
T.equal(#matched, 1, 'só a pendência que cabe é baixada')
T.equal(matched[1], 2, 'a de 200 cabe, a de 300 não')
T.equal(leftover.money, 50, 'sobra fica sem pendência')

local id = Utils.opaqueId('BOX')
T.truthy(id:match('^BOX%-%d+%-%w+$'), 'id opaco com prefixo')

-- Código de DNA: estável por personagem, muda com a chave e não carrega o citizenid.
local dna1 = Utils.dnaCode('segredo-a', 'ABC12345')
T.equal(dna1, Utils.dnaCode('segredo-a', 'ABC12345'), 'mesmo personagem, mesmo código')
T.truthy(dna1:match('^%x+$') and #dna1 == 16, '16 dígitos hexadecimais')
T.truthy(dna1 ~= Utils.dnaCode('segredo-b', 'ABC12345'), 'outra chave, outro código')
T.truthy(dna1 ~= Utils.dnaCode('segredo-a', 'ABC12346'), 'outro personagem, outro código')
local hex = ('ABC12345'):gsub('.', function(c) return ('%02x'):format(c:byte()) end)
T.falsy(dna1:lower():find(hex, 1, true), 'o código não contém o citizenid em hex')

print('utils_spec: ok')
