local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { phone = 'sky_phone' } }
local state = 'started'
local sent
local alias = {}

-- O sky_phone recebe a notificação solta pelo alias de compatibilidade qs-smartphone.
function alias:sendPhoneNotification(source, payload)
    sent = { source = source, payload = payload }
end

exports = T.exports({ sky_phone = {}, ['qs-smartphone'] = alias })
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
T.equal(sent.payload.body, 'A runner completed a sale.', 'notification body forwarded')
T.equal(sent.payload.appId, 'exchange', 'app id forwarded')
T.equal(sent.payload.ignored, nil, 'unknown field removed')

BGRZ.SendPhoneNotification(18, { title = 'Olheiro', body = 'Carga à vista.' })
T.equal(sent.payload.appId, 'noir', 'missing app id falls back to the default')
BGRZ.SendPhoneNotification(18, { title = 'Olheiro', appId = 'Bad Id!' })
T.equal(sent.payload.appId, 'noir', 'invalid app id falls back to the default')
T.equal(sent.payload.body, 'Olheiro', 'missing body reuses the title')
T.equal(payload.ignored ~= nil, true, 'caller payload not mutated')

ok, err = BGRZ.SendPhoneNotification(0, payload)
T.equal(ok, false, 'invalid source rejected')
T.equal(err, 'invalid_source', 'invalid source code')

ok, err = BGRZ.SendPhoneNotification(18, { body = 'missing title' })
T.equal(ok, false, 'invalid payload rejected')
T.equal(err, 'invalid_payload', 'invalid payload code')

alias.sendPhoneNotification = function() error('phone exploded') end
ok, err = BGRZ.SendPhoneNotification(18, payload)
T.equal(ok, false, 'provider exception returned')
T.equal(err, 'provider_unavailable', 'provider exception code')

state = 'stopped'
ok, err = BGRZ.SendPhoneNotification(18, payload)
T.equal(ok, false, 'stopped phone rejected')
T.equal(err, 'provider_unavailable', 'stopped phone code')

-- SMS anônimo ---------------------------------------------------------------------------
local skyPhone = {}
local anonymous
function skyPhone:SendAnonymousMessage(citizenId, body)
    anonymous = { citizenId = citizenId, body = body }
    if citizenId == 'NOSIM' then return 0, 'no_sim' end
    return 2, '5551234567'
end
exports = T.exports({ sky_phone = skyPhone, ['qs-smartphone'] = alias })
state = 'started'

ok, err = BGRZ.SendPhoneAnonymousMessage('CID1', 'Ouvi falar de vocês.')
T.equal(ok, true, 'anonymous sent')
T.equal(err, 2, 'chips reached')
T.equal(anonymous.citizenId, 'CID1', 'recipient forwarded')
ok, err = BGRZ.SendPhoneAnonymousMessage('NOSIM', 'x')
T.equal(ok, false, 'no registered sim')
T.equal(err, 'no_sim', 'no sim code')
ok, err = BGRZ.SendPhoneAnonymousMessage('', 'x')
T.equal(err, 'invalid_recipient', 'empty recipient')
ok, err = BGRZ.SendPhoneAnonymousMessage('CID1', '')
T.equal(err, 'invalid_message', 'empty body')
state = 'stopped'
ok, err = BGRZ.SendPhoneAnonymousMessage('CID1', 'x')
T.equal(err, 'provider_unavailable', 'phone down')

print('phone_notifications_spec: ok')
