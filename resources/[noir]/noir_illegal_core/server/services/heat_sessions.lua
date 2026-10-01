-- Login e logout do personagem para o decaimento por hora jogada (heat_service.lua).

local Service = NoirIllegal.Services.Heat

AddEventHandler('bgrz_core:server:playerLoaded', function(source)
    local identity = NoirIllegal.Bridges.Qbox.getIdentity(source)
    if identity then Service.startSession(identity.source, identity.citizenId) end
end)

AddEventHandler('bgrz_core:server:playerUnloaded', function(source)
    Service.endSession(tonumber(source))
end)

AddEventHandler('playerDropped', function()
    Service.endSession(source)
end)

-- Restart do core com gente dentro: quem já está online segue decaindo de onde parou.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, playerId in ipairs(GetPlayers()) do
        local identity = NoirIllegal.Bridges.Qbox.getIdentity(tonumber(playerId))
        if identity then Service.resumeSession(identity.source, identity.citizenId) end
    end
end)
