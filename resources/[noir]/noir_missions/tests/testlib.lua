---Harness para rodar o servidor do noir_missions em Lua puro.
---
---    cd resources/[noir]/noir_missions
---    lua5.4 tests/unit/elysian_flow_spec.lua
---
---Não é um FiveM de mentira completo: são os natives que o resource usa, com entidades em
---tabela, relógio controlável e o bgrz_core fingido. O runtime, os componentes e a validação
---rodam de verdade; só as bordas são falsas.
local Json = dofile('dev/json.lua')

local Test = {}

function Test.equal(actual, expected, label)
    if actual ~= expected then
        error(('%s: esperado %s, veio %s'):format(label, tostring(expected), tostring(actual)), 2)
    end
end

function Test.truthy(value, label)
    if not value then error(label or 'esperado verdadeiro', 2) end
end

function Test.falsy(value, label)
    if value then error(label or 'esperado falso', 2) end
end

---`require 'a.b'` -> `a/b.lua`, com cache.
function Test.require()
    local cache = {}
    return function(path)
        if cache[path] ~= nil then return cache[path] end
        local chunk = assert(loadfile((path:gsub('%.', '/')) .. '.lua'))
        local result = chunk()
        if result == nil then result = true end
        cache[path] = result
        return result
    end
end

-- vector3 com aritmética e `#` como comprimento, como no CfxLua.
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(a, b) return vector3(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)) end
vectorMeta.__add = function(a, b) return vector3(a.x + b.x, a.y + b.y, (a.z or 0) + (b.z or 0)) end
vectorMeta.__len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
vectorMeta.__tostring = function(a) return ('vector3(%.2f, %.2f, %.2f)'):format(a.x, a.y, a.z) end
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vectorMeta) end
vec3 = vector3

function joaat(text)
    local hash = 0
    for index = 1, #text do
        hash = (hash + text:lower():byte(index)) % 0x100000000
        hash = (hash + (hash << 10)) % 0x100000000
        hash = hash ~ (hash >> 6)
    end
    hash = (hash + (hash << 3)) % 0x100000000
    hash = hash ~ (hash >> 11)
    hash = (hash + (hash << 15)) % 0x100000000
    return hash
end

