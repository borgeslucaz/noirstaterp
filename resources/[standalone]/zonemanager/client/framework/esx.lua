-- ESX framework adapter (client). Shared object acquired lazily (no load-order dependency).
-- awaitCallback is used only when config.callbacks = 'framework'.

local ESX

return {
    -- ESX.TriggerServerCallback is async; block until its cb fires so await(name, ...) stays
    -- synchronous.
    awaitCallback = function(name, ...)
        ESX = ESX or exports.es_extended:getSharedObject()
        local done, result = false, nil
        ESX.TriggerServerCallback(name, function(res)
            done, result = true, res
        end, ...)
        while not done do
            Wait(0)
        end
        return result
    end,
}
