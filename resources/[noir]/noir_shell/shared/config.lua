Config = {}

Config.Debug = false

Config.ModelLoadTimeout = 5000

Config.CollisionTimeout = 5000

Config.DefaultOrigin = vec4(0.0, 0.0, 0.0, 0.0)

-- Optional named shell definitions, consumed via exports.noir_shell:CreateFromDefinition(name, overrides)
Config.Shells = {
    -- lev_apartment = {
    --     model = `lev_apartment_shell`,
    --     origin = vec4(1000.0, 1000.0, -100.0, 0.0),
    --     entranceOffset = vec4(1.25, -3.11, 0.10, 180.0),
    -- },
}