---Monta o servidor falso. Devolve o controle: relógio, entidades, jogadores, registros.
function Test.server()
    local S = {
        now = 0, timers = {}, entities = {}, nextEntity = 100, players = {},
        sent = {}, callbacks = {}, netEvents = {}, handlers = {}, exports = {},
        kvp = {}, files = {}, core = { notifications = {}, sms = {}, items = {}, money = {}, keys = {} },
        gangs = {}, downed = {},
    }

    json = { decode = Json.decode, encode = function(value) return Json.encode(value, true) end }

    lib = {
        print = {
            info = function() end, debug = function() end,
            warn = function(message) S.warnings = (S.warnings or 0) + 1; if os.getenv('NM_VERBOSE') then print('WARN', message) end end,
            error = function(message) error('lib.print.error: ' .. tostring(message), 2) end,
        },
        callback = {
            register = function(name, fn) S.callbacks[name] = fn end,
        },
    }

    function GetGameTimer() return S.now end
    function Wait() end
    function CreateThread() end
    function SetTimeout(ms, fn)
        S.timers[#S.timers + 1] = { at = S.now + ms, fn = fn, seq = #S.timers }
    end
    function GetCurrentResourceName() return 'noir_missions' end
    function GetInvokingResource() return nil end
    function GetResourceState() return 'started' end
    function IsPlayerAceAllowed() return 1 end
    function RegisterNetEvent(name, fn) S.netEvents[name] = fn end
    function RegisterCommand() end
    function AddEventHandler(name, fn)
        S.handlers[name] = S.handlers[name] or {}
        table.insert(S.handlers[name], fn)
    end
    function TriggerEvent(name, ...)
        for _, fn in ipairs(S.handlers[name] or {}) do fn(...) end
    end
    S.clientHandlers = {}
    function TriggerClientEvent(name, target, ...)
        S.sent[#S.sent + 1] = { name = name, target = target, args = { ... } }
        -- Cliente falso que responde na hora (pedidos de vaga, tipo de veículo).
        if S.clientHandlers[name] then S.clientHandlers[name](target, ...) end
    end
    function exports(name, fn) S.exports[name] = fn end

    function GetResourceKvpInt(key) return S.kvp[key] or 0 end
    function SetResourceKvpInt(key, value) S.kvp[key] = value end
    function DeleteResourceKvp(key) S.kvp[key] = nil end

    function LoadResourceFile(_, path)
        if S.files[path] ~= nil then return S.files[path] end
        local file = io.open(path, 'r')
        if not file then return nil end
        local content = file:read('a')
        file:close()
        return content
    end
    function SaveResourceFile(_, path, content)
        S.files[path] = content
        return 1 -- como no Enhanced: número, não booleano
    end

    -- Entidades ---------------------------------------------------------------------------
    local function newEntity(kind, model, x, y, z, h)
        S.nextEntity = S.nextEntity + 1
        local id = S.nextEntity
        S.entities[id] = {
            id = id, kind = kind, model = model, coords = vector3(x, y, z), heading = h or 0,
            health = kind == 'vehicle' and 1000 or 200, engine = 1000.0, owner = 1, state = {}, seats = {},
        }
        return id
    end
    S.newEntity = newEntity

    function CreatePed(_, model, x, y, z, h) return newEntity('ped', model, x, y, z, h) end
    function CreateVehicleServerSetter(model, _, x, y, z, h) return newEntity('vehicle', model, x, y, z, h) end
    function CreateObjectNoOffset(model, x, y, z) return newEntity('object', model, x, y, z, 0) end
    function CreatePedInsideVehicle(vehicle, _, model, seat)
        local veh = S.entities[vehicle]
        if not veh or (S.maxSeats and seat >= S.maxSeats) then return 0 end
        local id = newEntity('ped', model, veh.coords.x, veh.coords.y, veh.coords.z, 0)
        veh.seats[seat] = id
        S.entities[id].vehicle = vehicle
        return id
    end
    function DoesEntityExist(id) return S.entities[id] ~= nil end
    function DeleteEntity(id) S.entities[id] = nil end
    function NetworkGetNetworkIdFromEntity(id) return id + 5000 end
    function NetworkGetEntityFromNetworkId(netId) return S.entities[netId - 5000] and (netId - 5000) or 0 end
    function NetworkGetEntityOwner(id) return S.entities[id] and S.entities[id].owner or -1 end
    function GetEntityHealth(id) return S.entities[id] and S.entities[id].health or 0 end
    function GetVehicleEngineHealth(id) return S.entities[id] and S.entities[id].engine or -4000.0 end
    function GetEntityCoords(id)
        local entity = S.entities[id]
        if not entity then return vector3(0, 0, 0) end
        -- Ped dentro de veículo anda com ele.
        if entity.vehicle and S.entities[entity.vehicle] then return S.entities[entity.vehicle].coords end
        return entity.coords
    end
    function GetEntityHeading(id) return S.entities[id] and S.entities[id].heading or 0 end
    function GetEntityVelocity() return vector3(0, 0, 0) end
    function GetEntityModel(id) return S.entities[id] and S.entities[id].model or 0 end
    function GetEntityType(id)
        local kind = S.entities[id] and S.entities[id].kind
        return kind == 'ped' and 1 or kind == 'vehicle' and 2 or kind == 'object' and 3 or 0
    end
    function GetPedInVehicleSeat(vehicle, seat)
        local veh = S.entities[vehicle]
        return veh and veh.seats[seat] or 0
    end
    function GetVehiclePedIsIn(ped)
        local entity = S.entities[ped]
        return entity and entity.vehicle or 0
    end
    function SetEntityHeading(id, h) if S.entities[id] then S.entities[id].heading = h end end
    function FreezeEntityPosition() end
    function SetEntityOrphanMode() end
    function SetVehicleNumberPlateText(id, plate) if S.entities[id] then S.entities[id].plate = plate end end
    function SetVehicleDoorsLocked(id, state) if S.entities[id] then S.entities[id].locked = state end end

    function Entity(id)
        local entity = S.entities[id] or { state = {} }
        return {
            state = setmetatable({}, {
                __index = function(_, key)
                    if key == 'set' then return function(_, k, v) entity.state[k] = v end end
                    return entity.state[key]
                end,
            }),
        }
    end
    function Player(source)
        local player = S.players[source] or { state = {} }
        return {
            state = setmetatable({}, {
                __index = function(_, key)
                    if key == 'set' then return function(_, k, v) player.state[k] = v end end
                    return player.state[key]
                end,
            }),
        }
    end

    -- Jogadores ---------------------------------------------------------------------------
    function S.addPlayer(source, x, y, z, gang)
        local ped = newEntity('ped', joaat('mp_m_freemode_01'), x, y, z, 0)
        S.players[source] = { ped = ped, name = 'Player' .. source, state = {} }
        S.gangs[source] = gang
        return ped
    end
    function S.dropPlayer(source)
        local player = S.players[source]
        S.players[source] = nil
        if player then S.entities[player.ped] = nil end
        for _, fn in ipairs(S.handlers.playerDropped or {}) do
            _G.source = source
            fn()
        end
    end
    function S.moveTo(source, x, y, z)
        local ped = S.entities[S.players[source].ped]
        if ped.vehicle and S.entities[ped.vehicle] then
            for seat, occupant in pairs(S.entities[ped.vehicle].seats) do
                if occupant == ped.id then S.entities[ped.vehicle].seats[seat] = nil end
            end
        end
        ped.vehicle = nil
        ped.coords = vector3(x, y, z or ped.coords.z)
    end
    function S.enterVehicle(source, vehicle, seat)
        local ped = S.entities[S.players[source].ped]
        ped.vehicle = vehicle
        S.entities[vehicle].seats[seat or -1] = ped.id
    end
    function S.moveEntity(id, x, y, z)
        S.entities[id].coords = vector3(x, y, z or S.entities[id].coords.z)
    end
    function IsPedAPlayer(ped)
        for _, player in pairs(S.players) do
            if player.ped == ped then return true end
        end
        return false
    end
    function TaskWarpPedIntoVehicle(ped, vehicle, seat)
        if S.entities[ped] and S.entities[vehicle] then
            S.entities[ped].vehicle = vehicle
            S.entities[vehicle].seats[seat] = ped
        end
    end
    function GetPlayerPed(source) return S.players[source] and S.players[source].ped or 0 end
    function GetPlayerName(source) return S.players[source] and S.players[source].name or nil end
    function GetPlayers()
        local list = {}
        for source in pairs(S.players) do list[#list + 1] = tostring(source) end
        table.sort(list)
        return list
    end

    -- bgrz_core fingido --------------------------------------------------------------------
    local core = {}
    function core:Notify(source, message, kind) table.insert(S.core.notifications, { source = source, message = message, kind = kind }) end
    function core:GetCharacter(source)
        if not S.players[source] then return nil end
        return { citizenId = 'CID' .. source, name = { full = 'Pessoa ' .. source } }
    end
    function core:GetGang(source) return S.gangs[source] end
    function core:SendPhoneAnonymousMessage(citizenId, text) table.insert(S.core.sms, { citizenId = citizenId, text = text }) return true end
    function core:CanCarryItem() return true end
    function core:AddItem(source, item, amount) table.insert(S.core.items, { source = source, item = item, amount = amount }) return true end
    function core:RemoveItem() return true end
    function core:GetItemCount() return 0 end
    function core:GetItemList() return {} end
    function core:AddMoney(source, account, amount) table.insert(S.core.money, { source = source, account = account, amount = amount }) return true end
    function core:GiveVehicleKeys(source, vehicle, plate) table.insert(S.core.keys, { source = source, vehicle = vehicle, plate = plate }) return true end
    function core:IsPlayerDowned(source) return S.downed[source] == true end
    function core:GetVehicleClass() return 12 end
    function core:SendDispatch() return true end
    _G.exports = setmetatable({}, {
        __call = function(_, name, fn) S.exports[name] = fn end,
        __index = function(_, resource)
            if resource == 'bgrz_core' then return core end
            if resource == 'noir_missions' then
                return setmetatable({}, { __index = function(_, fnName)
                    return function(_, ...) return S.exports[fnName](...) end
                end })
            end
            return nil
        end,
    })

    -- Relógio ------------------------------------------------------------------------------
    function S.advance(ms)
        local target = S.now + ms
        while true do
            table.sort(S.timers, function(a, b)
                if a.at == b.at then return a.seq < b.seq end
                return a.at < b.at
            end)
            local timer = S.timers[1]
            if not timer or timer.at > target then break end
            table.remove(S.timers, 1)
            S.now = timer.at
            timer.fn()
        end
        S.now = target
    end

    function S.call(name, source, ...)
        local fn = assert(S.callbacks[name], 'callback não registrado: ' .. name)
        return fn(source, ...)
    end

    function S.findSent(name, target)
        for index = #S.sent, 1, -1 do
            local message = S.sent[index]
            if message.name == name and (target == nil or message.target == target) then return message end
        end
        return nil
    end

    function S.countEntities(predicate)
        local total = 0
        for _, entity in pairs(S.entities) do
            if not predicate or predicate(entity) then total = total + 1 end
        end
        return total
    end

    return S
end

return Test
