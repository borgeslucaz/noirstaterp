local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }
local state = 'started'
local revived
local reviveThrows = false
local playerStates = { [1] = { isDead = true }, [2] = { isDead = false } }
local balances = { cash = 150, bank = 900 }

local medical = {}
function medical:Revive(source)
    if reviveThrows then error('provider exploded') end
    revived = source
end

local qbx = {}
function qbx:GetMoney(source, account)
    if source ~= 1 then return false end
    return balances[account]
end

exports = T.exports({ qbx_medical = medical, qbx_core = qbx })
GetResourceState = function() return state end
GetCurrentResourceName = function() return 'bgrz_core' end
AddEventHandler = function() end
RegisterNetEvent = function() end
TriggerEvent = function() end
Player = function(source) return { state = playerStates[source] or {} } end

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')
dofile('server/medical.lua')

T.equal(BGRZ.Medical.IsDowned(1), true, 'downed player')
T.equal(BGRZ.Medical.IsDowned(2), false, 'alive player')
T.equal(BGRZ.Medical.IsDowned(3), false, 'unknown player')
T.equal(BGRZ.Medical.IsDowned('1'), false, 'string source rejected')

local ok, err = BGRZ.Medical.Revive(1)
T.equal(ok, true, 'revive ok')
T.equal(revived, 1, 'revive forwarded')

ok, err = BGRZ.Medical.Revive(0)
T.equal(err, 'invalid_source', 'zero source rejected')

reviveThrows = true
ok, err = BGRZ.Medical.Revive(1)
T.equal(ok, false, 'provider exception handled')
T.equal(err, 'provider_unavailable', 'provider exception code')
reviveThrows = false

state = 'stopped'
ok, err = BGRZ.Medical.Revive(1)
T.equal(err, 'provider_unavailable', 'stopped provider')
state = 'started'

T.equal(BGRZ.GetMoney(1, 'bank'), 900, 'bank balance')
T.equal(BGRZ.GetMoney(1, 'cash'), 150, 'cash balance')
T.equal(BGRZ.GetMoney(2, 'bank'), 0, 'offline player has 0')

print('medical_spec: ok')
