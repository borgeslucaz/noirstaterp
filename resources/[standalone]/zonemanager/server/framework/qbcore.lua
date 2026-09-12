-- QBCore framework adapter. Admin via Functions.HasPermission.
-- Core object acquired lazily to avoid a load-order dependency.

local QBCore

return {
    isAdmin = function(src)
        QBCore = QBCore or exports['qb-core']:GetCoreObject()
        return QBCore.Functions.HasPermission(src, 'admin')
            or QBCore.Functions.HasPermission(src, 'god')
    end,
    -- Bridge fetch/save onto QBCore's native server callback; QBCore delivers fn's return via cb.
    registerCallback = function(name, fn)
        QBCore = QBCore or exports['qb-core']:GetCoreObject()
        QBCore.Functions.CreateCallback(name, function(source, cb, ...)
            cb(fn(source, ...))
        end)
    end,
}
