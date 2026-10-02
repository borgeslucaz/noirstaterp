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
local triggered = {}
TriggerEvent = function(name, ...) triggered[#triggered + 1] = { name = name, args = { ... } } end
local playerState = {}
LocalPlayer = { state = setmetatable({}, { __index = function(_, key)
    if key == 'set' then return function(_, k, v) playerState[k] = v end end
    return playerState[key]
end }) }

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

-- Guardar arma e travar inventário.
T.truthy(BGRZ.HolsterWeapon(true), 'guarda a arma')
T.equal(triggered[1].name, 'ox_inventory:disarm', 'pelo evento do provider')
T.equal(triggered[1].args[1], true, 'sem animação quando pedido')
T.truthy(BGRZ.SetInventoryBusy(true), 'trava')
T.truthy(BGRZ.IsInventoryBusy(), 'inventário travado')
T.truthy(BGRZ.SetInventoryBusy(false), 'destrava')
T.falsy(BGRZ.IsInventoryBusy(), 'inventário livre')
T.equal(select(2, BGRZ.SetInventoryBusy('sim')), 'invalid_state', 'estado não-booleano recusado')

state = 'stopped'
T.equal(select(2, BGRZ.DisplayItemMetadata('grade', 'Grau')), 'provider_unavailable', 'provider parado')
T.equal(select(2, BGRZ.HolsterWeapon()), 'provider_unavailable', 'guardar com provider parado')
T.equal(select(2, BGRZ.SetInventoryBusy(true)), 'provider_unavailable', 'travar com provider parado')

print('client_inventory_spec: ok')
