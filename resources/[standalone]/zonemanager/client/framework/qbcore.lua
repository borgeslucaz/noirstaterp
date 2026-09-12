-- QBCore framework adapter (client). Core object acquired lazily (no load-order dependency).
-- awaitCallback is used only when config.callbacks = 'framework'.

local QBCore

return {
    -- QBCore.Functions.TriggerCallback is async; block until its cb fires so await(name, ...) stays
    -- synchronous.
    awaitCallback = function(name, ...)
        QBCore = QBCore or exports['qb-core']:GetCoreObject()
        local done, result = false, nil
        QBCore.Functions.TriggerCallback(name, function(res)
            done, result = true, res
        end, ...)
        while not done do
            Wait(0)
        end
        return result
    end,
}
