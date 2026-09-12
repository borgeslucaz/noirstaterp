local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }
local state = 'started'
local dutyResult = 3
local requestedJob
local qbx = {}

function qbx:GetDutyCountJob(job)
    requestedJob = job
    if dutyResult == 'throw' then error('provider exploded') end
    return dutyResult, {}
end

exports = T.exports({ qbx_core = qbx })
GetResourceState = function() return state end
GetCurrentResourceName = function() return 'bgrz_core' end
AddEventHandler = function() end
RegisterNetEvent = function() end
TriggerEvent = function() end

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')

local count, err = BGRZ.CountOnDutyJob('police')
T.equal(count, 3, 'duty count returned')
T.equal(err, nil, 'duty count no error')
T.equal(requestedJob, 'police', 'job forwarded')

count, err = BGRZ.CountOnDutyJob('')
T.equal(count, nil, 'empty job rejected')
T.equal(err, 'invalid_job', 'empty job code')

count, err = BGRZ.CountOnDutyJob('bad job')
T.equal(err, 'invalid_job', 'job with spaces rejected')

dutyResult = 'throw'
count, err = BGRZ.CountOnDutyJob('police')
T.equal(count, nil, 'provider exception handled')
T.equal(err, 'provider_unavailable', 'provider exception code')

dutyResult = -1
count, err = BGRZ.CountOnDutyJob('police')
T.equal(count, nil, 'negative count rejected')
T.equal(err, 'operation_failed', 'negative count code')

dutyResult = 2.7
count, err = BGRZ.CountOnDutyJob('police')
T.equal(count, 2, 'count floored')

state = 'stopped'
count, err = BGRZ.CountOnDutyJob('police')
T.equal(count, nil, 'stopped core rejected')
T.equal(err, 'provider_unavailable', 'stopped core code')

print('duty_count_spec: ok')
