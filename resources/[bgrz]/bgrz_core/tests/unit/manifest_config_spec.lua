local function read(path)
    local file = assert(io.open(path, 'r'))
    local content = file:read('*a')
    file:close()
    return content
end

BGRZConfig = nil
dofile('shared/config.lua')
assert(BGRZConfig.Version == '0.5.0', 'config version must be 0.5.0')
assert(BGRZConfig.Providers.inventory == 'ox_inventory', 'inventory provider missing')
assert(BGRZConfig.Providers.target == 'ox_target', 'target provider missing')
assert(BGRZConfig.Providers.phone == 'sd-phone', 'phone provider missing')
assert(BGRZConfig.Providers.dispatch == 'sd-phone', 'dispatch provider missing')
assert(BGRZConfig.Providers.dispatchFallback == 'qbx_police', 'dispatch fallback missing')
assert(BGRZConfig.Limits.maxItemAmount == 100000, 'item amount limit missing')

local manifest = read('fxmanifest.lua')
for _, required in ipairs({
    "version '0.5.0'",
    "'shared/provider.lua'",
    "'shared/capabilities.lua'",
    "'client/target.lua'",
    "'client/phone.lua'",
    "'server/inventory.lua'",
    "'server/phone_notifications.lua'",
    "'server/dispatch.lua'",
    "'ox_inventory'",
    "'ox_target'",
}) do
    assert(manifest:find(required, 1, true), 'manifest missing ' .. required)
end

print('manifest_config_spec: ok')
