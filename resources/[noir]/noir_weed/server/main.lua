---Boot do servidor: banco, carga das plantas e mesas, sync inicial dos clients e
---gravação no desligamento. As ações moram em plants/rolling/tables.

local Integrations = require 'server.integrations'
local Storage = require 'server.storage'
local Actions = require 'server.actions'
local Plants = require 'server.plants'
local Tables = require 'server.tables'
require 'server.rolling'
require 'server.manual'

lib.callback.register('noir_weed:server:sync', function(source)
    if not Actions.ready then return { plants = {}, mine = {}, tables = {}, tablesMine = {} } end
    local citizenId = Integrations.citizenId(source)
    local plants, mine = Plants.sync(citizenId)
    local tables, tablesMine = Tables.sync(citizenId)
    return { plants = plants, mine = mine, tables = tables, tablesMine = tablesMine }
end)

CreateThread(function()
    Storage.migrate()
    Plants.load()
    Tables.load()
    Actions.ready = true
    TriggerClientEvent('noir_weed:client:resync', -1)
    Plants.run()
end)

local function saveAll()
    if Actions.ready then Plants.save() end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then saveAll() end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', saveAll)
AddEventHandler('txAdmin:events:scheduledRestart', function(event)
    if event.secondsRemaining == 60 then saveAll() end
end)
