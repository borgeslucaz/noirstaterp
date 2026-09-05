Config = {}

-- ─────────────────────────────────────────────
--  FRAMEWORK
-- ─────────────────────────────────────────────
Config.Framework = "standalone" -- Options: "qbcore", "esx", "standalone"

-- ─────────────────────────────────────────────
--  PAYMENT
-- ─────────────────────────────────────────────
Config.PaymentEnabled = false             -- Enable payment system (requires qbcore or esx)
Config.TaxiFare      = 250               -- Amount charged per ride
Config.PaymentTiming = "on_arrival"      -- "on_confirm" | "on_arrival"

-- ─────────────────────────────────────────────
--  LOCALE
-- ─────────────────────────────────────────────
Config.Locale = "en"  -- Change to any file in /locales/ (without .lua)

-- ─────────────────────────────────────────────
--  MAP BLIPS – static taxi stop icons
-- ─────────────────────────────────────────────
Config.TaxiBlipSprite = 198
Config.TaxiBlipColor  = 27
Config.TaxiBlipScale  = 0.8

-- ─────────────────────────────────────────────
--  MAP BLIPS – moving taxi tracking icons
-- ─────────────────────────────────────────────
Config.MovingTaxiBlipSprite      = 56
Config.MovingTaxiBlipColor       = 5
Config.MovingTaxiBlipScale       = 0.9
Config.ShowBlipWhenEnRoute       = true   -- Show blip while taxi drives to player
Config.ShowBlipWhenDelivering    = true   -- Show blip during trip
Config.ShowBlipWhenReturning     = false  -- Show blip when returning to spawn

-- ─────────────────────────────────────────────
--  DRIVING BEHAVIOUR
-- ─────────────────────────────────────────────
Config.RespectTrafficLights = false  -- true = obey lights, false = ignore them

-- ─────────────────────────────────────────────
--  TIMERS  (all in seconds)
-- ─────────────────────────────────────────────
Config.WaypointTimeout  = 180   -- Time player has to set a waypoint after entering
Config.CooldownAfterKick = 600  -- Cooldown after being removed for bad behaviour
Config.ExitTimeout      = 240   -- Time to exit the taxi after arrival
Config.ReservedTimeout  = 150   -- Time reserved taxi waits at stop for player
Config.UpdateInterval   = 1000  -- Status broadcast interval in ms

-- ─────────────────────────────────────────────
--  TAXI STOPS
-- ─────────────────────────────────────────────
Config.TaxiStops = {
    {
        name        = "taxi_stop_1",
        label       = "Downtown Taxi Stop",
        coords      = vector3(257.14, -1118.76, 29.33),
        size        = vector2(2, 5),
        heading     = 0,
        spawnCoords = vector4(257.34, -1123.95, 29.21, 82.90)
    },
    {
        name        = "taxi_stop_2",
        label       = "Legion Square Taxi Stop",
        coords      = vector3(304.17, -765.07, 29.31),
        size        = vector2(5, 2),
        heading     = 340,
        spawnCoords = vector4(307.50, -766.10, 29.25, 161.98)
    },
    {
        name        = "taxi_stop_3",
        label       = "Pillbox Hill Taxi Stop",
        coords      = vector3(-250.17, -887.1, 30.62),
        size        = vector2(2, 5),
        heading     = 340,
        spawnCoords = vector4(-247.94, -881.84, 30.62, 69.55)
    },
    {
        name        = "taxi_stop_4",
        label       = "Little Seoul Taxi Stop",
        coords      = vector3(-558.13, -848.97, 27.58),
        size        = vector2(2, 5),
        heading     = 0,
        spawnCoords = vector4(-565.0, -850.0, 27.5, 0.0)
    }
}

-- ─────────────────────────────────────────────
--  TAXI DRIVERS
-- ─────────────────────────────────────────────
Config.TaxiDrivers = {
    {
        id           = 1,
        name         = "Michael Rodriguez",
        pedModel     = "a_m_m_tourist_01",
        driverImage  = "driver1.png",
        vehicleModel = "taxi",
        vehicleImage = "taxi.png",
        voiceFile    = "none",          -- mp3 filename inside html/sounds/ or "none"
        color        = {r = 255, g = 215, b = 0},
        assignedStop = "taxi_stop_1"
    },
    {
        id           = 2,
        name         = "David Chen",
        pedModel     = "a_m_y_business_01",
        driverImage  = "driver2.png",
        vehicleModel = "taxi",
        vehicleImage = "taxi.png",
        voiceFile    = "none",
        color        = {r = 255, g = 204, b = 0},
        assignedStop = "taxi_stop_2"
    },
    {
        id           = 3,
        name         = "James Thompson",
        pedModel     = "a_m_m_business_01",
        driverImage  = "driver3.png",
        vehicleModel = "taxi",
        vehicleImage = "taxi.png",
        voiceFile    = "none",
        color        = {r = 255, g = 183, b = 0},
        assignedStop = "taxi_stop_3"
    }
}

-- ─────────────────────────────────────────────
--  STATUS CONSTANTS  (do not change)
-- ─────────────────────────────────────────────
Config.Status = {
    AVAILABLE    = "available",
    EN_ROUTE     = "en_route",
    DELIVERING   = "delivering",
    JUST_FINISHED = "just_finished",
    RETURNING    = "returning"
}
