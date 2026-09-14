-- Cayo Perico Island: 4840.571, -5174.425, 2.0
exports('GetCayoPericoIsland', function()
    return CayoPericoIsland
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    CayoPericoIsland.Clear()
end)

local scanDelay = 1000
local loadRadius = 2250.0

CayoPericoIsland = {
    coords = vector3(4840.571, -5174.425, 2.0),
    enabled = false,
    loaded = false,

    Enable = function(state)
        CayoPericoIsland.enabled = state

        if not state then
            CayoPericoIsland.Clear()
        end
    end,

    Clear = function()
        if not CayoPericoIsland.loaded then
            return
        end

        SetIslandHopperEnabled('HeistIsland', false)
        SetToggleMinimapHeistIsland(false)
        CayoPericoIsland.loaded = false
    end
}

-- Stream Cayo and its minimap only near the island so Los Santos keeps its map.
CreateThread(function()
    while true do
        if CayoPericoIsland.enabled then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords.xy - CayoPericoIsland.coords.xy)

            if distance < loadRadius then
                if not CayoPericoIsland.loaded then
                    SetIslandHopperEnabled('HeistIsland', true)
                    SetToggleMinimapHeistIsland(true)
                    CayoPericoIsland.loaded = true
                end
            else
                CayoPericoIsland.Clear()
            end
        end

        Wait(scanDelay)
    end
end)
