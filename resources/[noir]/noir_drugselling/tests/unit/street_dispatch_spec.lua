-- lua5.4 tests/unit/street_dispatch_spec.lua (na raiz do resource)
local RES = (os.getenv('RES') or './')
dofile(RES .. 'config/ServerConfig.lua')

local states = { bgrz_core = 'started' }
local sent = {}
local pedPos = { x = 100.0, y = 200.0, z = 30.0 }
function GetResourceState(name) return states[name] or 'missing' end
function GetPlayerPed() return 1 end
function GetEntityCoords() return pedPos end
exports = { bgrz_core = setmetatable({
    SendDispatch = function(_, request) sent[#sent + 1] = request return true, { provider = 'ps-mdt' } end,
}, { __index = function() return nil end }) }

dofile(RES .. 'integrations/server/street_dispatch.lua')

local function equal(actual, expected, message)
    if actual ~= expected then error(('%s: esperado %s, veio %s'):format(message, tostring(expected), tostring(actual)), 2) end
end

-- Chance: 5% e +2,5% por venda recente no ponto, até 15%.
equal(NoirDrugDispatch.chanceFor(0), 5, 'primeira venda no ponto')
equal(NoirDrugDispatch.chanceFor(2), 10, 'duas vendas antes')
equal(NoirDrugDispatch.chanceFor(4), 15, 'quatro vendas antes: teto')
equal(NoirDrugDispatch.chanceFor(20), 15, 'não passa do teto')

-- Repetição no mesmo ponto, janela e raio.
equal(NoirDrugDispatch.track(0, 0, 1000), 0, 'ponto novo')
equal(NoirDrugDispatch.track(10, 10, 1100), 1, 'mesmo ponto')
equal(NoirDrugDispatch.track(50, 50, 1200), 2, 'ainda dentro do raio')
equal(NoirDrugDispatch.track(500, 500, 1300), 0, 'outro ponto, longe')
equal(NoirDrugDispatch.track(0, 0, 1000 + 30 * 60 + 1), 2, 'a primeira venda saiu da janela')

-- Comprador que não chama nunca chama, mesmo com chance cheia.
math.random = function(a) if a then return a end return 0 end
equal(NoirDrugDispatch.onSale(1, { dispatchCall = false }), false, 'dependente não chama')
equal(#sent, 0, 'nada enviado')

-- Sorteio dentro da chance: chama pelo bgrz_core, com código e perto da venda.
equal(NoirDrugDispatch.onSale(1, { dispatchCall = true }), true, 'chamado enviado')
equal(sent[1].code, '10-66', 'código do chamado')
equal(sent[1].jobs[2], 'bcso', 'vai para os três departamentos')
local dx, dy = sent[1].coords.x - pedPos.x, sent[1].coords.y - pedPos.y
assert(dx * dx + dy * dy <= 25.0 * 25.0 + 0.01, 'posição dentro do desvio')

-- Sorteio fora da chance: não chama.
math.random = function(a) if a then return a end return 0.99 end
equal(NoirDrugDispatch.onSale(1, { dispatchCall = true }), false, 'sorteio acima da chance')

-- Sem bgrz_core: não chama e não quebra.
math.random = function(a) if a then return a end return 0 end
states.bgrz_core = nil
equal(NoirDrugDispatch.onSale(1, { dispatchCall = true }), false, 'sem bridge')

print('street_dispatch_spec: ok')
