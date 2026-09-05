
RegisterNetEvent('grot_fastmechanic:applyMods')
AddEventHandler('grot_fastmechanic:applyMods', function(mods)
    local src = source
end)
RegisterNetEvent('grot_fastmechanic:log')
AddEventHandler('grot_fastmechanic:log', function(message)
    local src = source
    print('[FastMechanic] Gracz ' .. GetPlayerName(src) .. ': ' .. message)
end)
