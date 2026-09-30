---Guia de Cultivo: usar o item no inventário abre o livro na NUI. O servidor manda os
---números (config), a NUI monta as páginas.

local Actions = require 'client.actions'

local open = false

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'manual:close' })
end

exports('useManual', function()
    if open or Actions.isBusy() then return end
    local response = lib.callback.await('noir_weed:server:manual', false)
    if not response or not response.ok then return Actions.fail(response and response.code) end
    open = true
    SendNUIMessage({ action = 'manual:open', data = response.manual })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('manualClose', function(_, cb)
    close()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and open then SetNuiFocus(false, false) end
end)
