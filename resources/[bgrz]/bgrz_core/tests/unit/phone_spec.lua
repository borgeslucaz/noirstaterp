local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { phone = 'sd-phone' } }
local state = 'started'
local caller = 'noir_outposts'
local calls = {}
local provider = {}

function provider:addCustomApp(definition)
    calls[#calls + 1] = { action = 'add', definition = definition }
    return true
end

function provider:removeCustomApp(identifier)
    calls[#calls + 1] = { action = 'remove', identifier = identifier }
    return true
end

exports = T.exports({ ['sd-phone'] = provider })
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
    requires = { item = 'outposts_exchange_card' },
}
local ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, true, 'phone app registered')
T.equal(err, nil, 'phone app no error')
T.equal(calls[#calls].definition.identifier, 'exchange', 'definition forwarded')
T.equal(definition.resource, nil, 'definition not mutated')

ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, true, 'owner can update app')

caller = 'noir_other'
local beforeCollision = #calls
ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, false, 'foreign identifier collision rejected')
T.equal(err, 'identifier_collision', 'foreign collision code')
T.equal(#calls, beforeCollision, 'collision not forwarded')

caller = 'event_runtime'
state = 'stopped'
T.fire(handlers, 'onClientResourceStart', 'sd-phone')
T.equal(#calls, beforeCollision, 'stopped phone not rehydrated')
state = 'started'
T.fire(handlers, 'onClientResourceStart', 'sd-phone')
T.equal(calls[#calls].action, 'add', 'phone restart rehydrates app')
T.equal(calls[#calls].definition.identifier, 'exchange', 'rehydrated identifier')

T.fire(handlers, 'onClientResourceStop', 'noir_outposts')
T.equal(calls[#calls].action, 'remove', 'caller stop removes app')
T.equal(calls[#calls].identifier, 'exchange', 'owned app removed')

caller = 'noir_outposts'
ok, err = BGRZ.RegisterPhoneApp({ identifier = '', name = 'Bad' })
T.equal(ok, false, 'invalid identifier rejected')
T.equal(err, 'invalid_definition', 'invalid definition code')

state = 'stopped'
ok, err = BGRZ.RegisterPhoneApp(definition)
T.equal(ok, false, 'stopped phone rejected')
T.equal(err, 'provider_unavailable', 'stopped phone code')

print('phone_spec: ok')
