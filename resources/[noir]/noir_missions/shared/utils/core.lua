---Utilitários puros, iguais nos dois lados. Nada aqui chama native do jogo, para que os
---testes rodem em Lua puro.
local Utils = {}

---@param value any
---@return any
function Utils.deepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, inner in pairs(value) do
        copy[Utils.deepCopy(key, seen)] = Utils.deepCopy(inner, seen)
    end
    return copy
end

---@param value any
---@return boolean
function Utils.isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@param min number
---@param max number
---@param fallback number
---@return number
function Utils.clampNumber(value, min, max, fallback)
    if type(value) == 'string' then value = tonumber(value) end
    if not Utils.isFiniteNumber(value) then return fallback end
    if value < min then return min end
    if value > max then return max end
    return value
end

---@param value any
---@param maxLength integer
---@param fallback? string
---@return string
function Utils.cleanString(value, maxLength, fallback)
    if type(value) == 'number' or type(value) == 'boolean' then value = tostring(value) end
    if type(value) ~= 'string' then return fallback or '' end
    value = value:gsub('[%c]', function(char)
        return char == '\n' and '\n' or ''
    end)
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

---IDs internos: minúsculas, números, `_` e `-`. É o que vai em nome de arquivo e em chave
---de tabela, então qualquer outra coisa é recusada em vez de corrigida em silêncio.
---@param value any
---@param maxLength? integer
---@return boolean
function Utils.isId(value, maxLength)
    return type(value) == 'string' and #value >= 2 and #value <= (maxLength or 48)
        and value:match('^[a-z0-9][a-z0-9_%-]*$') ~= nil
end

---Coordenada vinda do JSON: `{ x, y, z, w? }`, todos finitos.
---@param value any
---@return boolean
function Utils.isPosition(value)
    return type(value) == 'table'
        and Utils.isFiniteNumber(value.x) and Utils.isFiniteNumber(value.y) and Utils.isFiniteNumber(value.z)
        and (value.w == nil or Utils.isFiniteNumber(value.w))
end

---@param a table
---@param b table
---@return number
function Utils.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Distância só no plano. Zona de missão é cilindro: subir num telhado não tira ninguém dela.
---@param a table
---@param b table
---@return number
function Utils.distance2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

---@generic T
---@param list T[]
---@param random? fun(m: integer, n?: integer): integer
---@return T[]
function Utils.shuffle(list, random)
    random = random or math.random
    local copy = {}
    for index = 1, #list do copy[index] = list[index] end
    for index = #copy, 2, -1 do
        local swap = random(1, index)
        copy[index], copy[swap] = copy[swap], copy[index]
    end
    return copy
end

---@generic T
---@param list T[]
---@param random? fun(m: integer, n?: integer): integer
---@return T?
function Utils.pick(list, random)
    if type(list) ~= 'table' or #list == 0 then return nil end
    return list[(random or math.random)(1, #list)]
end

---Sorteio entre `min` e `max` inteiros, aceitando min > max e valores ausentes.
---@param min any
---@param max any
---@param random? fun(m: integer, n?: integer): integer
---@return integer
function Utils.randomBetween(min, max, random)
    min = math.floor(tonumber(min) or 0)
    max = math.floor(tonumber(max) or min)
    if max < min then min, max = max, min end
    if min == max then return min end
    return (random or math.random)(min, max)
end

---@param list table[]?
---@param id string
---@return table? item
---@return integer? index
function Utils.findById(list, id)
    if type(list) ~= 'table' then return nil end
    for index = 1, #list do
        if list[index].id == id then return list[index], index end
    end
    return nil
end

---@param list any[]
---@param value any
---@return boolean
function Utils.contains(list, value)
    if type(list) ~= 'table' then return false end
    for index = 1, #list do
        if list[index] == value then return true end
    end
    return false
end

---Conta pares de uma tabela associativa.
---@param map table
---@return integer
function Utils.count(map)
    local total = 0
    for _ in pairs(map) do total = total + 1 end
    return total
end

return Utils
