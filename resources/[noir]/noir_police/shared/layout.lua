---Formato do layout (posições editáveis em jogo): delegacias, radares, câmeras de
---segurança e sensores do shotspotter.
---
---Três formas do mesmo dado:
---  * config (`config/shared.lua`, `config/server.lua`): com vec3/vec4, é a semente;
---  * plano: só números e textos, é o que vai para o banco, o GlobalState e a rede;
---  * decodificado: plano de volta com vec3/vec4, que é o que os módulos usam.
---
---`validate` confere o plano que chega do editor: o cliente só propõe.

local Utils = require 'shared.utils'

local Layout = {}

Layout.kinds = { stations = true, radars = true, cameras = true, shotspotter = true }

local LIMITS = {
    stations = 20, points = 10, spawns = 10, garages = 10,
    radars = 60, cameras = 120, shotspotter = 120,
    text = 60, radius = 10.0, speed = 300,
}
Layout.limits = LIMITS

local function round(value) return math.floor(value * 100 + 0.5) / 100 end

local function flat(v, withW)
    if not v then return nil end
    local out = { x = round(v.x), y = round(v.y), z = round(v.z) }
    if withW then out.w = round(v.w or 0.0) end
    return out
end

local function toV3(t) return t and vec3(t.x + 0.0, t.y + 0.0, t.z + 0.0) or nil end
local function toV4(t) return t and vec4(t.x + 0.0, t.y + 0.0, t.z + 0.0, (t.w or 0.0) + 0.0) or nil end

local function mapList(list, fn)
    local out = {}
    for index = 1, #(list or {}) do out[index] = fn(list[index]) end
    return out
end

-- Codificar (config/decodificado -> plano) ------------------------------------------

Layout.encode = {}

function Layout.encode.stations(list)
    return mapList(list, function(station)
        local function area(entry)
            return entry and { x = round(entry.coords.x), y = round(entry.coords.y), z = round(entry.coords.z),
                radius = round(entry.radius or 1.5) } or nil
        end
        return {
            id = station.id,
            label = station.label,
            departments = mapList(station.departments, function(name) return name end),
            blip = station.blip and {
                x = round(station.blip.coords.x), y = round(station.blip.coords.y), z = round(station.blip.coords.z),
                sprite = station.blip.sprite, color = station.blip.color, scale = station.blip.scale,
            } or nil,
            duty = mapList(station.duty, flat),
            lockers = mapList(station.lockers, flat),
            evidence = area(station.evidence),
            fingerprint = area(station.fingerprint),
            lab = area(station.lab),
            reception = area(station.reception),
            cameras = area(station.cameras),
            garages = mapList(station.garages, function(garage)
                return {
                    type = garage.type,
                    point = flat(garage.point),
                    spawns = mapList(garage.spawns, function(spawn) return flat(spawn, true) end),
                }
            end),
        }
    end)
end

function Layout.encode.radars(list)
    return mapList(list, function(radar)
        local out = flat(radar.coords, true)
        out.speedLimit = radar.speedLimit
        return out
    end)
end

function Layout.encode.cameras(list)
    return mapList(list, function(camera)
        local out = flat(camera.coords)
        out.label = camera.label
        out.rx, out.ry, out.rz = round(camera.r.x), round(camera.r.y), round(camera.r.z)
        out.canRotate = camera.canRotate == true
        return out
    end)
end

function Layout.encode.shotspotter(list)
    return mapList(list, flat)
end

-- Decodificar (plano -> vetores) -----------------------------------------------------

Layout.decode = {}

function Layout.decode.stations(list)
    return mapList(list, function(station)
        local function area(entry)
            return entry and { coords = toV3(entry), radius = entry.radius or 1.5 } or nil
        end
        return {
            id = station.id,
            label = station.label,
            departments = station.departments or {},
            blip = station.blip and { coords = toV3(station.blip), sprite = station.blip.sprite,
                color = station.blip.color, scale = station.blip.scale } or nil,
            duty = mapList(station.duty, toV3),
            lockers = mapList(station.lockers, toV3),
            evidence = area(station.evidence),
            fingerprint = area(station.fingerprint),
            lab = area(station.lab),
            reception = area(station.reception),
            cameras = area(station.cameras),
            garages = mapList(station.garages, function(garage)
                return { type = garage.type, point = toV3(garage.point), spawns = mapList(garage.spawns, toV4) }
            end),
        }
    end)
end

function Layout.decode.radars(list)
    return mapList(list, function(radar) return { coords = toV4(radar), speedLimit = radar.speedLimit } end)
end

function Layout.decode.cameras(list)
    return mapList(list, function(camera)
        return { label = camera.label, coords = toV3(camera), r = vec3(camera.rx + 0.0, camera.ry + 0.0, camera.rz + 0.0),
            canRotate = camera.canRotate == true }
    end)
end

function Layout.decode.shotspotter(list)
    return mapList(list, toV3)
end

-- Validar (plano vindo do editor) ------------------------------------------------------

