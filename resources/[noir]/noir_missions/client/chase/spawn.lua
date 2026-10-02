---Vagas de nascimento na estrada para a perseguição, atrás de quem está sendo perseguido e
---fora da vista de todo mundo. O servidor pede só ao cliente do alvo (é quem tem o terreno
---carregado em volta) e confere de novo distância e jogadores no que voltar.
---
---Uma vaga só vale se:
---  * é nó de via de carro ligado (nada de calçada, beco desligado, telhado, trilha);
---  * o chão está ali (sonda de chão bate com a altura do nó) e não é água;
---  * não fica muito acima nem abaixo do alvo (viaduto por cima, túnel por baixo);
---  * está na faixa de distância de TODOS os jogadores por perto, não só do alvo;
---  * ninguém está vendo: fora da tela do alvo e sem linha de visão da câmera até lá;
---  * não tem veículo parado em cima.
---Os carros seguintes da onda nascem em fila, cada um num nó mais para trás da mesma via.
local ChaseSpawn = {}

local MAX_HEIGHT_GAP = 18.0
local VEHICLE_CLEARANCE = 6.0
local QUEUE_STEP = 12.0

---@param entity integer
---@return vector3 forward
local function forwardOf(entity)
    local velocity = GetEntityVelocity(entity)
    if #(velocity) > 3.0 then return norm(vector3(velocity.x, velocity.y, 0.0)) end
    local heading = math.rad(GetEntityHeading(entity))
    return vector3(-math.sin(heading), math.cos(heading), 0.0)
end

---Algum jogador consegue ver o ponto? Tela do alvo e linha de visão da câmera.
---@param point vector3
---@return boolean
local function seen(point)
    local probe = point + vector3(0.0, 0.0, 1.2)
    if IsSphereVisible(probe.x, probe.y, probe.z, 3.0) then
        local camera = GetFinalRenderedCamCoord()
        local handle = StartShapeTestLosProbe(camera.x, camera.y, camera.z, probe.x, probe.y, probe.z, 1 | 16, cache.ped, 4)
        local status, hit = GetShapeTestResult(handle)
        local tries = 0
        while status == 1 and tries < 10 do
            Wait(0)
            status, hit = GetShapeTestResult(handle)
            tries = tries + 1
        end
        -- Na tela e sem nada no caminho: visto.
        if hit == 0 then return true end
    end
    return false
end

---@param node vector3
---@param origin vector3
---@param minDistance number
---@param maxDistance number
---@return boolean
local function farFromPlayers(node, minDistance, maxDistance, origin)
    local gap = #(vector3(node.x - origin.x, node.y - origin.y, 0.0))
    if gap < minDistance or gap > maxDistance then return false end
    for _, player in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= 0 and #(GetEntityCoords(ped) - node) < minDistance then return false end
    end
    return true
end

---@param node vector3
---@param origin vector3
---@return boolean
local function solidRoad(node, origin)
    if math.abs(node.z - origin.z) > MAX_HEIGHT_GAP then return false end
    local found, ground = GetGroundZFor_3dCoord(node.x, node.y, node.z + 3.0, false)
    if not found or math.abs(ground - node.z) > 3.0 then return false end
    local water, height = GetWaterHeight(node.x, node.y, node.z)
    if water and height > ground then return false end
    if IsAnyVehicleNearPoint(node.x, node.y, node.z, VEHICLE_CLEARANCE) then return false end
    return true
end

---Nó de via ligado mais perto do ponto, com o sentido da via.
---@param point vector3
---@return vector3? node
---@return number? heading
local function roadNode(point)
    -- nodeType 0 = via principal; 1 = qualquer via seca, para região sem via principal (porto).
    -- Nenhum dos dois inclui calçada, telhado ou água.
    for _, nodeType in ipairs({ 0, 1 }) do
        local found, node, heading = GetClosestVehicleNodeWithHeading(point.x, point.y, point.z, nodeType, 3.0, 0)
        if found and #(vector3(node.x - point.x, node.y - point.y, 0.0)) < 80.0 then return node, heading end
    end
    return nil
end

---Sentido da via que aponta para o alvo, para o carro já sair perseguindo.
---@param node vector3
---@param roadHeading number
---@param origin vector3
---@return number
local function facing(node, roadHeading, origin)
    local toTarget = GetHeadingFromVector_2d(origin.x - node.x, origin.y - node.y)
    local diff = math.abs(((roadHeading - toTarget) + 180.0) % 360.0 - 180.0)
    return diff <= 90.0 and roadHeading or (roadHeading + 180.0) % 360.0
end

---@param minDistance number
---@param maxDistance number
---@param count integer
---@return table[] points { x, y, z, w }
function ChaseSpawn.find(minDistance, maxDistance, count)
    local origin = GetEntityCoords(cache.ped)
    local forward = forwardOf(cache.vehicle or cache.ped)
    local side = vector3(-forward.y, forward.x, 0.0)
    local span = maxDistance - minDistance

    -- Atrás primeiro; depois as laterais (estrada paralela, cruzamento) — nunca à frente.
    local directions = {
        -forward, norm(-forward + side * 0.6), norm(-forward - side * 0.6), side, -side,
    }
    local fractions = { 0.35, 0.6, 0.15, 0.85 }

    for _, direction in ipairs(directions) do
        for _, fraction in ipairs(fractions) do
            local probe = origin + direction * (minDistance + span * fraction)
            local node, heading = roadNode(probe)
            if node and farFromPlayers(node, minDistance, maxDistance, origin)
                and solidRoad(node, origin) and not seen(node) then
                local w = facing(node, heading, origin)
                local points = { { x = node.x, y = node.y, z = node.z + 0.5, w = w } }
                -- Os outros carros em fila, cada um num nó mais longe do alvo na mesma via.
                local back = vector3(math.sin(math.rad(w)), -math.cos(math.rad(w)), 0.0)
                local last = node
                for _ = 2, count do
                    local nextNode = roadNode(last + back * QUEUE_STEP)
                    if not nextNode or #(nextNode - last) < 6.0
                        or not solidRoad(nextNode, origin) or seen(nextNode) then break end
                    points[#points + 1] = { x = nextNode.x, y = nextNode.y, z = nextNode.z + 0.5, w = w }
                    last = nextNode
                end
                return points
            end
        end
    end
    return {}
end

RegisterNetEvent('noir_missions:client:chaseSpawn', function(requestId, minDistance, maxDistance, count)
    if source ~= 65535 then return end
    local points = ChaseSpawn.find(tonumber(minDistance) or 120.0, tonumber(maxDistance) or 450.0,
        math.max(1, math.min(4, math.floor(tonumber(count) or 1))))
    TriggerServerEvent('noir_missions:server:chaseSpawn', requestId, points)
end)

return ChaseSpawn
