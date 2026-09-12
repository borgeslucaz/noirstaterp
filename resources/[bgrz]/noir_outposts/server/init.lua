-- Bootstrap: migrations, carga de estado, rotação, entidades, scheduler e cleanup.
NoirOutposts = NoirOutposts or {}

local config = require 'config.server'
local shared = require 'config.shared'
local Log = NoirOutposts.Log
local Db = NoirOutposts.Db
local State = NoirOutposts.State
local Sessions = NoirOutposts.Sessions
local Security = NoirOutposts.Security
local Entities = NoirOutposts.Entities
local Integration = NoirOutposts.Integration
local Repositories = NoirOutposts.Repositories
local Services = NoirOutposts.Services
local Scheduler = NoirOutposts.Scheduler

NoirOutposts.Ready = false

local REQUIRED_TABLES = {
    'noir_outposts',
    'noir_outpost_dealers',
    'noir_outpost_stock',
    'noir_outpost_operations',
    'noir_outpost_rotations',
    'noir_outpost_organizations',
}

---Aplica migrations aceitando somente DDL não destrutivo.
---@return boolean ok
local function runMigrations()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_initial.sql')
    if not sql or sql == '' then
        Log.error('migration_missing', { file = 'migrations/001_initial.sql' })
        return false
    end

    local executed = 0
    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = rawStatement:gsub('^%s*(.-)%s*$', '%1')
        statement = statement:gsub('%-%-[^\n]*', ''):gsub('^%s*(.-)%s*$', '%1')
        if statement ~= '' then
            local upper = statement:upper()
            local allowed = upper:match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') ~= nil
                or upper:match('^INSERT%s+IGNORE%s+INTO%s+') ~= nil
            if not allowed then
                Log.error('migration_rejected', { statement = statement:sub(1, 80) })
                return false
            end
            if Db.execute(statement) == nil then
                Log.error('migration_failed', { statement = statement:sub(1, 80) })
                return false
            end
            executed = executed + 1
        end
    end

    if executed == 0 then
        Log.error('migration_empty', {})
        return false
    end

    Db.insert('INSERT IGNORE INTO noir_outpost_migrations (name, applied_at) VALUES (?, ?)',
        { '001_initial', os.time() })
    Log.info('migration_checked', { statements = executed })
    return true
end

---@return boolean ok
local function verifySchema()
    for index = 1, #REQUIRED_TABLES do
        local row = Db.single('SELECT 1 AS present FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
            { REQUIRED_TABLES[index] })
        if not row then
            Log.error('schema_missing_table', { table = REQUIRED_TABLES[index] })
            return false
        end
    end
    return true
end

---@return boolean ok
local function validateConfiguration()
    for id, definition in pairs(shared.outposts) do
        if type(definition.dealerCorners) ~= 'table'
            or #definition.dealerCorners < config.limits.maxDealersPerOutpost then
            Log.error('config_invalid_corners', { outpostId = id })
            return false
        end
        if not definition.computer or not definition.entrance then
            Log.error('config_invalid_coords', { outpostId = id })
            return false
        end
    end

    for index = 1, #shared.dealerProfiles do
        local profile = shared.dealerProfiles[index]
        if config.dealerHirePrice[profile.key] == nil then
            Log.error('config_missing_hire_price', { profileKey = profile.key })
            return false
        end
    end

    for index = 1, #shared.products do
        local product = shared.products[index]
        local rule = config.products[product.id]
        if rule and (rule.quantity.min < 1 or rule.quantity.max < rule.quantity.min) then
            Log.error('config_invalid_quantity', { product = product.id })
            return false
        end
    end

    if #State.productIds == 0 then
        Log.error('config_no_products', {})
        return false
    end

    return true
end

