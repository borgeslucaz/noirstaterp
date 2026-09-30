---Boot do client: sync com o servidor no login, no start do resource e quando o
---servidor termina de carregar; limpa os props no logout e no stop.

lib.locale()

local Integrations = require 'client.integrations'
local Plants = require 'client.plants'
local Tables = require 'client.tables'
require 'client.grinder'
require 'client.manual'

local function clearAll()
    Plants.clear()
    Tables.clear()
end

local function resync()
    clearAll()
    if not Integrations.isLoggedIn() then return end
    local data = lib.callback.await('noir_weed:server:sync', false)
    if type(data) ~= 'table' then return end
    Plants.load(data.plants or {}, data.mine or {})
    Tables.load(data.tables or {}, data.tablesMine or {})
end

RegisterNetEvent('noir_weed:client:resync', resync)
AddEventHandler('bgrz_core:client:playerLoaded', resync)
AddEventHandler('bgrz_core:client:playerUnloaded', clearAll)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == cache.resource then resync() end
end)

Integrations.showGradeInTooltip()

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    Plants.despawnAll()
    Tables.despawnAll()
end)
