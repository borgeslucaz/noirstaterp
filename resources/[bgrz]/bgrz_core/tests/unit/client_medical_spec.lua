local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }
local state = 'started'
local medicalState = 'laststand'
local accepted = true
local throws = false

local medical = {}
function medical:IsLaststand() if throws then error('boom') end return medicalState == 'laststand' end
function medical:IsDead() return medicalState == 'dead' end
function medical:GetLaststandTime() return 212.6 end
function medical:GetDeathTime() return -3 end
function medical:RequestRespawn() return accepted end

local events, addHandler = T.events()
local triggered = {}
exports = T.exports({ qbx_medical = medical })
GetResourceState = function() return state end
AddEventHandler = addHandler
TriggerEvent = function(name) triggered[#triggered + 1] = name end

dofile('shared/provider.lua')
dofile('client/medical.lua')

local info = BGRZ.Medical.GetDownedInfo()
T.equal(info.state, 'laststand', 'laststand state')
T.equal(info.seconds, 212, 'laststand seconds floored')

medicalState = 'dead'
info = BGRZ.Medical.GetDownedInfo()
T.equal(info.state, 'dead', 'dead state')
T.equal(info.seconds, 0, 'negative seconds clamped')

medicalState = 'alive'
T.equal(BGRZ.Medical.GetDownedInfo(), nil, 'alive returns nil')

throws = true
T.equal(BGRZ.Medical.GetDownedInfo(), nil, 'provider exception returns nil')
throws = false

T.equal(BGRZ.Medical.RequestRespawn(), true, 'respawn accepted')
accepted = false
T.equal(BGRZ.Medical.RequestRespawn(), false, 'respawn refused')

state = 'stopped'
T.equal(BGRZ.Medical.GetDownedInfo(), nil, 'stopped provider')
T.equal(BGRZ.Medical.RequestRespawn(), false, 'stopped provider respawn')

T.fire(events, 'qbx_medical:client:onPlayerRespawned')
T.equal(triggered[1], 'bgrz_core:client:playerRespawned', 'respawn re-emitted')

print('client_medical_spec: ok')
