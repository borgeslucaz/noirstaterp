return {
    stateMetadata = 'noirBurnerPhone',
    maxContacts = 50,
    maxMessages = 100,
    activityRequestCooldown = 2,

    -- This table is server-only and is the authority for which apps may run.
    -- Do not enable an activity until its server validation and client bridge
    -- are both implemented.
    activities = {
        drugSales = false,
        deliveries = false,
        blackMarket = false,
    },

    -- Contract providers are other server resources that expose the four
    -- exports below. The phone never talks to them from JavaScript: every
    -- NUI action passes through this resource, which validates ownership of
    -- the item and rate-limits requests before delegating.
    --
    -- list(source)                -> { active = {...}, available = {...} }
    -- accept(source, offerId)     -> ok, reason
    -- resume(source, contractId)  -> ok, reason
    -- abandon(source, contractId) -> ok, reason
    contracts = {
        enabled = true,
        requestCooldownMs = 750,
        providers = {
            {
                resource = 'noir_houserobbery',
                list = 'GetBurnerContracts',
                accept = 'AcceptBurnerContract',
                resume = 'ResumeBurnerContract',
                abandon = 'AbandonBurnerContract',
            },
        },
    },
}
