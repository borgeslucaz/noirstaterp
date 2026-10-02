---Marcador no chão da vaga de entrega do veículo. Só desenha por frame com o jogador a menos
---de 80 m da vaga; longe dela, o laço dorme.
local State = require 'client.runtime.state'

local Markers = {}

local running = false
local DRAW_DISTANCE = 80.0

---@return table[]
local function parkSpots()
    local spots = {}
    for _, delivery in ipairs(State.view and State.view.deliveries or {}) do
        if delivery.park then spots[#spots + 1] = delivery end
    end
    return spots
end

function Markers.start()
    if running then return end
    running = true
    CreateThread(function()
        while State.view do
            local spots = parkSpots()
            local origin = GetEntityCoords(cache.ped)
            local near = false
            for _, spot in ipairs(spots) do
                local park = spot.park
                if #(origin - vector3(park.x, park.y, park.z)) < DRAW_DISTANCE then
                    near = true
                    local size = (spot.parkRadius or 4) * 2.0
                    DrawMarker(1, park.x, park.y, park.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        size, size, 0.6, 57, 223, 69, 70, false, false, 2, false, nil, nil, false)
                    DrawMarker(36, park.x, park.y, park.z + 1.4, 0.0, 0.0, 0.0, 0.0, 0.0, (park.w or 0.0),
                        1.2, 1.2, 1.2, 57, 223, 69, 180, false, false, 2, false, nil, nil, false)
                end
            end
            Wait(near and 0 or 1000)
        end
        running = false
    end)
end

return Markers
