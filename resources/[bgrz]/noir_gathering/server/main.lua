---Boot do servidor e callbacks de admin.

local Config = require 'config.server'
local Storage = require 'server.storage'
local Routes = require 'server.routes'
local Sessions = require 'server.sessions'
local Security = require 'server.security'
local Integrations = require 'server.integrations'

local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.adminAce)
end

local function adminGuard(source)
    if not isAdmin(source) then return { ok = false, error = 'not_allowed' } end
    if not Storage.isReady() then return { ok = false, error = 'storage_failed' } end
    if not Security.rateLimit(source, 'admin') then return { ok = false, error = 'busy' } end
end

lib.callback.register('noir_gathering:server:adminData', function(source)
    local refused = adminGuard(source)
    if refused then return refused end
    return {
        ok = true,
        routes = Routes.list(),
        items = Integrations.itemList(),
        jobs = Integrations.jobList(),
        gangs = Integrations.gangList(),
    }
end)

lib.callback.register('noir_gathering:server:adminSave', function(source, id, route)
    local refused = adminGuard(source)
    if refused then return refused end
    local savedId, err = Routes.save(id, route)
    if not savedId then return { ok = false, error = err } end
    lib.print.info(('rota %d salva por %s'):format(savedId, GetPlayerName(source)))
    return { ok = true, id = savedId, route = Routes.get(savedId) }
end)

lib.callback.register('noir_gathering:server:adminDelete', function(source, id)
    local refused = adminGuard(source)
    if refused then return refused end
    local ok, err = Routes.delete(id)
    if not ok then return { ok = false, error = err } end
    lib.print.info(('rota %d apagada por %s'):format(id, GetPlayerName(source)))
    return { ok = true }
end)

lib.addCommand(Config.adminCommand, { help = locale('command_help') }, function(source)
    if not isAdmin(source) then
        Integrations.notify(source, locale('error_not_allowed'), 'error')
        return
    end
    TriggerClientEvent('noir_gathering:client:openCreator', source)
end)

Sessions.register()

MySQL.ready(function()
    local ok, err = pcall(function()
        Storage.migrate()
        Routes.load()
    end)
    if not ok then lib.print.error(('falha ao preparar o banco: %s'):format(err)) end
end)
