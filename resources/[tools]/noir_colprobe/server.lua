-- /colprobe só para admin (ACE noir.colprobe, ver permissions.cfg). O resultado sai no
-- console do servidor para ser lido no log.
lib.addCommand('colprobe', {
    help = 'Diagnóstico de colisão na frente do personagem',
    restricted = 'noir.colprobe',
}, function(source)
    TriggerClientEvent('noir_colprobe:run', source)
end)

RegisterNetEvent('noir_colprobe:report', function(lines)
    if not IsPlayerAceAllowed(source, 'noir.colprobe') or type(lines) ~= 'table' then return end
    for i = 1, math.min(#lines, 80) do
        print(('[colprobe %s] %s'):format(source, tostring(lines[i])))
    end
end)

lib.addCommand('colview', {
    help = 'Liga/desliga o desenho da colisão do mrp_house em volta do personagem',
    restricted = 'noir.colprobe',
}, function(source)
    TriggerClientEvent('noir_colprobe:colview', source)
end)
