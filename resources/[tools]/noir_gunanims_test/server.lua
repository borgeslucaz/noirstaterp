-- /testanims só para admin (ACE noir.gunanims.test, ver permissions.cfg).
lib.addCommand('testanims', {
    help = 'Menu de teste das animações de arma (ND_GunAnims)',
    restricted = 'noir.gunanims.test',
}, function(source)
    TriggerClientEvent('noir_gunanims_test:open', source)
end)

