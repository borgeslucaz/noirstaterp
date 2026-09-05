-- Routing bucket isolation is server-authoritative, so it can't live in
-- client/main.lua. Each player gets their own bucket while "inside" so two
-- players entering at the same time don't see each other.
local DEFAULT_BUCKET = 0
local BUCKET_OFFSET = 100000

RegisterNetEvent('noir_shell_test:enter', function()
    local src = source

    SetPlayerRoutingBucket(src, BUCKET_OFFSET + src)
end)

RegisterNetEvent('noir_shell_test:exit', function()
    local src = source

    SetPlayerRoutingBucket(src, DEFAULT_BUCKET)
end)

AddEventHandler('playerDropped', function()
    SetPlayerRoutingBucket(source, DEFAULT_BUCKET)
end)
