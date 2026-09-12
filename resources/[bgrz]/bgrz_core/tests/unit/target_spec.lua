local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { target = 'ox_target' } }
local state = 'started'
local caller = 'noir_outposts'
local calls = {}
local provider = {}
local nextZoneId = 100

function provider:addEntity(entity, options)
    calls[#calls + 1] = { action = 'addEntity', entity = entity, options = options }
end

function provider:removeEntity(entity, names)
    calls[#calls + 1] = { action = 'removeEntity', entity = entity, names = names }
end

function provider:addLocalEntity(entity, options)
    calls[#calls + 1] = { action = 'addLocalEntity', entity = entity, options = options }
end

function provider:removeLocalEntity(entity, names)
    calls[#calls + 1] = { action = 'removeLocalEntity', entity = entity, names = names }
end

function provider:addSphereZone(definition)
    nextZoneId = nextZoneId + 1
    calls[#calls + 1] = { action = 'addSphereZone', definition = definition, id = nextZoneId }
    return nextZoneId
end

function provider:removeZone(id, suppressWarning)
    calls[#calls + 1] = { action = 'removeZone', id = id, suppressWarning = suppressWarning }
end

exports = T.exports({ ox_target = provider })
GetResourceState = function() return state end
GetInvokingResource = function() return caller end
NetworkDoesNetworkIdExist = function(value) return value == 42 end
DoesEntityExist = function(value) return value == 200 end
local handlers
handlers, AddEventHandler = T.events()
GetCurrentResourceName = function() return 'bgrz_core' end

dofile('shared/provider.lua')
dofile('client/target.lua')

local options = {
    { name = 'rob', label = 'Rob dealer' },
    { name = 'stock', label = 'Stock dealer' },
}
local ok, err = BGRZ.AddEntityTarget(42, options)
T.equal(ok, true, 'network target added')
T.equal(err, nil, 'network target no error')
T.equal(calls[#calls].action, 'addEntity', 'network provider method')
T.equal(calls[#calls].options[1].name, 'noir_outposts:rob', 'network option namespaced')
T.equal(options[1].name, 'rob', 'caller options not mutated')

caller = 'noir_other'
ok, err = BGRZ.AddEntityTarget(42, { { name = 'rob', label = 'Inspect' } })
T.equal(ok, true, 'same public name allowed for another owner')
T.equal(calls[#calls].options[1].name, 'noir_other:rob', 'second owner namespaced')

ok, err = BGRZ.RemoveEntityTarget(42, 'stock')
T.equal(ok, false, 'caller cannot remove foreign option')
T.equal(err, 'not_owner', 'foreign removal code')

caller = 'noir_outposts'
ok, err = BGRZ.RemoveEntityTarget(42, 'rob')
T.equal(ok, true, 'owned target removed')
T.equal(calls[#calls].action, 'removeEntity', 'network remove method')
T.equal(calls[#calls].names[1], 'noir_outposts:rob', 'owned provider name removed')

ok, err = BGRZ.AddEntityTarget(200, { name = 'talk', label = 'Talk' })
T.equal(ok, true, 'local target added')
T.equal(calls[#calls].action, 'addLocalEntity', 'local provider method')

ok, err = BGRZ.AddSphereZoneTarget({
    name = 'computer:docks',
    coords = { x = 1.0, y = 2.0, z = 3.0 },
    radius = 2.5,
    drawSprite = true,
    options = { { name = 'open', label = 'Open terminal' } },
})
T.equal(ok, true, 'sphere zone added')
T.equal(calls[#calls].action, 'addSphereZone', 'sphere provider method')
T.equal(calls[#calls].definition.name, 'noir_outposts:computer:docks', 'zone name namespaced')
T.equal(calls[#calls].definition.options[1].name, 'noir_outposts:open', 'zone option namespaced')
local firstZoneId = calls[#calls].id

ok, err = BGRZ.AddSphereZoneTarget({
    name = 'computer:docks', coords = { x = 1.0, y = 2.0, z = 3.0 }, radius = 2.5,
    options = { { name = 'open', label = 'Open terminal' } },
})
T.equal(ok, false, 'duplicate owned zone rejected')
T.equal(err, 'already_exists', 'duplicate zone code')

caller = 'noir_other'
ok, err = BGRZ.RemoveZoneTarget('computer:docks')
T.equal(ok, false, 'caller cannot remove foreign zone')
T.equal(err, 'not_owner', 'foreign zone removal code')

caller = 'event_runtime'
local beforeRehydrate = #calls
T.fire(handlers, 'onClientResourceStart', 'ox_target')
local rehydratedZone
for index = beforeRehydrate + 1, #calls do
    if calls[index].action == 'addSphereZone' then rehydratedZone = calls[index] end
end
T.truthy(rehydratedZone, 'provider restart rehydrates zone')
T.truthy(rehydratedZone.id ~= firstZoneId, 'rehydrated zone stores new provider id')

local beforeCleanup = #calls
T.fire(handlers, 'onClientResourceStop', 'noir_outposts')
local cleanedLocal
local cleanedZone
for index = beforeCleanup + 1, #calls do
    if calls[index].action == 'removeLocalEntity' then cleanedLocal = calls[index] end
    if calls[index].action == 'removeZone' then cleanedZone = calls[index] end
end
T.truthy(cleanedLocal, 'caller stop cleans local target')
T.equal(cleanedLocal.names[1], 'noir_outposts:talk', 'cleanup removes owned option')
T.truthy(cleanedZone, 'caller stop cleans owned zone')
T.equal(cleanedZone.id, rehydratedZone.id, 'cleanup uses rehydrated provider id')

caller = 'noir_outposts'
ok, err = BGRZ.AddEntityTarget(0, options)
T.equal(ok, false, 'invalid entity rejected')
T.equal(err, 'invalid_entity', 'invalid entity code')

ok, err = BGRZ.AddSphereZoneTarget({
    name = 'bad', coords = { x = 0 / 0, y = 0, z = 0 }, radius = 1,
    options = { { name = 'open', label = 'Open' } },
})
T.equal(ok, false, 'invalid zone coordinates rejected')
T.equal(err, 'invalid_coords', 'invalid zone coordinate code')

caller = 'event_runtime'
local beforeBridgeStop = #calls
T.fire(handlers, 'onClientResourceStop', 'bgrz_core')
local bridgeStopCleanup
for index = beforeBridgeStop + 1, #calls do
    if calls[index].action == 'removeEntity' then bridgeStopCleanup = calls[index] end
end
T.truthy(bridgeStopCleanup, 'bridge stop explicitly cleans provider registrations')
T.equal(bridgeStopCleanup.names[1], 'noir_other:rob', 'bridge stop cleans the remaining owner')

state = 'stopped'
caller = 'noir_outposts'
ok, err = BGRZ.AddEntityTarget(42, options)
T.equal(ok, false, 'stopped target rejected')
T.equal(err, 'provider_unavailable', 'stopped target code')

print('target_spec: ok')
