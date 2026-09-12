local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = {
    Providers = {
        dispatch = 'sd-phone',
        dispatchFallback = 'qbx_police',
    },
}
local states = { ['sd-phone'] = 'started', qbx_police = 'started', qbx_core = 'started' }
local mdtCall
local clientEvents = {}
local phone = {}
local qbx = {}

function phone:mdtCreateCall(call)
    mdtCall = call
    return 'call-123'
end

function qbx:GetQBPlayers()
    return {
        [11] = { PlayerData = { source = 11, job = { name = 'police', onduty = true } } },
        [12] = { PlayerData = { source = 12, job = { name = 'police', onduty = false } } },
        [13] = { PlayerData = { source = 13, job = { name = 'ambulance', onduty = true } } },
    }
end

exports = T.exports({ ['sd-phone'] = phone, qbx_core = qbx })
GetResourceState = function(resource) return states[resource] or 'missing' end
TriggerClientEvent = function(name, target, ...)
    clientEvents[#clientEvents + 1] = { name = name, target = target, args = { ... } }
end

dofile('shared/provider.lua')
dofile('server/dispatch.lua')

local request = {
    code = '10-90',
    title = 'Suspicious activity',
    message = 'Possible drug sale',
    coords = { x = 125.5, y = -42.25, z = 31.0 },
    jobs = { 'police' },
    duration = 150,
    radius = 80.0,
}
local ok, result = BGRZ.SendDispatch(request)
T.equal(ok, true, 'primary dispatch sent')
T.equal(result.provider, 'sd-phone', 'primary dispatch provider')
T.equal(result.id, 'call-123', 'primary dispatch id')
T.equal(mdtCall.code, '10-90', 'dispatch code normalized')
T.equal(mdtCall.type, 'Suspicious activity', 'dispatch title normalized')
T.equal(mdtCall.location, 'Possible drug sale', 'dispatch message normalized')
T.equal(mdtCall.coords.x, 125.5, 'dispatch explicit x')
T.equal(mdtCall.coords.y, -42.25, 'dispatch explicit y')
T.equal(mdtCall.ttl, 150, 'dispatch duration normalized')

phone.mdtCreateCall = function() return nil end
clientEvents = {}
ok, result = BGRZ.SendDispatch(request)
T.equal(ok, true, 'fallback dispatch sent')
T.equal(result.provider, 'qbx_police', 'fallback provider')
T.equal(result.recipients, 1, 'fallback recipients')
T.equal(#clientEvents, 1, 'only matching on-duty police alerted')
T.equal(clientEvents[1].name, 'police:client:policeAlert', 'police client event')
T.equal(clientEvents[1].target, 11, 'police target source')
T.equal(clientEvents[1].args[1].x, 125.5, 'fallback explicit coords')
T.equal(clientEvents[1].args[2], 'Possible drug sale', 'fallback message')

local beforeEvents = #clientEvents
ok, result = BGRZ.SendDispatch({ title = 'No coords' })
T.equal(ok, false, 'missing coords rejected')
T.equal(result, 'invalid_coords', 'missing coords code')
T.equal(#clientEvents, beforeEvents, 'invalid dispatch not emitted')

ok, result = BGRZ.SendDispatch({
    title = 'Bad jobs', coords = request.coords, jobs = { 12 },
})
T.equal(ok, false, 'invalid jobs rejected')
T.equal(result, 'invalid_jobs', 'invalid jobs code')

states['sd-phone'] = 'stopped'
states.qbx_police = 'stopped'
ok, result = BGRZ.SendDispatch(request)
T.equal(ok, false, 'no dispatch provider rejected')
T.equal(result, 'provider_unavailable', 'no dispatch provider code')

print('dispatch_spec: ok')
