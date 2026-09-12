-- Qbox framework adapter (client). Qbox bundles ox_lib, so callbacks route through its lib.callback
-- API. awaitCallback is used only when config.callbacks = 'framework'.

return {
    -- lib.callback.await is already synchronous, so no manual block. The false second arg disables
    -- the timeout (wait-forever), matching the internal shim.
    awaitCallback = function(name, ...)
        -- lib is the ox_lib global Qbox bundles; not a LuaLS-known symbol here.
        ---@diagnostic disable-next-line: undefined-global
        return lib.callback.await(name, false, ...)
    end,
}
