NoirIllegal.Ready = false

math.randomseed(os.time() + GetGameTimer())

local requiredTables = {
    'noir_illegal_schema_migrations',
    'noir_illegal_profiles',
    'noir_illegal_player_reputation',
    'noir_illegal_organization_reputation',
    'noir_illegal_player_heat',
    'noir_illegal_unlocks',
    'noir_illegal_cooldowns',
    'noir_illegal_activity_ledger',
    'noir_illegal_audit_log',
}

local function checkSchema()
    for i = 1, #requiredTables do
        local exists = MySQL.scalar.await([[
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1
        ]], { requiredTables[i] })
        if not exists then
            error(('Missing database table %s. Import migrations/001_initial.sql first.'):format(
                requiredTables[i]))
        end
    end
    local migration = MySQL.scalar.await(
        'SELECT 1 FROM noir_illegal_schema_migrations WHERE version = ? LIMIT 1',
        { '001_initial' })
    if not migration then error('Migration 001_initial is not recorded.') end
end

MySQL.ready(function()
    local ok, startupError = pcall(function()
        NoirIllegal.Services.Activity.validateConfiguration()
        NoirIllegal.Migrations.run()
        checkSchema()
    end)
    if not ok then
        NoirIllegal.Logger.error('startup_failed', { error = tostring(startupError) })
        StopResource(GetCurrentResourceName())
        return
    end
    NoirIllegal.Ready = true
    NoirIllegal.Logger.info('ready', { version = NoirIllegal.Config.Version })
end)
