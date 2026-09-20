---Helpers sem estado, compartilhados por client e servidor.
---Regra: nada aqui toca native, evento ou export. É só cálculo e validação, para
---poder ser lido dos dois lados sem surpresa.

local Config = require 'config.shared'

local Utils = {}

---@param value any
---@return boolean
function Utils.isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

---@param value any
---@return boolean
function Utils.isInteger(value)
    return Utils.isFinite(value) and value % 1 == 0
end

---Inteiro positivo, que é o formato de netId, source e quantidade de item.
---@param value any
---@return boolean
function Utils.isPositiveInteger(value)
    return Utils.isInteger(value) and value > 0
end

---Cria um `DebugPrint` com escopo. A flag é lida a cada chamada, e não na criação,
---para que ligar o debug em runtime funcione sem restart.
---
---    local DebugPrint = Utils.debugPrint('smashgrab')
---    DebugPrint('recusado: distancia', distance)
---
---@param scope string
---@return fun(...: any)
function Utils.debugPrint(scope)
    local prefix = ('[%s]'):format(scope)
    return function(...)
        if not Config.debug then return end
        -- `info`, e não `debug`, de propósito: o nível padrão do `ox:printlevel`
        -- é `info`, então `lib.print.debug` é FILTRADO e não aparece no console.
        -- Quem liga `Config.debug` quer ver a saída — exigir também um convar que
        -- ele não sabe que existe é armadilha. A trava continua sendo a nossa
        -- flag; quem preferir o nível do ox pode usar
        -- `setr ox:printlevel:noir_prettycrimes debug`.
        lib.print.info(prefix, ...)
    end
end

---Rolagem de chance. Aceita 0..1; fora disso vira "nunca".
---@param probability number?
---@return boolean
function Utils.chance(probability)
    if not Utils.isFinite(probability) or probability <= 0 then return false end
    if probability >= 1 then return true end
    return math.random() < probability
end

---Inteiro dentro de um intervalo de config, aceito como número ou `{ min, max }`.
---@param range number|{ min: number, max: number }|nil
---@return integer
function Utils.randomInt(range)
    if Utils.isFinite(range) then return math.floor(range) end
    if type(range) ~= 'table' then return 0 end

    local min, max = range.min or range[1], range.max or range[2]
    if not Utils.isFinite(min) or not Utils.isFinite(max) then return 0 end

    min, max = math.floor(min), math.floor(max)
    if max < min then min, max = max, min end
    return math.random(min, max)
end

---Sorteio ponderado sobre uma lista de entradas com campo `weight`.
---Entrada sem peso válido é descartada; lista inteira inválida devolve nil.
---@generic T: { weight: number }
---@param entries T[]
---@return T?
function Utils.pickWeighted(entries)
    if type(entries) ~= 'table' or #entries == 0 then return nil end

    local total = 0
    for index = 1, #entries do
        local weight = entries[index] and entries[index].weight
        if Utils.isFinite(weight) and weight > 0 then total = total + weight end
    end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local cursor = 0
    for index = 1, #entries do
        local entry = entries[index]
        local weight = entry and entry.weight
        if Utils.isFinite(weight) and weight > 0 then
            cursor = cursor + weight
            if roll < cursor then return entry end
        end
    end

    return nil
end

---Transforma um conjunto (`{ chave = true }`) ou lista em lista ordenada.
---Ordenar importa: é o que deixa o log de boot igual entre dois starts.
---@param source table
---@return string[]
function Utils.sortedKeys(source)
    local keys = {}
    if type(source) ~= 'table' then return keys end
    for key in pairs(source) do
        if type(key) == 'string' then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return keys
end

return Utils
