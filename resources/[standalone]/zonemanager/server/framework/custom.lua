-- Custom framework adapter. WIRE YOUR FRAMEWORK HERE - the only file to edit.

return {
    isAdmin = function(src)
        -- return MyFramework.IsAdmin(src)
        return false
    end,
    -- OPTIONAL: only needed when config.callbacks = 'framework'. Bridge fetch/save
    -- onto your callback system; call fn(source, ...) and deliver its return.
    -- registerCallback = function(name, fn)
    --     MyFramework.RegisterCallback(name, function(source, cb, ...)
    --         cb(fn(source, ...))
    --     end)
    -- end,
}
