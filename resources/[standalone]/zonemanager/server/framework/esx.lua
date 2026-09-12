-- ESX framework adapter. Admin via xPlayer.getGroup() == 'admin'.
-- Shared object acquired lazily to avoid a load-order dependency.

local ESX

return {
    isAdmin = function(src)
        ESX = ESX or exports.es_extended:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer ~= nil and xPlayer.getGroup() == 'admin'
    end,
    -- Bridge fetch/save onto ESX's native server callback; ESX delivers fn's return via cb.
    registerCallback = function(name, fn)
        ESX = ESX or exports.es_extended:getSharedObject()
        ESX.RegisterServerCallback(name, function(source, cb, ...)
            cb(fn(source, ...))
        end)
    end,
}
