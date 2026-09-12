-- Custom framework adapter (client). Wire your framework here if config.callbacks = 'framework'
-- AND it has client-side callbacks. The server gate lives in server/framework/custom.lua; this
-- is only the client callback transport.

return {
    -- OPTIONAL (only for config.callbacks = 'framework'). Bridge the editor's round-trips onto your
    -- framework's client callbacks: call (name, ...), block until the value lands, return it. Leave
    -- absent to use the built-in 'internal' shim.
    -- awaitCallback = function(name, ...)
    --     local done, result = false, nil
    --     MyFramework.TriggerServerCallback(name, function(res)
    --         done, result = true, res
    --     end, ...)
    --     while not done do
    --         Wait(0)
    --     end
    --     return result
    -- end,
}
