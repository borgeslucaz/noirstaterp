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

---Hash de model numa forma canônica: uint32, sempre.
---
---**Toda** entrada e toda consulta da allowlist passam por aqui, e é a única
---razão de esta função existir. A versão anterior normalizava só a CONSULTA e
---guardava a chave crua do `joaat` — o que funciona enquanto o `joaat` devolve
---uint32 e quebra em silêncio quando ele devolve int32 com sinal.
---
---Quebra só para metade dos models, ainda por cima: um hash abaixo de 2^31 é
---igual nas duas formas, então `prop_parknmeter_02` (2108567945) passava e
---`prop_parknmeter_01` (2354728673) era recusado pela mesma allowlist. Meio
---sistema funcionando é bem pior que nenhum, porque parece configuração errada.
---@param value any
---@return number? hash
function Rules.normalizeHash(value)
    if not Utils.isFinite(value) then return nil end
    return math.floor(value) % 0x100000000
end

---Models aceitos, por hash. Allowlist do §7.4: o client manda o hash do model que
---mirou, e um hash fora daqui é recusado antes de qualquer outro trabalho.
---@type table<number, boolean>
Rules.modelHashes = {}
for index = 1, #CrimeConfig.models do
    Rules.modelHashes[Rules.normalizeHash(joaat(CrimeConfig.models[index]))] = true
end

---@param model any
---@return boolean
function Rules.isAllowedModel(model)
    local hash = Rules.normalizeHash(model)
    return hash ~= nil and Rules.modelHashes[hash] == true
end

---Os hashes aceitos, em texto e em ordem, para mensagem de erro.
---
---Ordenado porque a saída vai para log: duas execuções do mesmo servidor
---precisam imprimir a mesma linha, senão comparar dois relatos vira trabalho.
---@return string[]
function Rules.expectedHashes()
    local list = {}
    for hash in pairs(Rules.modelHashes) do list[#list + 1] = hash end
    table.sort(list)
    for index = 1, #list do list[index] = ('%d'):format(list[index]) end
    return list
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

---Soma das duas barras. É a duração que o servidor mede contra o tempo decorrido
---entre reservar e entregar, e ela é a mesma conta nos dois lados.
---@return integer ms
function Rules.totalDuration()
    return CrimeConfig.pryDuration + CrimeConfig.collectDuration
end

return Rules
