-- A gang vem do bridge, não de `QBX.PlayerData`.
--
-- Ler o PlayerData direto já contrariava o §2.1, e agora estaria simplesmente errado: o
-- Qbox deixou de ser dono de gang. O bridge resolve pelo provider configurado.
local function hasGangSet()
    if GetResourceState('bgrz_core') ~= 'started' then return false end
    local ok, gang = pcall(function() return exports.bgrz_core:GetGang() end)
    return ok
        and type(gang) == 'table'
        and type(gang.name) == 'string'
        and gang.name ~= ''
        and gang.name ~= 'none'
end

local function areaLabel(areaName)
    local label = tostring(areaName):gsub('_', ' ')
    return label:gsub('(%a)([%w]*)', function(first, rest)
        return first:upper() .. rest
    end)
end

AddEventHandler('zonemanager:enter', function(areaName)
    if not hasGangSet() then return end

    lib.notify({
        title = 'Território',
        description = ('Você entrou na área dos %s'):format(areaLabel(areaName)),
        type = 'inform',
        icon = 'map-location-dot',
        duration = 5000,
    })
end)

-- Pede um novo snapshot ao iniciar este resource. Isso recria as zonas já carregadas
-- e também detecta corretamente quem estiver dentro de uma área nesse momento.
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(250)
        if GetResourceState('zonemanager') == 'started' then
            TriggerServerEvent('zonemanager:clientReady')
        end
    end)
end)