local function bootstrap()
    if not validateConfiguration() then
        Log.error('startup_aborted', { reason = 'invalid_configuration' })
        return
    end
    if not runMigrations() or not verifySchema() then
        Log.error('startup_aborted', { reason = 'schema_unavailable' })
        return
    end

    local ids = {}
    for id in pairs(shared.outposts) do ids[#ids + 1] = id end
    table.sort(ids)
    Repositories.Outpost.ensureRows(ids)
    Repositories.Outpost.resetStaleClaims()

    State.load()
    Integration.rebuildMembers()

    local rotation = Services.Rotation.apply()
    if not rotation then
        Log.error('startup_aborted', { reason = 'rotation_failed' })
        return
    end

    Entities.syncAll()
    Scheduler.start()
    NoirOutposts.Ready = true

    Services.Notification.broadcastPublicSnapshot()
    Log.info('started', {
        outposts = #ids,
        cycle = rotation.cycleKey,
        products = #State.productIds,
    })
end

CreateThread(function()
    local attempts = 0
    while GetResourceState('bgrz_core') ~= 'started' and attempts < 100 do
        attempts = attempts + 1
        Wait(100)
    end
    if GetResourceState('bgrz_core') ~= 'started' then
        Log.error('startup_aborted', { reason = 'bgrz_core_unavailable' })
        return
    end
    MySQL.ready(bootstrap)
end)

-- Lifecycle --------------------------------------------------------------------------

AddEventHandler('bgrz_core:server:playerLoaded', function(playerSource)
    if not NoirOutposts.Ready or type(playerSource) ~= 'number' then return end
    Services.Notification.sendPublicSnapshot(playerSource)
end)

AddEventHandler('bgrz_core:server:playerUnloaded', function(playerSource)
    if type(playerSource) ~= 'number' then return end
    Sessions.abortForSource(playerSource, 'player_unloaded')
    Sessions.closePanel(playerSource, 'player_unloaded')
end)

AddEventHandler('playerDropped', function()
    local src = source
    Sessions.abortForSource(src, 'player_dropped')
    Sessions.closePanel(src, 'player_dropped')
end)

-- Trocar de organização/grade invalida sessões e painéis em andamento.
AddEventHandler('noir_outposts:server:organizationChanged', function(playerSource)
    Sessions.abortForSource(playerSource, 'organization_changed')
    Sessions.closePanel(playerSource, 'organization_changed')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Scheduler.stop()
    Sessions.abortAll('resource_stop')
    Entities.despawnAll()
    Services.Notification.clear()
    Services.Sale.clear()
    NoirOutposts.Ready = false
end)

-- bgrz_core parando invalida os adapters: encerra sessões com segurança.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= 'bgrz_core' then return end
    Log.warn('bridge_stopped', {})
    Sessions.abortAll('provider_unavailable')
end)

-- Administração ------------------------------------------------------------------------

RegisterCommand('outposts', function(source, args)
    if source ~= 0 and not Security.isAdmin(source) then return end
    local function reply(message)
        if source == 0 then print(message) else Integration.notify(source, message, 'inform') end
    end

    local action = args[1]
    if action == 'status' then
        for _, entry in pairs(State.outposts) do
            reply(('%s | %s | dono=%s | dealers=%d | estoque=%d | carteira=%d'):format(
                entry.row.id, entry.row.status, entry.row.owner_organization_id or '-',
                State.dealerCount(entry.row.id), State.stockTotal(entry.row.id), entry.row.purse_available))
        end
        return
    end

    if action == 'release' then
        local outpostId = Security.outpostId(args[2])
        if not outpostId then return reply('Outpost inválido.') end
        Services.Rotation.releaseExpired(outpostId)
        Services.Notification.broadcastPublicSnapshot()
        Log.info('admin_release', { outpostId = outpostId, source = source })
        return reply(('Controle de %s liberado.'):format(outpostId))
    end

    if action == 'rotate' then
        Services.Rotation.rotateCorners(Security.outpostId(args[2]) or '')
        return reply('Corners rotacionados.')
    end

    reply('Uso: /outposts status | release <id> | rotate <id>')
end, false)
