-- Layout editável: o config vira plano, o plano passa na validação e volta a vetor.
-- A validação é a única barreira entre o editor (cliente) e o banco.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Layout = require 'shared.layout'

-- O config inteiro sobrevive à ida e volta.
local stations = Layout.encode.stations(Config.stations)
local clean, err = Layout.validate.stations(stations, Config.departments)
T.truthy(clean, 'estações do config passam na validação: ' .. tostring(err))
T.equal(#clean, #Config.stations, 'mesma quantidade de estações')
local decoded = Layout.decode.stations(clean)
T.equal(decoded[1].id, Config.stations[1].id, 'id preservado')
T.equal(decoded[1].garages[1].spawns[1].w, Config.stations[1].garages[1].spawns[1].w, 'heading da vaga preservado')
T.truthy(decoded[1].reception and decoded[1].reception.coords, 'recepção preservada no ciclo config -> plano -> vetores')

T.truthy(Layout.validate.radars(Layout.encode.radars(Config.radars.locations)), 'radares do config')
T.truthy(Layout.validate.cameras(Layout.encode.cameras(Config.securityCameras)), 'câmeras do config')
T.truthy(Layout.validate.shotspotter(Layout.encode.shotspotter(ServerConfig.shotspotter.locations)), 'sensores do config')

-- Recusas
local function station(overrides)
    local base = { id = 'x', label = 'X', departments = { 'police' }, duty = {}, lockers = {}, garages = {} }
    for key, value in pairs(overrides) do base[key] = value end
    return base
end

local _, code = Layout.validate.stations({ station({ departments = { 'mafia' } }) }, Config.departments)
T.equal(code, 'invalid_department', 'departamento inexistente')
_, code = Layout.validate.stations({ station({}), station({}) }, Config.departments)
T.equal(code, 'invalid_station', 'id repetido')
_, code = Layout.validate.stations({ station({ id = 'a b' }) }, Config.departments)
T.equal(code, 'invalid_station', 'id com espaço')
_, code = Layout.validate.stations({ station({ duty = { { x = 0 / 0, y = 0, z = 0 } } }) }, Config.departments)
T.equal(code, 'invalid_point', 'NaN no ponto')
_, code = Layout.validate.stations({ station({ garages = { { type = 'car', point = { x = 1, y = 1, z = 1 }, spawns = {} } } }) }, Config.departments)
T.equal(code, 'invalid_garage', 'garagem sem vaga')
_, code = Layout.validate.stations({ station({ garages = { { type = 'boat', point = { x = 1, y = 1, z = 1 }, spawns = { { x = 1, y = 1, z = 1, w = 0 } } } } }) }, Config.departments)
T.equal(code, 'invalid_garage', 'tipo de garagem inválido')
_, code = Layout.validate.stations({ station({ evidence = { x = 1, y = 1, z = 1, radius = 50 } }) }, Config.departments)
T.equal(code, 'invalid_point', 'raio grande demais')
_, code = Layout.validate.stations({ station({ reception = { x = 1, y = 1, z = 1, radius = 50 } }) }, Config.departments)
T.equal(code, 'invalid_point', 'raio da recepção grande demais')
_, code = Layout.validate.radars({ { x = 1, y = 1, z = 1, w = 0, speedLimit = 5 } })
T.equal(code, 'invalid_point', 'limite de velocidade baixo demais')

local many = {}
for index = 1, Layout.limits.shotspotter + 1 do many[index] = { x = index, y = 0, z = 0 } end
_, code = Layout.validate.shotspotter(many)
T.equal(code, 'invalid_layout', 'lista acima do teto')

-- O heading volta para 0..360.
local radars = Layout.validate.radars({ { x = 1, y = 1, z = 1, w = 370, speedLimit = 60 } })
T.equal(radars[1].w, 10, 'heading normalizado')

print('layout_spec: ok')
