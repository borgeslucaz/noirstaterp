-- ─────────────────────────────────────────────
--  RD-Taxi  –  English locale  (en.lua)
--  Duplicate this file and translate to add
--  a new language.  Then set Config.Locale
--  in config.lua to the new filename (no .lua).
-- ─────────────────────────────────────────────

Locale = {
    -- Help text shown at taxi stops
    HELP_PRESS_TO_OPEN   = "Press ~INPUT_CONTEXT~ to view available taxis",
    HELP_ON_COOLDOWN     = "~r~You are on cooldown. Time remaining: %ss",

    -- Calling / reserving
    TAXI_RESERVED        = "Taxi reserved! Wait at the taxi stop for your taxi to arrive.",
    TAXI_EN_ROUTE        = "Your taxi is on the way!",

    -- Arrival notifications
    TAXI_READY_NEARBY    = "Your taxi is ready! Stand near the back door and press ~g~G~w~ to enter.",
    TAXI_ARRIVED         = "Your taxi has arrived! Stand near the back door and press ~g~G~w~ to enter.",

    -- Inside taxi
    WELCOME_SET_WAYPOINT = "Welcome! Open your map (ESC or M) and set a waypoint to your destination.",
    DESTINATION_CONFIRMED = "Destination confirmed. Enjoy your ride!",
    DESTINATION_CANCELLED = "Destination cancelled. Set a new waypoint when ready.",
    DOORS_LOCKED_FOR_RIDE = "Doors locked for your safety. Relax and enjoy the ride!",

    -- Arrival at destination
    ARRIVED_EXIT_VEHICLE = "You have arrived! Exit the vehicle when ready.",
    EXIT_REMINDER        = "~g~You have arrived at your destination. Exit the vehicle.",
    EXIT_URGENT          = "~r~Please exit the taxi! Time remaining: %ss",

    -- Timeouts / kicks
    WAYPOINT_TIMEOUT     = "You took too long to select a destination!",
    EXIT_TIMEOUT         = "You took too long to exit!",
    KICKED_COOLDOWN      = "You have been removed from the taxi. Cooldown: 10 minutes.",

    -- Payment
    PAYMENT_SUCCESS      = "Paid $%s for the ride.",
    PAYMENT_FAIL         = "Insufficient funds! You need $%s.",
    PAYMENT_FAIL_KICKED  = "Insufficient funds! Kicked from taxi.",

    -- Reserved taxi demand
    DEMAND_TIMEOUT       = "The reserved taxi left before you could enter.",
}

-- Helper – printf-style string formatting using Locale keys
function L(key, ...)
    local str = Locale[key]
    if not str then return "[MISSING: " .. tostring(key) .. "]" end
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
