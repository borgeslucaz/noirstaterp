---Boot do client: lê as rotas públicas do GlobalState, desenha os alvos de início e os
---pontos de rota sem início, e abre o menu da rota.

local Config = require 'config.shared'
local Rules = require 'shared.rules'
local Integrations = require 'client.integrations'
local Collect = require 'client.collect'
local Creator = require 'client.creator'

local STATE_KEY = 'noir_gathering:routes'

---@type integer[]
local zones = {}

local function clearZones()
    for index = 1, #zones do Integrations.removeZone(zones[index]) end
    zones = {}
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
                disabled = Collect.isBusy(),
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

---@param routes table[]?
local function rebuild(routes)
    clearZones()
    if not Integrations.isLoggedIn() then return end

    for _, route in ipairs(routes or GlobalState[STATE_KEY] or {}) do
        if Rules.isPublic(route.groups) or Integrations.hasGroup(route.groups) then
            if route.mode == 'shift' and route.start then
                addZone({
                    name = ('noir_gathering:start:%d'):format(route.id),
                    coords = toVector(route.start),
                    radius = Config.targetRadius,
                    options = { {
                        name = 'noir_gathering:start:open',
                        icon = 'fa-solid fa-briefcase',
                        label = locale('target_open', route.name),
                        onSelect = function() openRouteMenu(route) end,
                    } },
                })
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
                                canInteract = function() return not Collect.isBusy() end,
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
    clearZones()
end)

RegisterNetEvent('noir_gathering:client:sessionEnded', function(reason)
    if source ~= 65535 then return end
    Collect.ended(reason)
end)

RegisterNetEvent('noir_gathering:client:openCreator', function()
    if source ~= 65535 then return end
    Creator.open()
end)

lib.addKeybind({
    name = 'noir_gathering_stop',
    description = locale('key_stop'),
    defaultKey = Config.stopKey,
    onReleased = Collect.stop,
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Collect.reset()
    Creator.reset()
end)

CreateThread(function() rebuild() end)
