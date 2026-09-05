return {
    framework = "qb", -- Qbox exposes the QB compatibility events used by this HUD.
    speedUnit = "kph", -- Display unit: "kph" (km/h, default) or "mph". Converted once in Lua.

    -- Update rates balance responsiveness and client/NUI CPU usage.
    playerUpdateInterval = 500,
    vehicleUpdateInterval = 125,
    vehicleSlowUpdateInterval = 500,

    useBuiltInSeatbeltLogic = false, -- qbx_seatbelt already owns the seatbelt logic.
    ejectMinSpeed = 20.0, -- Using built-in seatbelt logic: Minimum speed to eject when not wearing a seatbelt (in speedUnit).

    minimapAlways = false, -- Always show minimap (true) or only in vehicles (false).
    compassAlways = false, -- Always show compass (true) or only in vehicles (false).
    compassLocation = "hidden", -- Compass position: "top", "bottom", "hidden".

    useSkewedStyle = true, -- Enable skewed style for HUD (true/false).
    skewAmount = 10, -- Amount of skew to apply (recommended 10-20).
}
