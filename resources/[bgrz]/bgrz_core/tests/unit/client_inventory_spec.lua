local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }
local state = 'started'
local throws = false
local shown = {}

local inventory = {}
function inventory:displayMetadata(key, label)
    if throws then error('boom') end
    shown[#shown + 1] = { key, label }
end

exports = T.exports({ ox_inventory = inventory })
GetResourceState = function() return state end

dofile('shared/provider.lua')
dofile('client/inventory.lua')

local ok, err = BGRZ.DisplayItemMetadata('grade', 'Grau')
T.truthy(ok, 'repassa ao provider')
T.equal(err, nil, 'sem erro')
T.equal(shown[1][1], 'grade', 'chave do metadata')
T.equal(shown[1][2], 'Grau', 'rótulo do tooltip')

T.equal(select(2, BGRZ.DisplayItemMetadata('', 'Grau')), 'invalid_key', 'chave vazia recusada')
T.equal(select(2, BGRZ.DisplayItemMetadata('grade', 42)), 'invalid_label', 'rótulo não-texto recusado')
T.equal(#shown, 1, 'inválido não chega ao provider')

throws = true
T.equal(select(2, BGRZ.DisplayItemMetadata('grade', 'Grau')), 'provider_unavailable', 'exceção do provider não sobe')
throws = false

state = 'stopped'
T.equal(select(2, BGRZ.DisplayItemMetadata('grade', 'Grau')), 'provider_unavailable', 'provider parado')

print('client_inventory_spec: ok')
