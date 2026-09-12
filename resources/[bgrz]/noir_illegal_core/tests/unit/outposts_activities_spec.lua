NoirIllegal = { Services = { Level = { validateConfiguration = function() end } } }

dofile('shared/constants.lua')
dofile('shared/config.lua')
dofile('shared/activities.lua')
dofile('shared/permissions.lua')
dofile('server/validators.lua')
dofile('server/services/activity_service.lua')

local function equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(
        label, tostring(expected), tostring(actual)))
end

local function allowlist(activityKey, expected)
    local actual = NoirIllegal.Activities[activityKey].metadata.allow
    equal(#actual, #expected, activityKey .. ' metadata count')
    for index = 1, #expected do
        equal(actual[index], expected[index], activityKey .. ' metadata #' .. index)
    end
end

equal(NoirIllegal.Permissions.publicRecorders.noir_outposts, true, 'outposts public recorder')

local claim = assert(NoirIllegal.Activities.outpost_claim, 'outpost_claim missing')
equal(claim.enabled, true, 'claim enabled')
equal(claim.callers[1], 'noir_outposts', 'claim caller')
equal(claim.cooldownSeconds, 0, 'claim cooldown')
equal(claim.personal.street, 2, 'claim personal street')
equal(claim.organization.street, 5, 'claim organization street')
equal(claim.heat, 2.0, 'claim heat')
equal(claim.requirements.organization, true, 'claim organization requirement')
allowlist('outpost_claim', { 'outpostId', 'previousOwnerId' })

local sale = assert(NoirIllegal.Activities.outpost_sale, 'outpost_sale missing')
equal(sale.enabled, true, 'sale enabled')
equal(sale.callers[1], 'noir_outposts', 'sale caller')
equal(sale.cooldownSeconds, 0, 'sale cooldown')
equal(sale.personal.drug, 0, 'sale personal drug')
equal(sale.organization.drug, 1, 'sale organization drug')
equal(sale.heat, 0, 'sale does not assign passive heat to an arbitrary online member')
equal(sale.requirements.organization, true, 'sale organization requirement')
equal(sale.diminishingReturns.key, 'organization:activity', 'sale diminishing key')
equal(sale.diminishingReturns.windowSeconds, 3600, 'sale diminishing window')
equal(sale.diminishingReturns.softCap, 30, 'sale soft cap')
equal(sale.diminishingReturns.floorMultiplier, 0.20, 'sale floor')
equal(sale.diminishingReturns.curve, 'linear', 'sale curve')
allowlist('outpost_sale', { 'outpostId', 'dealerId', 'product', 'quantity' })

local robbery = assert(NoirIllegal.Activities.outpost_robbery, 'outpost_robbery missing')
equal(robbery.enabled, true, 'robbery enabled')
equal(robbery.callers[1], 'noir_outposts', 'robbery caller')
equal(robbery.cooldownSeconds, 900, 'robbery cooldown')
equal(robbery.personal.street, 2, 'robbery personal street')
equal(next(robbery.organization), nil, 'robbery organization empty')
equal(robbery.heat, 4.0, 'robbery heat')
allowlist('outpost_robbery', { 'outpostId', 'dealerId', 'lootValue' })

NoirIllegal.Services.Activity.validateConfiguration()
print('outposts_activities_spec: ok')
