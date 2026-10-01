---Escolha do ponto de nascimento de uma perseguição. Função pura, para testar sem jogo.
---
---Entre os pontos cadastrados, só vale o que está:
---  * a pelo menos `minDistance` de TODOS os participantes (não nasce na cara de ninguém);
---  * a no máximo `maxDistance` do alvo (não nasce do outro lado do mapa).
---Dos que valem, ganha o que está mais atrás do alvo em relação ao sentido em que ele anda —
---atrás é fora da vista de quem dirige e é de onde uma perseguição vem —, com desempate pela
---distância mais perto do meio da faixa.
local SpawnPoints = {}

local function distance2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

---Vetor unitário do sentido do alvo: velocidade quando anda, senão o heading.
---@param velocity? { x: number, y: number }
---@param heading? number graus, padrão do GTA (0 = norte, cresce para oeste)
---@return { x: number, y: number }
function SpawnPoints.forward(velocity, heading)
    if velocity then
        local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        if speed > 3.0 then return { x = velocity.x / speed, y = velocity.y / speed } end
    end
    local radians = math.rad(heading or 0.0)
    return { x = -math.sin(radians), y = math.cos(radians) }
end

---@param candidates table[] pontos { x, y, z, w? }
---@param opts { target: table, forward: table, players: table[], minDistance: number, maxDistance: number }
---@return integer? index
---@return number? score
function SpawnPoints.choose(candidates, opts)
    local bestIndex, bestScore
    local ideal = (opts.minDistance + opts.maxDistance) / 2
    for index = 1, #candidates do
        local point = candidates[index]
        local toTarget = distance2d(point, opts.target)
        local ok = toTarget <= opts.maxDistance
        if ok then
            for player = 1, #opts.players do
                if distance2d(point, opts.players[player]) < opts.minDistance then
                    ok = false
                    break
                end
            end
        end
        if ok then
            local dx, dy = point.x - opts.target.x, point.y - opts.target.y
            local length = math.max(0.001, math.sqrt(dx * dx + dy * dy))
            local ahead = (dx / length) * opts.forward.x + (dy / length) * opts.forward.y -- -1 atrás, 1 à frente
            local spread = math.abs(toTarget - ideal) / math.max(1, opts.maxDistance)
            local score = -ahead * 2.0 - spread
            if not bestScore or score > bestScore then bestIndex, bestScore = index, score end
        end
    end
    return bestIndex, bestScore
end

return SpawnPoints
