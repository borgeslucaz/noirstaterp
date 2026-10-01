-- Run from the resource root with Lua 5.4:
-- lua tests/unit/crime_heat_spec.lua
-- Crimes que só somam heat: a config valida, cada evento vira a activity certa e o heat não
-- passa pelo retorno decrescente.

NoirIllegal = { Services = {
    Level = { validateConfiguration = function() end },
    Unlock = { validateConfiguration = function() end },
} }

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('shared/activities.lua')
dofile('shared/permissions.lua')
dofile('server/validators.lua')
dofile('server/services/activity_service.lua')

local function equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
end

NoirIllegal.Services.Activity.validateConfiguration()

local expected = {
    house_robbery = 8, petty_smashgrab = 2, petty_parkingmeter = 1, store_register = 4, store_safe = 6,
    jewelery_vitrine = 2, bank_fleeca = 12, bank_paleto = 16, bank_pacific = 20, truck_robbery = 12,
    vehicle_break_in = 2, gun_craft = 3,
}
for key, heat in pairs(expected) do
    local activity = assert(NoirIllegal.Activities[key], key .. ' missing')
    equal(activity.enabled, true, key .. ' enabled')
    equal(activity.heat, heat, key .. ' heat')
    local street = ({ house_robbery = 3, petty_smashgrab = 0.5, petty_parkingmeter = 0.25 })[key]
    equal(activity.personal.street, street, key .. ' personal street')
    equal(next(activity.organization or {}), nil, key .. ' gives no gang reputation')
    equal(activity.diminishingReturns, nil, key .. ' has no diminishing returns')
    equal(activity.callers[1], 'noir_illegal_core', key .. ' recorded by the core adapter')
end

-- Adaptador: cada evento vira a activity certa, e só do resource dono.
local handlers, recorded, invoking = {}, {}, nil
function AddEventHandler(name, fn) handlers[name] = fn end
function GetInvokingResource() return invoking end
NoirIllegal.Adapters = {}
dofile('server/adapters/adapters.lua')
NoirIllegal.Adapters.record = function(source, key, id, options)
    recorded[#recorded + 1] = { source = source, key = key, id = id, options = options }
end
dofile('server/adapters/crimes.lua')

local function fire(resource, event, ...)
    invoking = resource
    recorded = {}
    handlers[event](...)
    return recorded
end

local r = fire('noir_houserobbery', 'noir_houserobbery:server:robberyCompleted', { id = 'hr:1:2:3', houseId = 'h1', tier = 2, sources = { 4, 5 } })
equal(#r, 2, 'house robbery heats every participant')
equal(r[1].key, 'house_robbery', 'house robbery activity')
assert(r[1].id ~= r[2].id, 'one transaction per participant')
equal(#fire('noir_houserobbery', 'noir_houserobbery:server:robberyCompleted', { id = 'hr:1:2:3', houseId = 'h1', tier = 2, sources = { 4 } }), 1, 'replay keeps the same id')

equal(#fire('outro_resource', 'noir_houserobbery:server:robberyCompleted', { id = 'x', sources = { 4 } }), 0, 'forged announcer ignored')

equal(fire('noir_prettycrimes', 'noir_prettycrimes:server:crimeCompleted', 3, 'petty_smashgrab', 't1', {})[1].key, 'petty_smashgrab', 'smashgrab')
equal(#fire('noir_prettycrimes', 'noir_prettycrimes:server:crimeCompleted', 3, 'drug_sale', 't1', {}), 0, 'prettycrimes cannot pick another activity')

equal(fire('qbx_storerobbery', 'qbx_storerobbery:server:registerRobbed', 3, 1)[1].key, 'store_register', 'register')
equal(fire('qbx_storerobbery', 'qbx_storerobbery:server:safeRobbed', 3, 1)[1].key, 'store_safe', 'safe')
equal(fire('qbx_jewelery', 'qbx_jewelery:server:vitrineRobbed', 3, 2)[1].key, 'jewelery_vitrine', 'vitrine')
equal(fire('qbx_bankrobbery', 'qbx_bankrobbery:server:bankOpened', 3, 4)[1].key, 'bank_fleeca', 'fleeca')
equal(fire('qbx_bankrobbery', 'qbx_bankrobbery:server:bankOpened', 3, 'paleto')[1].key, 'bank_paleto', 'paleto')
equal(fire('qbx_bankrobbery', 'qbx_bankrobbery:server:bankOpened', 3, 'pacific')[1].key, 'bank_pacific', 'pacific')
equal(#fire('qbx_bankrobbery', 'qbx_bankrobbery:server:bankOpened', 3, 'other'), 0, 'unknown bank')
equal(fire('qbx_truckrobbery', 'qbx_truckrobbery:server:truckLooted', 3)[1].key, 'truck_robbery', 'truck')

local a = fire('mri_Qcarkeys', 'mri_Qcarkeys:server:vehicleBrokenInto', 3, 'hotwire', 77, 'ABC 123')[1]
local b = fire('mri_Qcarkeys', 'mri_Qcarkeys:server:vehicleBrokenInto', 3, 'hotwire', 77, 'ABC 123')[1]
equal(a.key, 'vehicle_break_in', 'break-in')
equal(a.id, b.id, 'same car same day counts once')
equal(#fire('mri_Qcarkeys', 'mri_Qcarkeys:server:vehicleBrokenInto', 3, 'teleport', 77, 'X'), 0, 'unknown kind')

local g1 = fire('noir_guncraft', 'noir_guncraft:server:craftCollected', 3, 10, 'weapon_pistol')[1]
local g2 = fire('noir_guncraft', 'noir_guncraft:server:craftCollected', 3, 11, 'weapon_pistol')[1]
equal(g1.key, 'gun_craft', 'gun craft')
assert(g1.id ~= g2.id, 'one transaction per queue row')

equal(#fire('qbx_storerobbery', 'qbx_storerobbery:server:registerRobbed', 'abc', 1), 0, 'source must be a number')

print('crime_heat_spec: ok')
