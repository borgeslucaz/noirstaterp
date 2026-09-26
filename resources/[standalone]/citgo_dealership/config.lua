Config = {}

Config.UseOxTarget = true   -- noir: nao temos core_focus
Config.UseOxRadial = false

Config.DefaultGarage = 'pillboxgarage'

Config.SecondaryColorPrice = 2000

Config.PreviewPoint = vec4(1219.25, -2280.94, -49.0, 180.67)

-- ── Finance Settings ────────────────────────────────────────────────────────

Config.Finance = {
    enabled           = false,         -- noir: financiamento exige tgg-banking, que nao usamos
    loanDuration      = 30,            -- days
    paymentFrequency  = 'daily',       -- 'daily', 'weekly'
    autoPayment       = true,          -- auto-deduct from bank
    maxMissedPayments = 4,             -- repo after this many missed
    repoCheckInterval = 60,            -- seconds between repo checks

    -- Credit score tiers: determines max vehicle price and interest rate
    -- Higher credit = cheaper loans and access to expensive vehicles
    tiers = {
        { minScore = 800, maxPrice = math.huge, rate = 3.5,  label = 'Excellent' },
        { minScore = 700, maxPrice = math.huge, rate = 7.0,  label = 'Good' },
        { minScore = 600, maxPrice = 250000,    rate = 12.0, label = 'Fair' },
        { minScore = 500, maxPrice = 100000,    rate = 18.0, label = 'Poor' },
        { minScore = 300, maxPrice = 50000,     rate = 24.0, label = 'Bad' },
        { minScore = 0,   maxPrice = 25000,     rate = 30.0, label = 'Very Bad' },
    },
}

-- ── Dealerships ─────────────────────────────────────────────────────────────

Config.Dealerships = {
    pdm = {
        label        = 'Premium Deluxe Motorsport',
        shopKey      = 'pdm',
        blip         = { sprite = 326, color = 3, scale = 0.7, label = 'Car Dealer' },
        location     = vec4(-30.85, -1087.37, 26.65, 164.48),
        spawnPoint   = vec4(-51.66, -1095.82, 26.48, 154.87),
        npc          = { model = 's_m_m_autoshop_01', heading = 164.48 },
        categories   = {
            'compacts', 'sedans', 'suvs', 'coupes', 'sports',
            'sportsclassics', 'super', 'muscle', 'offroad', 'vans',
            'motorcycles', 'openwheel',
        },
    },
    luxury = {
        label        = 'Luxury Autos',
        shopKey      = 'luxury',
        blip         = { sprite = 326, color = 5, scale = 0.7, label = 'Luxury Autos' },
        location     = vec4(-1260.17, -356.47, 36.91, 204.0),
        spawnPoint   = vec4(-1246.15, -348.34, 36.91, 204.0),
        npc          = { model = 's_m_m_autoshop_01', heading = 204.0 },
        categories   = {
            'super', 'sports', 'sportsclassics', 'coupes', 'sedans',
        },
    },
}
