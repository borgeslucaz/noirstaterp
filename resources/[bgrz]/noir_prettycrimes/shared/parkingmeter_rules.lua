---Parquímetro — a identidade de um poste, calculada igual nos dois lados.
---
---Todo o módulo depende de uma pergunta: **como dois processos diferentes chamam
---o mesmo poste pelo mesmo nome, sem que exista entidade?**
---
---A resposta é a coordenada em grade. Prop de mapa não anda, e a posição dele é
---idêntica em todos os clients; arredondada para células de `gridSize`, ela vira
---uma string estável que o client calcula para consultar sua lista local e o
---servidor calcula para decidir. Nenhum dos dois manda a chave pronta para o
---outro confiar — cada um a recomputa a partir de coordenada.
---
---Tudo aqui é função pura: sem native, sem evento, sem export. É o que permite
---testar em Lua puro (§22.1) e é por isso que o cálculo mora no shared em vez de
---ser copiado nos dois lados, onde uma divergência de arredondamento seria um bug
---silencioso — o servidor esvaziaria um poste e o client continuaria oferecendo
---outro.

local Utils = require 'shared.utils'
local CrimeConfig = require 'config.parkingmeter'

local Rules = {}

---Models aceitos, por hash. Allowlist do §7.4: o client manda o hash do model que
---mirou, e um hash fora daqui é recusado antes de qualquer outro trabalho.
---@type table<number, boolean>
Rules.modelHashes = {}
for index = 1, #CrimeConfig.models do
    Rules.modelHashes[joaat(CrimeConfig.models[index])] = true
end

---@param model any
---@return boolean
function Rules.isAllowedModel(model)
    if not Utils.isFinite(model) then return false end
    -- joaat devolve uint32; um hash que atravessou a rede como inteiro com sinal
    -- aponta para o mesmo model e não pode ser recusado por causa do sinal.
    return Rules.modelHashes[math.floor(model) % 0x100000000] == true
end

---Aceita vector3 ou a tabela `{ x, y, z }` que sobrevive ao json de um callback.
---@param coords any
---@return number? x
---@return number? y
---@return number? z
function Rules.readCoords(coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return nil end
    local x, y, z = coords.x, coords.y, coords.z
    if not Utils.isFinite(x) or not Utils.isFinite(y) or not Utils.isFinite(z) then
        return nil
    end
    -- O mapa do GTA V cabe folgado aqui. Coordenada fora disto não é um poste, é
    -- um número inventado, e recusar cedo poupa o resto da validação.
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then
        return nil
    end
    return x, y, z
end

---Identidade do poste: a célula da grade em que ele está.
---
---`math.floor(v / size + 0.5)` é arredondamento para o inteiro mais próximo, e
---não truncamento: com truncamento, dois valores a um milímetro um do outro mas
---em lados opostos de uma borda de célula cairiam em chaves diferentes. Vale para
---negativo do mesmo jeito, que é metade do mapa.
---@param coords any
---@return string? key
function Rules.meterKey(coords)
    local x, y, z = Rules.readCoords(coords)
    if not x then return nil end

    local size = CrimeConfig.gridSize
    if not Utils.isFinite(size) or size <= 0 then size = 0.5 end

    return ('%d:%d:%d'):format(
        math.floor(x / size + 0.5),
        math.floor(y / size + 0.5),
        math.floor(z / size + 0.5))
end

---Distância no plano horizontal entre dois pontos.
---
---Horizontal de propósito: o alvo do ox_target fica na altura da cabeça do poste
---e o jogador está no chão, então a diferença de Z é ruído constante que só
---apertaria o limite sem proteger nada.
---@param a table
---@param b table
---@return number? distance
function Rules.flatDistance(a, b)
    local ax, ay = Rules.readCoords(a)
    local bx, by = Rules.readCoords(b)
    if not ax or not bx then return nil end
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

---O poste cai em alguma área onde parquímetro existe?
---
---A lista vem do config de SERVIDOR, mas a função mora aqui porque é geometria
---pura e é testável assim. O client nunca a chama: ele não recebe as áreas.
---@param coords any
---@param areas table[]
---@return boolean
function Rules.inAnyArea(coords, areas)
    local x, y, z = Rules.readCoords(coords)
    if not x or type(areas) ~= 'table' then return false end

    for index = 1, #areas do
        local area = areas[index]
        local ax, ay, az = Rules.readCoords(area and area.coords)
        if ax and Utils.isFinite(area.radius) then
            local dx, dy, dz = x - ax, y - ay, z - az
            if (dx * dx + dy * dy + dz * dz) <= (area.radius * area.radius) then
                return true
            end
        end
    end

    return false
end

---Soma das duas barras. É a duração que o servidor mede contra o tempo decorrido
---entre reservar e entregar, e ela é a mesma conta nos dois lados.
---@return integer ms
function Rules.totalDuration()
    return CrimeConfig.pryDuration + CrimeConfig.collectDuration
end

return Rules
