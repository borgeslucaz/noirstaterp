local Shops = require 'client.modules.shops'

local function startShopCreation()
    local allowed = lib.callback.await('mechanic:server:canCreateShop', false)

    if not allowed then
        lib.notify({
            title = locale('no_permission'),
            type = 'error'
        })
        return
    end

    Shops.StartCreation()
end

RegisterCommand('createshop', startShopCreation, false)
RegisterCommand('advcreateshop', startShopCreation, false)
