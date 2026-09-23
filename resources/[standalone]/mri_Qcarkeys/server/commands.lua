local Bridge = require 'server.bridge'

lib.addCommand('givetempkeys', {
    help = 'Give Temporary Keys',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Target player\'s server id',
            optional = true,
        },
        {
            name = 'plate',
            type = 'string',
            help = 'Número da placa do veículo',
            optional = true,
        }
    },
    restricted = 'group.admin'
}, function(source, args)
    local plate = args.plate
    if not plate then
        plate = lib.callback.await('mm_carkeys:client:getplate', source)
        if not plate then
            local ndata = {
                description = 'Você não está em um veículo',
                type = 'error'
            }
            TriggerClientEvent('ox_lib:notify', source, ndata)
            return
        end
    end
    GiveTempKeys(args.target or source, plate)
end)

lib.addCommand('removetempkeys', {
    help = 'Remove Temporary Keys',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Target player\'s server id',
            optional = true,
        },
        {
            name = 'plate',
            type = 'string',
            help = 'Número da placa do veículo',
            optional = true,
        }
    },
    restricted = 'group.admin'
}, function(source, args)
    local plate = args.plate
    if not plate then
        plate = lib.callback.await('mm_carkeys:client:getplate', source)
        if not plate then
            local ndata = {
                description = 'Você não está em um veículo',
                type = 'error'
            }
            TriggerClientEvent('ox_lib:notify', source, ndata)
            return
        end
    end
    RemoveTempKeys(args.target or source, plate)
end)

-- Admin entrega a chave definitiva (item) de uma placa. Serve para quem ja tinha carro antes da
-- chave virar item, e para dar a copia a um segundo motorista.
lib.addCommand('givekeys', {
    help = 'Dar a chave definitiva de um veiculo',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Server id do jogador (padrao: voce)',
            optional = true,
        },
        {
            name = 'plate',
            type = 'string',
            help = 'Placa (padrao: o veiculo em que voce esta)',
            optional = true,
        }
    },
    restricted = 'group.admin'
}, function(source, args)
    local plate = args.plate or lib.callback.await('mm_carkeys:client:getplate', source)
    if not plate then
        TriggerClientEvent('ox_lib:notify', source, { description = 'Informe a placa ou entre no veiculo', type = 'error' })
        return
    end
    local target = args.target or source
    GivePermanentKeyForPlate(target, NormalizePlate(plate))
    TriggerClientEvent('ox_lib:notify', source, { description = ('Chave %s entregue ao id %s'):format(NormalizePlate(plate), target), type = 'success' })
end)

lib.addCommand('removekeys', {
    help = 'Remove Permanent Keys',
    params = {},
}, function(source)
    local src = source
    local playerJob = Bridge:GetPlayerJob(src)
    if playerJob == "police" or playerJob == "cardealer" or IsPlayerAceAllowed(src, "admin") or playerJob['police'] or playerJob['cardealer'] then
        TriggerClientEvent('mm_carkeys:client:removekeyitem', src)
        return
    end
    local ndata = {
		title = 'Falhou',
    	description = 'Not Verified',
    	type = 'error'
	}
    TriggerClientEvent('ox_lib:notify', source, ndata)
end)

lib.addCommand('stackkeys', {
    help = 'Stack Permanent Keys',
    params = {},
}, function(source)
    local src = source
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    if not next(keys) then
        local ndata = {
            description = 'You don\'t have any keys',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, ndata)
        return
    end
    TriggerClientEvent('mm_carkeys:client:stackkeys', src)
end)

lib.addCommand('unstackkeys', {
    help = 'Unstack Permanent Keys',
    params = {},
}, function(source)
    local src = source
    local bag = Bridge:GetPlayerItemsByName(src, 'keybag')
    if not bag then
        local ndata = {
            description = 'You don\'t have a key bag',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, ndata)
        return
    end
    TriggerClientEvent('mm_carkeys:client:unstackkeys', src)
end)