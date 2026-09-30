-- Catálogo do editor (server/catalog.lua) com o banco em memória: semente pelo config.lua,
-- validação, gravação e aplicação em Config. Rodar da pasta do resource:
--     lua5.4 tests/catalog_spec.lua

local failures = 0
local function check(name, cond)
    if cond then print('ok   ' .. name) else failures = failures + 1; print('FAIL ' .. name) end
end

-- Ambiente do FiveM ---------------------------------------------------------------------
vec3 = function(x, y, z) return { x = x, y = y, z = z } end
vec4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
vector3, vector4 = vec3, vec4
joaat = function(s) return s end
GlobalState = {}
lib = {}

local function deepcopy(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
end
-- JSON de mentira: guarda uma cópia e devolve uma chave.
local store, seq = {}, 0
json = {
    null = setmetatable({}, { __name = 'null' }),
    encode = function(v) seq = seq + 1; local key = 'J' .. seq; store[key] = deepcopy(v); return key end,
    decode = function(s) return deepcopy(store[s]) end,
}

-- Banco em memória -------------------------------------------------------------------
local db = { settings = {}, points = {}, vehicles = {}, log = {}, nextPoint = 1 }
local ready
MySQL = {
    ready = function(cb) ready = cb end,
    query = { await = function(q, p)
        if q:find('^%s*CREATE') then return {} end
        if q:find('FROM taxijob_settings') then
            local rows = {}
            for k, v in pairs(db.settings) do rows[#rows + 1] = { key = k, data = v } end
            return rows
        end
        if q:find('INSERT INTO taxijob_settings') then db.settings[p[1]] = p[2]; return {} end
        if q:find('SELECT id, data FROM taxijob_points') then
            local rows = {}
            for id, d in pairs(db.points) do rows[#rows + 1] = { id = id, data = d } end
            table.sort(rows, function(a, b) return a.id < b.id end)
            return rows
        end
        if q:find('INSERT INTO taxijob_points') then db.points[db.nextPoint] = p[1]; db.nextPoint = db.nextPoint + 1; return {} end
        if q:find('UPDATE taxijob_points') then db.points[p[2]] = p[1]; return {} end
        if q:find('DELETE FROM taxijob_points') then db.points[p[1]] = nil; return {} end
        if q:find('SELECT id, data FROM taxijob_vehicles') then
            local rows = {}
            for id, r in pairs(db.vehicles) do rows[#rows + 1] = { id = id, sort = r.sort, data = r.data } end
            table.sort(rows, function(a, b) return a.sort < b.sort end)
            return rows
        end
        if q:find('INSERT INTO taxijob_vehicles') then db.vehicles[p[1]] = { sort = p[2], data = p[3] }; return {} end
        if q:find('DELETE FROM taxijob_vehicles') then db.vehicles[p[1]] = nil; return {} end
        if q:find('INSERT INTO taxijob_editor_log') then db.log[#db.log + 1] = p; return {} end
        error('query inesperada: ' .. q)
    end },
    insert = { await = function(q, p)
        local id = db.nextPoint
        db.points[id] = p[1]
        db.nextPoint = id + 1
        return id
    end },
}

Progression = { setLevels = function(list) Progression.current = list; return true end }

dofile('config.lua')
dofile('serverConfig.lua')
dofile('server/catalog.lua')

local configPoints = 0
for _, list in pairs(Config.Points) do configPoints = configPoints + #list end
local configVehicles = #Config.RentalVehicles

ready()
local view = Catalog.adminView()

-- Semente --------------------------------------------------------------------------------
check('catálogo pronto', Catalog.ready)
check('semente: todos os pontos do config', #view.points == configPoints)
check('semente: todos os carros do config', #view.vehicles == configVehicles)
check('semente: níveis do serverConfig', #view.levels == #ServerConfig.Progression.Levels)
check('PointList reconstruído', #Config.PointList == configPoints)
check('PointList com zona e coords', Config.PointList[1].zone and Config.PointList[1].coords.x ~= nil)
check('GlobalState publicado', GlobalState['noir_taxijob:catalog'] and #GlobalState['noir_taxijob:catalog'].vehicles == configVehicles)
local taxi = view.vehicles[1]
check('visual do táxi: extras com chave de texto', taxi.appearance and taxi.appearance.props.extras['5'] == 0 and taxi.appearance.props.extras[5] == nil)
local van
for _, v in ipairs(view.vehicles) do if v.model == 'imperialpas' then van = v end end
check('visual da van: mods com chave de texto', van and van.appearance.mods['10'] == 4 and van.appearance.mods['48'] == 4)

-- Reinício lê do banco sem semear de novo --------------------------------------------------
local before = #db.log
ready()
check('segundo start não duplica pontos', #Catalog.adminView().points == configPoints)

-- Pontos -----------------------------------------------------------------------------------
local id, code = Catalog.savePoint(nil, { region = 'downtown', x = 100.5, y = -200.25, z = 30, w = 90, enabled = true })
check('novo ponto salvo', id ~= nil)
check('novo ponto entra no sorteio', #Config.PointList == configPoints + 1)
check('ponto em região inválida recusado', select(2, Catalog.savePoint(nil, { region = 'mars', x = 1, y = 1, z = 1, w = 0 })) == 'invalid_region')
check('ponto fora do mapa recusado', select(2, Catalog.savePoint(nil, { region = 'downtown', x = 99999, y = 1, z = 1, w = 0 })) == 'invalid_point')
Catalog.savePoint(id, { region = 'downtown', x = 100.5, y = -200.25, z = 30, w = 90, enabled = false })
check('ponto desativado sai do sorteio', #Config.PointList == configPoints)
check('ponto desativado continua no editor', #Catalog.adminView().points == configPoints + 1)
check('apagar ponto', Catalog.deletePoint(id) == true and #Catalog.adminView().points == configPoints)
check('apagar ponto inexistente', select(2, Catalog.deletePoint(99999)) == 'unknown_point')

-- Carros -----------------------------------------------------------------------------------
local newCar = { id = 'teste', model = 'taxi', label = 'Teste', class = 'standard', requiredLevel = 2, rentalFee = 50, image = 'img/vehicles/taxi-fixed.png', description = 'x', enabled = true,
    appearance = { props = { color1 = 88, extras = { [5] = 0, [6] = 1 } } } }
check('novo carro', Catalog.saveVehicle(true, newCar) == 'teste')
check('novo carro na central e nos modelos aceitos', #Config.RentalVehicles == configVehicles + 1)
local saved = Config.RentalVehicles[#Config.RentalVehicles]
check('extras do carro novo com chave de texto', saved.appearance.props.extras['6'] == 1)
check('chave repetida recusada', select(2, Catalog.saveVehicle(true, newCar)) == 'vehicle_exists')
check('classe inexistente recusada', select(2, Catalog.saveVehicle(false, (function() local c = deepcopy(newCar); c.class = 'jato'; return c end)())) == 'invalid_class')
check('nível acima da tabela recusado', select(2, Catalog.saveVehicle(false, (function() local c = deepcopy(newCar); c.requiredLevel = 99; return c end)())) == 'invalid_level')
check('imagem fora de img/ recusada', select(2, Catalog.saveVehicle(false, (function() local c = deepcopy(newCar); c.image = '../server.lua'; return c end)())) == 'invalid_image')
Catalog.moveVehicle('teste', -1)
check('subir na lista', Config.RentalVehicles[#Config.RentalVehicles - 1].id == 'teste')
check('apagar carro', Catalog.deleteVehicle('teste') == true and #Config.RentalVehicles == configVehicles)

-- Níveis -----------------------------------------------------------------------------------
check('níveis fora de ordem recusados', select(2, Catalog.saveLevels({ { min = 0, label = 'a' }, { min = 0, label = 'b' } })) == 'levels_order')
check('nível 1 precisa começar em 0', select(2, Catalog.saveLevels({ { min = 10, label = 'a' } })) == 'first_level_zero')
check('níveis que deixariam carro sem nível recusados', select(2, Catalog.saveLevels({ { min = 0, label = 'a' }, { min = 100, label = 'b' } })) == 'vehicle_level_missing')
local levels = {}
for i, l in ipairs(ServerConfig.Progression.Levels) do levels[i] = { min = l.min, label = l.label } end
levels[#levels + 1] = { min = 20000, label = 'Lenda' }
check('níveis válidos aplicados', Catalog.saveLevels(levels) == true and #Progression.current == #levels)

-- Central e ajustes --------------------------------------------------------------------------
local depot = deepcopy(Catalog.depot())
depot.returnRadius = 40
check('Central salva e aplicada', Catalog.saveDepot(depot) == true and Config.Depot.returnRadius == 40)
depot.spawnPoints = {}
check('Central sem vaga recusada', select(2, Catalog.saveDepot(depot)) == 'invalid_spawns')
local values = deepcopy(Catalog.adminView().settings)
values.meter.PricePerKm = 14
check('ajustes aplicados em Config.Meter', Catalog.saveSettings(values) == true and Config.Meter.PricePerKm == 14)
values.dispatch.MinPickupDistance = 5000
check('distâncias fora de ordem recusadas', select(2, Catalog.saveSettings(values)) == 'invalid_dispatch')
check('ajuste recusado não muda nada', Config.Dispatch.MinPickupDistance ~= 5000)

print(failures == 0 and '\ntudo certo' or ('\n' .. failures .. ' falha(s)'))
os.exit(failures == 0 and 0 or 1)