local function point(value, withW)
    if type(value) ~= 'table' then return nil end
    local coords = Utils.toVec3({ value.x, value.y, value.z })
    if not coords then return nil end
    local out = { x = round(coords.x), y = round(coords.y), z = round(coords.z) }
    if withW then
        local w = tonumber(value.w)
        if not Utils.isFinite(w) then return nil end
        out.w = round(w % 360)
    end
    return out
end

local function pointList(list, withW, maximum)
    if list == nil then return {} end
    if type(list) ~= 'table' or #list > maximum then return nil end
    local out = {}
    for index = 1, #list do
        local p = point(list[index], withW)
        if not p then return nil end
        out[index] = p
    end
    return out
end

local function area(value)
    if value == nil or value == false then return nil, true end
    local p = point(value)
    local radius = tonumber(value.radius)
    if not p or not Utils.isFinite(radius) or radius <= 0 or radius > LIMITS.radius then return nil, false end
    p.radius = round(radius)
    return p, true
end

Layout.validate = {}

---@param list any
---@param departments table<string, table> Config.departments
---@return table? clean, string? err
function Layout.validate.stations(list, departments)
    if type(list) ~= 'table' or #list > LIMITS.stations then return nil, 'invalid_layout' end
    local out, seen = {}, {}
    for index = 1, #list do
        local station = list[index]
        if type(station) ~= 'table' then return nil, 'invalid_layout' end
        local id = type(station.id) == 'string' and station.id:match('^[%w_]+$') and #station.id <= 32 and station.id
        local label = Utils.cleanText(station.label, LIMITS.text)
        if not id or seen[id] or not label then return nil, 'invalid_station' end
        seen[id] = true

        local depts = {}
        for _, name in ipairs(type(station.departments) == 'table' and station.departments or {}) do
            if not departments[name] then return nil, 'invalid_department' end
            depts[#depts + 1] = name
        end
        if #depts == 0 then return nil, 'invalid_department' end

        local blip
        if station.blip then
            blip = point(station.blip)
            if not blip then return nil, 'invalid_point' end
            blip.sprite = Utils.intInRange(station.blip.sprite, 1, 900) or 60
            blip.color = Utils.intInRange(station.blip.color, 0, 85) or 29
            blip.scale = math.min(math.max(tonumber(station.blip.scale) or 0.8, 0.3), 2.0)
        end

        local duty = pointList(station.duty, false, LIMITS.points)
        local lockers = pointList(station.lockers, false, LIMITS.points)
        if not duty or not lockers then return nil, 'invalid_point' end

        local evidence, okE = area(station.evidence)
        local fingerprint, okF = area(station.fingerprint)
        local cameras, okC = area(station.cameras)
        local lab, okL = area(station.lab)
        local reception, okR = area(station.reception)
        if not okE or not okF or not okC or not okL or not okR then return nil, 'invalid_point' end

        local garages = {}
        if type(station.garages) == 'table' then
            if #station.garages > LIMITS.garages then return nil, 'invalid_layout' end
            for g = 1, #station.garages do
                local garage = station.garages[g]
                if type(garage) ~= 'table' or (garage.type ~= 'car' and garage.type ~= 'air') then
                    return nil, 'invalid_garage'
                end
                local gp = point(garage.point)
                local spawns = pointList(garage.spawns, true, LIMITS.spawns)
                if not gp or not spawns or #spawns == 0 then return nil, 'invalid_garage' end
                garages[g] = { type = garage.type, point = gp, spawns = spawns }
            end
        end

        out[index] = {
            id = id, label = label, departments = depts, blip = blip, duty = duty, lockers = lockers,
            evidence = evidence, fingerprint = fingerprint, lab = lab, reception = reception, cameras = cameras,
            garages = garages,
        }
    end
    return out
end

function Layout.validate.radars(list)
    if type(list) ~= 'table' or #list > LIMITS.radars then return nil, 'invalid_layout' end
    local out = {}
    for index = 1, #list do
        local p = point(list[index], true)
        local speed = type(list[index]) == 'table' and Utils.intInRange(list[index].speedLimit, 10, LIMITS.speed)
        if not p or not speed then return nil, 'invalid_point' end
        p.speedLimit = speed
        out[index] = p
    end
    return out
end

function Layout.validate.cameras(list)
    if type(list) ~= 'table' or #list > LIMITS.cameras then return nil, 'invalid_layout' end
    local out = {}
    for index = 1, #list do
        local entry = list[index]
        local p = point(entry)
        local label = type(entry) == 'table' and Utils.cleanText(entry.label, LIMITS.text)
        if not p or not label then return nil, 'invalid_point' end
        local rx, ry, rz = tonumber(entry.rx), tonumber(entry.ry), tonumber(entry.rz)
        if not Utils.isFinite(rx) or not Utils.isFinite(ry) or not Utils.isFinite(rz) then return nil, 'invalid_point' end
        p.label, p.rx, p.ry, p.rz = label, round(rx), round(ry), round(rz)
        p.canRotate = entry.canRotate == true
        out[index] = p
    end
    return out
end

function Layout.validate.shotspotter(list)
    local out = pointList(list, false, LIMITS.shotspotter)
    if not out then return nil, 'invalid_layout' end
    return out
end

return Layout
