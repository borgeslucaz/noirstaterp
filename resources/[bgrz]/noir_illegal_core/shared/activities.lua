-- Examples stay disabled until the owning gameplay resource is installed,
-- configured in permissions.lua, and explicitly enabled here.
NoirIllegal.Activities = {
    drug_sale = {
        enabled = true,
        callers = { 'noir_illegal_core' },
        cooldownSeconds = 0,
        idempotencyTtlSeconds = 2592000,
        personal = { drug = 2, street = 1 },
        organization = { drug = 1 },
        heat = 0.35,
        diminishingReturns = {
            windowSeconds = 3600,
            softCap = 20,
            floorMultiplier = 0.20,
            curve = 'linear',
            key = 'player:activity',
        },
        requirements = {},
        metadata = { allow = { 'zoneId', 'saleType', 'targetId' } },
    },
}
