local function read(path)
    local file = assert(io.open(path, 'r'), 'missing provider file: ' .. path)
    local content = file:read('*a')
    file:close()
    return content
end

local function contains(content, needle, label)
    assert(content:find(needle, 1, true), label .. ' contract missing: ' .. needle)
end

local inventory = read('../../[ox]/ox_inventory/modules/inventory/server.lua')
for _, name in ipairs({ 'AddItem', 'RemoveItem', 'GetItemCount', 'CanCarryItem' }) do
    contains(inventory, "exports('" .. name .. "'", 'ox_inventory')
end

local target = read('../../[ox]/ox_target/client/api.lua')
for _, name in ipairs({ 'addEntity', 'removeEntity', 'addLocalEntity', 'removeLocalEntity', 'addSphereZone', 'removeZone' }) do
    contains(target, 'function api.' .. name, 'ox_target')
end

local phoneApi = read('../../[standalone]/sky_phone/source/client/custom_apps.lua')
for _, name in ipairs({
    'AddCustomAppFromAdapter', 'UpdateCustomAppFromAdapter',
    'RemoveCustomAppFromAdapter', 'SendCustomAppMessageFromAdapter',
}) do
    contains(phoneApi, name .. ' = ', 'sky_phone custom app')
end

local phoneConfig = read('../../[standalone]/sky_phone/config/config.lua')
contains(phoneConfig, 'bgrz_core = true', 'sky_phone trusted adapter')

local policeClient = read('../../[qbx]/qbx_police/client/main.lua')
contains(policeClient, "RegisterNetEvent('police:client:policeAlert'", 'qbx_police fallback')

local qbxServer = read('../../[qbx]/qbx_core/server/functions.lua')
contains(qbxServer, "exports('GetQBPlayers'", 'qbx_core player enumeration')

print('provider_contract_spec: ok')
