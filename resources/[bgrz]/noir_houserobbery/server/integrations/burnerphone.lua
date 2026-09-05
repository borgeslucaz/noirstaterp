NoirBurnerIntegration = {}

local RESOURCE = 'noir_burnerphone'

function NoirBurnerIntegration.sendMessage(source, message, location)
    if GetResourceState(RESOURCE) ~= 'started' then
        exports.qbx_core:Notify(source, message, location and 'success' or 'inform')
        return false
    end

    local ok = pcall(function()
        exports[RESOURCE]:sendContactMessage(source, message, location)
    end)

    if not ok then exports.qbx_core:Notify(source, message, location and 'success' or 'inform') end
    return ok
end

-- Asks the burner phone to push a fresh contract snapshot to the player's NUI
-- (no-op when the phone is closed or the resource is not running).
function NoirBurnerIntegration.refreshContracts(source)
    if GetResourceState(RESOURCE) ~= 'started' then return false end
    return pcall(function()
        exports[RESOURCE]:refreshContracts(source)
    end)
end

function NoirBurnerIntegration.sendLocation(source, contract)
    return NoirBurnerIntegration.sendMessage(source, 'Tenho um endereço. Vá com calma e não chame atenção.', {
        x = contract.coords.x,
        y = contract.coords.y,
        z = contract.coords.z,
        label = 'Trabalho',
    })
end
