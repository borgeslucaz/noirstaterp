local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { phone = 'sd-phone' } }
local state = 'started'
local caller = 'noir_outposts'
local sent = {}
local providerResult = true
local provider = {}

function provider:addCustomApp() return true end
function provider:removeCustomApp() return true end
function provider:sendCustomAppMessage(identifier, message)
    sent[#sent + 1] = { identifier = identifier, message = message }
    return providerResult
end

exports = T.exports({ ['sd-phone'] = provider })
GetResourceState = function() return state end
GetInvokingResource = function() return caller end
GetCurrentResourceName = function() return 'bgrz_core' end
local handlers
handlers, AddEventHandler = T.events()

dofile('shared/provider.lua')
dofile('client/phone.lua')

local ok, err = BGRZ.SendPhoneAppMessage('exchange', { action = 'state' })
T.equal(ok, false, 'unregistered app rejected')
T.equal(err, 'not_registered', 'unregistered code')

T.equal(BGRZ.RegisterPhoneApp({ identifier = 'exchange', name = 'The Exchange' }), true, 'app registered')

ok, err = BGRZ.SendPhoneAppMessage('exchange', { action = 'state', data = { a = 1 } })
T.equal(ok, true, 'owner message sent')
T.equal(err, nil, 'owner message no error')
T.equal(sent[#sent].identifier, 'exchange', 'identifier forwarded')
T.equal(sent[#sent].message.action, 'state', 'message forwarded')

ok, err = BGRZ.SendPhoneAppMessage('exchange', 'text')
T.equal(ok, false, 'non-table message rejected')
T.equal(err, 'invalid_message', 'invalid message code')

ok, err = BGRZ.SendPhoneAppMessage('bad id!', {})
T.equal(ok, false, 'invalid identifier rejected')
T.equal(err, 'invalid_identifier', 'invalid identifier code')

caller = 'noir_other'
local before = #sent
ok, err = BGRZ.SendPhoneAppMessage('exchange', { action = 'state' })
T.equal(ok, false, 'foreign caller rejected')
T.equal(err, 'not_owner', 'foreign caller code')
T.equal(#sent, before, 'foreign message not forwarded')

caller = 'noir_outposts'
providerResult = false
ok, err = BGRZ.SendPhoneAppMessage('exchange', { action = 'state' })
T.equal(ok, false, 'provider refusal surfaced')
T.equal(err, 'operation_failed', 'provider refusal code')
providerResult = true

state = 'stopped'
ok, err = BGRZ.SendPhoneAppMessage('exchange', { action = 'state' })
T.equal(ok, false, 'stopped phone rejected')
T.equal(err, 'provider_unavailable', 'stopped phone code')
state = 'started'

T.fire(handlers, 'onClientResourceStop', 'noir_outposts')
ok, err = BGRZ.SendPhoneAppMessage('exchange', { action = 'state' })
T.equal(ok, false, 'stopped owner loses registration')
T.equal(err, 'not_registered', 'stopped owner code')

print('phone_message_spec: ok')
