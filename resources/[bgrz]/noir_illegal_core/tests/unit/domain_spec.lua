-- Run from the resource root with Lua 5.4:
-- lua tests/unit/domain_spec.lua

NoirIllegal = {}
json = { encode = function() return '{}' end, decode = function() return {} end }

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('shared/levels.lua')
dofile('shared/unlocks.lua')
dofile('shared/activities.lua')
dofile('shared/permissions.lua')
dofile('server/validators.lua')
dofile('server/services/level_service.lua')
dofile('server/services/heat_service.lua')
dofile('server/services/eligibility_service.lua')

local function equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(
        label, tostring(expected), tostring(actual)))
end

equal(NoirIllegal.Services.Level.get('drug', 0), 0, 'level zero')
equal(NoirIllegal.Services.Level.get('drug', 99.9999), 0, 'level below threshold')
equal(NoirIllegal.Services.Level.get('drug', 100), 1, 'level threshold')
equal(NoirIllegal.Services.Level.get('drug', 300), 2, 'second threshold')

equal(NoirIllegal.Services.Level.diminishingMultiplier(19, {
    softCap = 20, floorMultiplier = 0.2,
}), 1.0, 'diminishing before cap')
equal(NoirIllegal.Services.Level.diminishingMultiplier(20, {
    softCap = 20, floorMultiplier = 0.2,
}), 0.95, 'diminishing at cap')
equal(NoirIllegal.Services.Level.diminishingMultiplier(100, {
    softCap = 20, floorMultiplier = 0.2,
}), 0.2, 'diminishing floor')

NoirIllegal.Config.Heat.decayPerSecond = 0.5
local heat = NoirIllegal.Services.Heat.calculate(10, 100, 110)
equal(heat, 5, 'partial heat decay')
heat = NoirIllegal.Services.Heat.calculate(2, 100, 110)
equal(heat, 0, 'heat decay floor')
heat = NoirIllegal.Services.Heat.calculate(10, 110, 100)
equal(heat, 10, 'clock skew')

local eligible = NoirIllegal.Services.Eligibility.unlockRequirements({
    requirements = { reputation = { drug = 100 }, maxHeat = 25 },
}, {
    reputations = { drug = 100 },
    levels = { drug = 1 },
    heat = 25,
    organization = nil,
    unlocks = {},
})
equal(eligible, true, 'unlock boundary eligibility')

assert(NoirIllegal.Validators.uuid('575c1c60-03ad-4a64-9849-0b7fe8d43d4f'))
assert(not NoirIllegal.Validators.uuid('not-a-uuid'))

print('domain_spec: ok')
