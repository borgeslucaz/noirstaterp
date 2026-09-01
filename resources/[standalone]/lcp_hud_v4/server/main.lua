-- ---------------------------------------------------------------------------
--  lcp_hud_v4 server
-- ---------------------------------------------------------------------------
--  Lightweight server-side. The HUD is fully client-side; we only print a
--  banner on resource start and expose a basic version export.
-- ---------------------------------------------------------------------------

local VERSION = '4.0.0'

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(('^3[lcp_hud_v4]^7 v%s loaded.'):format(VERSION))
end)

exports('GetVersion', function() return VERSION end)
