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

function NoirBurnerIntegration.sendLocation(source, contract)
    return NoirBurnerIntegration.sendMessage(source, 'Tenho um endereço. Vá com calma e não chame atenção.', {
        x = contract.coords.x,
        y = contract.coords.y,
        z = contract.coords.z,
        label = 'Trabalho',
    })
end
