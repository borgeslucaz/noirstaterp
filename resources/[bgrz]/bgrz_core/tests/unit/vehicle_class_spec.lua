local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }

local state = 'started'
local classes = { [123] = 7, [456] = 0 }
local raise = false

exports = T.exports({
    qbx_core = setmetatable({}, { __index = function(_, key)
        if key ~= 'GetVehicleClass' then return nil end
        return function(_, model)
            if raise then error('sem cliente online') end
            return classes[model]
        end
    end }),
})
GetResourceState = function() return state end

-- server/qbox_bridge.lua registra handlers e usa o lib do Qbox no load.
local handlers
handlers, AddEventHandler = T.events()
RegisterNetEvent = AddEventHandler
TriggerEvent = function() end
TriggerClientEvent = function() end
GetPlayerPed = function() return 0 end
MySQL = { query = { await = function() return {} end } }
qbx = { spawnVehicle = function() return nil end }

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')

local class, err = BGRZ.GetVehicleClass(123)
T.equal(class, 7, 'classe do provider repassada')
T.equal(err, nil, 'sem erro no caminho feliz')

class, err = BGRZ.GetVehicleClass(456)
T.equal(class, 0, 'classe 0 é válida e não vira nil')

class, err = BGRZ.GetVehicleClass('nao-numero')
T.equal(class, nil, 'modelo não numérico recusado')
T.equal(err, 'invalid_model', 'código de erro estável')

class, err = BGRZ.GetVehicleClass(1.5)
T.equal(class, nil, 'modelo fracionário recusado')
T.equal(err, 'invalid_model', 'código de erro estável para fracionário')

class, err = BGRZ.GetVehicleClass(999)
T.equal(class, nil, 'modelo desconhecido devolve nil')
T.equal(err, 'provider_unavailable', 'modelo desconhecido sinalizado')

raise = true
class, err = BGRZ.GetVehicleClass(123)
T.equal(class, nil, 'exceção do provider não sobe')
T.equal(err, 'provider_unavailable', 'exceção vira código tratado')
raise = false

state = 'stopped'
class, err = BGRZ.GetVehicleClass(123)
T.equal(class, nil, 'provider parado devolve nil')
T.equal(err, 'provider_unavailable', 'provider parado sinalizado')

print('vehicle_class_spec: ok')
