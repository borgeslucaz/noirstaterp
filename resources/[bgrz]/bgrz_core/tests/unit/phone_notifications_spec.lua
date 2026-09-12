local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { phone = 'sd-phone' } }
local state = 'started'
local sent
local provider = {}

function provider:notify(source, payload)
    sent = { source = source, payload = payload }
    return true
end

exports = T.exports({ ['sd-phone'] = provider })
GetResourceState = function() return state end

dofile('shared/provider.lua')
dofile('server/phone_notifications.lua')

local payload = {
    app = 'The Exchange',
    appId = 'exchange',
    title = 'Sale completed',
    body = 'A runner completed a sale.',
    ignored = function() end,
}
local ok, err = BGRZ.SendPhoneNotification(18, payload)
T.equal(ok, true, 'notification sent')
T.equal(err, nil, 'notification no error')
T.equal(sent.source, 18, 'notification target')
T.equal(sent.payload.title, 'Sale completed', 'notification title forwarded')
T.equal(sent.payload.ignored, nil, 'unknown field removed')
T.equal(payload.ignored ~= nil, true, 'caller payload not mutated')

ok, err = BGRZ.SendPhoneNotification(0, payload)
T.equal(ok, false, 'invalid source rejected')
T.equal(err, 'invalid_source', 'invalid source code')

ok, err = BGRZ.SendPhoneNotification(18, { body = 'missing title' })
T.equal(ok, false, 'invalid payload rejected')
T.equal(err, 'invalid_payload', 'invalid payload code')

provider.notify = function() return false end
ok, err = BGRZ.SendPhoneNotification(18, payload)
T.equal(ok, false, 'provider refusal returned')
T.equal(err, 'notification_failed', 'provider refusal code')

provider.notify = function() error('phone exploded') end
ok, err = BGRZ.SendPhoneNotification(18, payload)
T.equal(ok, false, 'provider exception returned')
T.equal(err, 'provider_unavailable', 'provider exception code')

state = 'stopped'
ok, err = BGRZ.SendPhoneNotification(18, payload)
T.equal(ok, false, 'stopped phone rejected')
T.equal(err, 'provider_unavailable', 'stopped phone code')

print('phone_notifications_spec: ok')
