-- lua5.4 tests/unit/rules_spec.lua (na raiz do resource)
package.path = './?.lua;' .. package.path
local Rules = require 'server.rules'
local config = require 'config.server'

local function equal(actual, expected, message)
    if actual ~= expected then
        error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2)
    end
end

local function fails(fn, message)
    if pcall(fn) then error(message .. ': deveria falhar', 2) end
end

-- A config de verdade passa na validação.
local byKey = Rules.index(config.crimes)
for _, key in ipairs({ 'storerobbery', 'houserobbery', 'outpost', 'jewellery', 'truckrobbery', 'bankrobbery', 'paleto', 'pacific' }) do
    assert(byKey[key], 'crime esperado na tabela: ' .. key)
end

fails(function() Rules.index({ { key = 'a', label = 'A', minimumPolice = 1 }, { key = 'a', label = 'B', minimumPolice = 1 } }) end, 'key duplicada')
fails(function() Rules.index({ { key = 'a', label = 'A', minimumPolice = 1.5 } }) end, 'mínimo fracionado')
fails(function() Rules.index({ { key = 'a', label = 'A', minimumPolice = -1 } }) end, 'mínimo negativo')
fails(function() Rules.index({ { key = '', label = 'A', minimumPolice = 1 } }) end, 'key vazia')

-- check
local crime = { key = 'x', label = 'X', minimumPolice = 2 }
local ok, code = Rules.check(crime, 1)
equal(ok, false, 'abaixo do mínimo')
equal(code, 'not_enough_police', 'código abaixo do mínimo')
equal(Rules.check(crime, 2), true, 'no mínimo libera')
equal(Rules.check(crime, 5), true, 'acima do mínimo libera')
ok, code = Rules.check(nil, 10)
equal(ok, false, 'crime desconhecido')
equal(code, 'unknown_crime', 'código crime desconhecido')
equal(Rules.check({ key = 'z', label = 'Z', minimumPolice = 0 }, 0), true, 'mínimo zero libera sem polícia')

-- table: ordem da config e status
local crimes = {
    { key = 'a', label = 'A', minimumPolice = 0 },
    { key = 'b', label = 'B', minimumPolice = 3 },
    { key = 'c', label = 'C', minimumPolice = 1 },
}
local rows = Rules.table(crimes, 1, { c = true })
equal(#rows, 3, 'uma linha por crime')
equal(rows[1].key, 'a', 'ordem da config')
equal(rows[1].status, 'open', 'mínimo atingido')
equal(rows[2].status, 'closed', 'mínimo não atingido')
equal(rows[3].status, 'busy', 'em andamento vence o resto')
equal(rows[2].minimumPolice, 3, 'mínimo vai para a tabela')

-- membro de gang
equal(Rules.isGangMember({ ballas = 2 }), true, 'com gang')
equal(Rules.isGangMember({}), false, 'mapa vazio')
equal(Rules.isGangMember(nil), false, 'sem resposta do provider')

print('rules_spec: ok')
