---Boot do client: lê as rotas públicas do GlobalState, desenha o início de cada rota (NPC
---ou alvo no chão) e os pontos de rota sem início, e abre o menu da rota.

local Config = require 'config.shared'
local Rules = require 'shared.rules'
local Integrations = require 'client.integrations'
local Collect = require 'client.collect'
local Haul = require 'client.haul'
local Npc = require 'client.npc'
local Scenery = require 'client.scenery'
local Carry = require 'client.carry'
local Creator = require 'client.creator'

local STATE_KEY = 'noir_gathering:routes'

---@type integer[]
local zones = {}

local function clearZones()
    for index = 1, #zones do Integrations.removeZone(zones[index]) end
    zones = {}
    Npc.clear()
    Scenery.clear()
end

local function isBusy()
    return Collect.isBusy() or Haul.isActive()
end

local function addZone(data)
    local id = Integrations.addZone(data)
    if id then zones[#zones + 1] = id end
end

---@param point { x: number, y: number, z: number }
local function toVector(point)
    return vector3(point.x, point.y, point.z)
end

local function openRouteMenu(route)
    local options = {}
    for itemName, item in pairs(route.items) do
        if #item.points > 0 then
            options[#options + 1] = {
                title = item.label,
                description = item.tool and locale('menu_requires_tool') or nil,
                icon = Config.itemImage:format(itemName),
                image = Config.itemImage:format(itemName),
                disabled = isBusy(),
                onSelect = function() Collect.startShift(route, itemName) end,
            }
        end
    end
    table.sort(options, function(a, b) return a.title < b.title end)

    if Collect.isOnRoute(route.id) then
        options[#options + 1] = {
            title = locale('menu_stop_shift'),
            icon = 'fa-solid fa-ban',
            onSelect = Collect.stop,
        }
    end

    lib.registerContext({ id = 'noir_gathering:route', title = route.name, options = options })
    lib.showContext('noir_gathering:route')
end

local function openHaulMenu(route)
    local options = {}
    if Haul.isActive() then
        options[1] = { title = locale('menu_haul_stop'), icon = 'fa-solid fa-ban', onSelect = Haul.stop }
    else
        options[1] = {
            title = locale('menu_haul_start'),
            description = locale('menu_haul_start_desc', route.haul.count),
            icon = 'fa-solid fa-truck-ramp-box',
            disabled = isBusy(),
            onSelect = function() Haul.start(route) end,
        }
    end
    lib.registerContext({ id = 'noir_gathering:haul', title = route.name, options = options })
    lib.showContext('noir_gathering:haul')
end

---Início da rota: no NPC, se a rota tem um, ou numa esfera no ponto.
local function addStart(route)
    local haul = route.mode == 'haul'
    local options = { {
        name = 'noir_gathering:start:open',
        icon = haul and 'fa-solid fa-truck-ramp-box' or 'fa-solid fa-briefcase',
        label = locale('target_open', route.name),
        onSelect = function()
            if haul then openHaulMenu(route) else openRouteMenu(route) end
        end,
    } }
    local key = ('noir_gathering:start:%d'):format(route.id)
    if route.npc then
        Npc.add(key, route.start, route.npc, options)
    else
        addZone({ name = key, coords = toVector(route.start), radius = Config.targetRadius, options = options })
    end
end

---@param routes table[]?
local function rebuild(routes)
    clearZones()
    if not Integrations.isLoggedIn() then return end

    for _, route in ipairs(routes or GlobalState[STATE_KEY] or {}) do
        -- A pilha fica no mapa para todo mundo que chega perto, inclusive quem não tem acesso
        -- à rota: é cenário, não alvo.
        if route.haul and route.haul.stack then
            Scenery.add(('noir_gathering:stack:%d'):format(route.id), route.haul.stack, route.haul.prop)
        end
        local allowed = Rules.isPublic(route.groups) or Integrations.hasGroup(route.groups)
        -- O NPC também é visto por todos; só quem tem acesso recebe a opção nele.
        if not allowed and route.npc and route.start then
            Npc.add(('noir_gathering:start:%d'):format(route.id), route.start, route.npc, {})
        end
        if allowed then
            if (route.mode == 'shift' or route.mode == 'haul') and route.start then
                addStart(route)
            elseif route.mode == 'free' then
                for itemName, item in pairs(route.items) do
                    for index, point in ipairs(item.points) do
                        addZone({
                            name = ('noir_gathering:free:%d:%s:%d'):format(route.id, itemName, index),
                            coords = toVector(point),
                            radius = Config.targetRadius,
                            options = { {
                                name = 'noir_gathering:free:collect',
                                icon = 'fa-solid fa-hand',
                                label = locale('target_collect', item.label),
                                canInteract = function() return not isBusy() end,
                                onSelect = function() Collect.free(route, itemName, index) end,
                            } },
                        })
                    end
                end
            end
        end
    end
end

-- Rotas mudaram no servidor: redesenha. Quem estava num turno dela recebe o
-- `sessionEnded` separado, porque o servidor já encerrou a sessão.
AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    rebuild(value)
end)

AddEventHandler('bgrz_core:client:playerLoaded', function() rebuild() end)
AddEventHandler('bgrz_core:client:jobUpdated', function() rebuild() end)
AddEventHandler('bgrz_core:client:gangUpdated', function() rebuild() end)
AddEventHandler('bgrz_core:client:playerUnloaded', function()
    Collect.reset()
    Haul.reset()
    clearZones()
end)

RegisterNetEvent('noir_gathering:client:sessionEnded', function(reason)
    if source ~= 65535 then return end
    Collect.ended(reason)
end)

RegisterNetEvent('noir_gathering:client:haulEnded', function(reason)
    if source ~= 65535 then return end
    Haul.ended(reason)
end)

RegisterNetEvent('noir_gathering:client:scout', function(area, radius)
    if source ~= 65535 or type(area) ~= 'table' or type(radius) ~= 'number' then return end
    Haul.scout(area, radius)
end)

RegisterNetEvent('noir_gathering:client:openCreator', function()
    if source ~= 65535 then return end
    Creator.open()
end)

lib.addKeybind({
    name = 'noir_gathering_stop',
    description = locale('key_stop'),
    defaultKey = Config.stopKey,
    onReleased = function()
        if Haul.isActive() then return Haul.stop() end
        Collect.stop()
    end,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Collect.reset()
    Haul.reset()
    Npc.clear()
    Scenery.clear()
    Carry.clearAll()
    Creator.reset()
end)

CreateThread(function() rebuild() end)
