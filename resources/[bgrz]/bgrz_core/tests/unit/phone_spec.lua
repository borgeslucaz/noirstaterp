local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { phone = 'sky_phone' } }
local state = 'started'
local caller = 'noir_outposts'
local calls = {}
local provider = {}

-- Imita o sky_phone: id repetido é recusado no add e só entra pelo update.
local installed = {}

function provider:AddCustomAppFromAdapter(owner, definition)
    if installed[definition.id] then return false, 'duplicate_app_id' end
    installed[definition.id] = owner
    calls[#calls + 1] = { action = 'add', owner = owner, definition = definition }
    return true
end

function provider:UpdateCustomAppFromAdapter(owner, definition)
    if not installed[definition.id] then return false, 'app_not_found' end
    calls[#calls + 1] = { action = 'update', owner = owner, definition = definition }
    return true
end

function provider:RemoveCustomAppFromAdapter(owner, identifier)
    installed[identifier] = nil
    calls[#calls + 1] = { action = 'remove', owner = owner, identifier = identifier }
    return true
end

exports = T.exports({ sky_phone = provider })
GetResourceState = function() return state end
GetInvokingResource = function() return caller end
GetCurrentResourceName = function() return 'bgrz_core' end
local handlers
handlers, AddEventHandler = T.events()

dofile('shared/provider.lua')
dofile('client/phone.lua')

local definition = {
    identifier = 'exchange',
    name = 'The Exchange',
    ui = 'https://cfx-nui-noir_outposts/html/phone/index.html',
    defaultApp = true,
    requires = { item = 'outposts_exchange_card' },
}
local ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, true, 'phone app registered')
T.equal(err, nil, 'phone app no error')
T.equal(calls[#calls].definition.id, 'exchange', 'definition forwarded')
T.equal(calls[#calls].owner, 'noir_outposts', 'app registered in the caller name')
T.equal(calls[#calls].definition.defaultInstalled, true, 'defaultApp mapped')
T.equal(calls[#calls].definition.requires, nil, 'requires not forwarded')
T.equal(definition.resource, nil, 'definition not mutated')

ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, true, 'owner can update app')
T.equal(calls[#calls].action, 'update', 'owner re-register goes through update')

caller = 'noir_other'
local beforeCollision = #calls
ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, false, 'foreign identifier collision rejected')
T.equal(err, 'identifier_collision', 'foreign collision code')
T.equal(#calls, beforeCollision, 'collision not forwarded')

caller = 'event_runtime'
state = 'stopped'
installed = {}
T.fire(handlers, 'onClientResourceStart', 'sky_phone')
T.equal(#calls, beforeCollision, 'stopped phone not rehydrated')
state = 'started'
T.fire(handlers, 'onClientResourceStart', 'sky_phone')
T.equal(calls[#calls].action, 'add', 'phone restart rehydrates app')
T.equal(calls[#calls].definition.id, 'exchange', 'rehydrated identifier')
T.equal(calls[#calls].owner, 'noir_outposts', 'rehydrated in the owner name')

T.fire(handlers, 'onClientResourceStop', 'noir_outposts')
T.equal(calls[#calls].action, 'remove', 'caller stop removes app')
T.equal(calls[#calls].identifier, 'exchange', 'owned app removed')
T.equal(calls[#calls].owner, 'noir_outposts', 'removed in the owner name')

caller = 'noir_outposts'
ok, err = BGRZ.RegisterPhoneApp({ identifier = '', name = 'Bad' })
T.equal(ok, false, 'invalid identifier rejected')
T.equal(err, 'invalid_definition', 'invalid definition code')

state = 'stopped'
ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, false, 'stopped phone rejected')
T.equal(err, 'provider_unavailable', 'stopped phone code')

print('phone_spec: ok')
