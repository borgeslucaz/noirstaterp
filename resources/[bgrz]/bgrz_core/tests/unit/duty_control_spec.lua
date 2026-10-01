local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }
local state = 'started'
local players = { [1] = { PlayerData = { job = { name = 'police', type = 'leo', grade = { level = 2 }, onduty = true } } } }
local dutyCalls = {}
local typeResult = { 2, { 1, '4', 0, -3 } }
local qbx = {}

function qbx:GetPlayer(source) return players[source] end
function qbx:SetJobDuty(source, onDuty)
    if onDuty == 'throw' then error('provider exploded') end
    dutyCalls[#dutyCalls + 1] = { source, onDuty }
end
function qbx:GetDutyCountType(jobType)
    if typeResult == 'throw' then error('provider exploded') end
    return typeResult[1], typeResult[2]
end

exports = T.exports({ qbx_core = qbx })
GetResourceState = function() return state end
GetCurrentResourceName = function() return 'bgrz_core' end
AddEventHandler = function() end
RegisterNetEvent = function() end
TriggerEvent = function() end

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')

-- GetJob expõe a categoria.
local job = BGRZ.GetJob(1)
T.equal(job.type, 'leo', 'job type exposed')
T.equal(job.grade, 2, 'grade normalized')

-- SetJobDuty
local ok, err = BGRZ.SetJobDuty(1, false)
T.truthy(ok, 'duty toggled')
T.equal(dutyCalls[1][1], 1, 'source forwarded')
T.equal(dutyCalls[1][2], false, 'state forwarded')

ok, err = BGRZ.SetJobDuty(1, 'yes')
T.falsy(ok, 'non-boolean rejected')
T.equal(err, 'invalid_state', 'non-boolean code')

ok, err = BGRZ.SetJobDuty(0, true)
T.equal(err, 'invalid_player', 'zero source rejected')

ok, err = BGRZ.SetJobDuty(9, true)
T.equal(err, 'invalid_player', 'unloaded player rejected')

state = 'stopped'
ok, err = BGRZ.SetJobDuty(1, true)
T.equal(err, 'provider_unavailable', 'stopped provider code')
state = 'started'

-- GetOnDutyPlayersByType
local sources
sources, err = BGRZ.GetOnDutyPlayersByType('leo')
T.equal(#sources, 2, 'only valid sources kept')
T.equal(sources[1], 1, 'first source')
T.equal(sources[2], 4, 'numeric string coerced')

sources, err = BGRZ.GetOnDutyPlayersByType('bad type')
T.equal(err, 'invalid_job_type', 'invalid type rejected')

typeResult = 'throw'
sources, err = BGRZ.GetOnDutyPlayersByType('leo')
T.equal(err, 'provider_unavailable', 'provider exception code')

typeResult = { 0, nil }
sources, err = BGRZ.GetOnDutyPlayersByType('leo')
T.equal(err, 'operation_failed', 'missing list code')

print('duty_control_spec: ok')
