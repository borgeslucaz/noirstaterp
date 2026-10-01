local trunkBusy = {}

RegisterNetEvent('qb-radialmenu:trunk:server:Door', function(open, plate, door)
    TriggerClientEvent('qb-radialmenu:trunk:client:Door', -1, plate, door, open)
end)

RegisterNetEvent('qb-trunk:server:setTrunkBusy', function(plate, busy)
    trunkBusy[plate] = busy
end)

-- noir_police: 'qb-trunk:server:KidnapTrunk' saiu; aceitava qualquer alvo e qualquer carro.
-- O porta-malas é pelo callback noir_police:server:putInTrunk.

lib.callback.register('qb-trunk:server:getTrunkBusy', function(_, plate)
    return trunkBusy[plate]
end)

lib.addCommand('getintrunk', {
    help = locale("general.getintrunk_command_desc"),
}, function(source)
    TriggerClientEvent('qb-trunk:client:GetIn', source)
end)

lib.addCommand('putintrunk', {
    help = locale("general.putintrunk_command_desc"),
}, function(source)
    TriggerClientEvent('qb-trunk:server:KidnapTrunk', source)
end)
