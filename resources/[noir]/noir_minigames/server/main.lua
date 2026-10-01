---Comando do menu de teste. A ACE é conferida aqui; o cliente só abre o menu quando o
---servidor manda.

local Config = require 'config.server'

RegisterCommand(Config.command, function(source)
    if source == 0 then return end
    if not IsPlayerAceAllowed(source, Config.adminAce) then
        lib.notify(source, { type = 'error', description = locale('no_permission') })
        return
    end
    TriggerClientEvent('noir_minigames:client:openMenu', source)
end, false)

-- Sugestão no chat só para quem pode usar.
AddEventHandler('playerJoining', function()
    local source = source
    if IsPlayerAceAllowed(source, Config.adminAce) then
        TriggerClientEvent('chat:addSuggestion', source, '/' .. Config.command, locale('command_help'))
    end
end)
