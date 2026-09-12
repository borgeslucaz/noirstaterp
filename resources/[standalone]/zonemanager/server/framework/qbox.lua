-- Qbox framework adapter. Ace-native: admins live in the group.admin ace group,
-- so isAdmin needs no framework handle. Callbacks route through bundled ox_lib.

return {
    isAdmin = function(src)
        return IsPlayerAceAllowed(src, 'group.admin')
    end,
    -- Bridge fetch/save onto ox_lib's server callback (ox_lib uses a return, not a cb argument).
    registerCallback = function(name, fn)
        -- lib is the ox_lib global Qbox bundles; not a LuaLS-known symbol here.
        ---@diagnostic disable-next-line: undefined-global
        lib.callback.register(name, function(source, ...)
            return fn(source, ...)
        end)
    end,
}
