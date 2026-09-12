local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = {
    Version = '0.5.0',
    Providers = {
        inventory = 'ox_inventory',
        target = 'ox_target',
        phone = 'sd-phone',
        dispatch = 'sd-phone',
        dispatchFallback = 'qbx_police',
    },
}
local states = {
    ox_inventory = 'started',
    ox_target = 'started',
    ['sd-phone'] = 'stopped',
    qbx_police = 'started',
}
exports = T.exports()
GetResourceState = function(resource) return states[resource] or 'missing' end

dofile('shared/provider.lua')
dofile('shared/capabilities.lua')

local capabilities = BGRZ.GetCapabilities()
T.equal(capabilities.version, '0.5.0', 'bridge version')
T.equal(capabilities.inventory.available, true, 'inventory available')
T.equal(capabilities.inventory.provider, 'ox_inventory', 'inventory provider')
T.equal(capabilities.inventory.maxItemAmount, 100000, 'inventory operation limit')
T.equal(capabilities.target.available, true, 'target available')
T.equal(capabilities.phone.available, false, 'optional phone unavailable')
T.equal(capabilities.dispatch.available, true, 'dispatch fallback available')
T.equal(capabilities.dispatch.provider, 'qbx_police', 'dispatch fallback selected')

capabilities.inventory.available = false
T.equal(BGRZ.GetCapabilities().inventory.available, true, 'capabilities are fresh values')

states['sd-phone'] = 'started'
capabilities = BGRZ.GetCapabilities()
T.equal(capabilities.phone.available, true, 'phone became available')
T.equal(capabilities.dispatch.provider, 'sd-phone', 'primary dispatch selected')

print('capabilities_spec: ok')
