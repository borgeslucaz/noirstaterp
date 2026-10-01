---Ponto de nascimento na estrada, atrás deste jogador e fora da tela, para a perseguição.
---O servidor pede só a quem está sendo perseguido e confere a distância do que voltar.
local ChaseSpawn = {}

---@param minDistance number
---@param maxDistance number
---@return table? point { x, y, z, w }
function ChaseSpawn.find(minDistance, maxDistance)
    local ped = cache.ped
    local origin = GetEntityCoords(ped)
    local entity = cache.vehicle or ped
    local velocity = GetEntityVelocity(entity)
    local forward
    if #(velocity) > 3.0 then
        forward = norm(vector3(velocity.x, velocity.y, 0.0))
    else
        local heading = math.rad(GetEntityHeading(entity))
        forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
    end
    local side = vector3(-forward.y, forward.x, 0.0)

    local span = maxDistance - minDistance
    local distances = { minDistance + span * 0.35, minDistance + span * 0.6, minDistance + span * 0.15, minDistance + span * 0.85 }
    local offsets = { 0.0, 40.0, -40.0, 90.0, -90.0 }

    for _, distance in ipairs(distances) do
        for _, lateral in ipairs(offsets) do
            local probe = origin - forward * distance + side * lateral
            local found, node = GetClosestVehicleNode(probe.x, probe.y, probe.z, 1, 3.0, 0)
            if found then
                local gap = #(vector3(node.x, node.y, 0.0) - vector3(origin.x, origin.y, 0.0))
                if gap >= minDistance and gap <= maxDistance and not IsSphereVisible(node.x, node.y, node.z + 1.0, 4.0) then
                    -- Nasce virado para o alvo, para começar a perseguição já no sentido certo.
                    local heading = GetHeadingFromVector_2d(origin.x - node.x, origin.y - node.y)
                    return { x = node.x, y = node.y, z = node.z + 0.5, w = heading }
                end
            end
        end
    end
    return nil
end

RegisterNetEvent('noir_missions:client:chaseSpawn', function(requestId, minDistance, maxDistance)
    if source ~= 65535 then return end
    local point = ChaseSpawn.find(tonumber(minDistance) or 120.0, tonumber(maxDistance) or 450.0)
    TriggerServerEvent('noir_missions:server:chaseSpawn', requestId, point)
end)

return ChaseSpawn
