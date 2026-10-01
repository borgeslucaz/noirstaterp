---Utilitários puros, sem natives.

local Utils = {}

---@param value any
---@return boolean
function Utils.isFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---Inteiro positivo dentro da faixa, ou nil.
---@param value any
---@param minimum number
---@param maximum number
---@return integer?
function Utils.intInRange(value, minimum, maximum)
    value = tonumber(value)
    if not Utils.isFinite(value) or value % 1 ~= 0 then return nil end
    if value < minimum or value > maximum then return nil end
    return math.floor(value)
end

---Texto limpo e limitado, ou nil.
---@param value any
---@param maximum integer
---@param minimum? integer
---@return string?
function Utils.cleanText(value, maximum, minimum)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #value < (minimum or 1) or #value > maximum then return nil end
    return value
end

---vector3/table/array -> {x, y, z} com números finitos e dentro do mapa.
---@param value any
---@return vector3?
function Utils.toVec3(value)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x, y, z = value.x, value.y, value.z
    if x == nil then x, y, z = value[1], value[2], value[3] end
    if not Utils.isFinite(x) or not Utils.isFinite(y) or not Utils.isFinite(z) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return vector3 and vector3(x, y, z) or { x = x, y = y, z = z }
end

---@param tbl table
---@return string[]
function Utils.sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

---Faixa da multa do radar para um excesso. `fines` em ordem crescente de `over`.
---@param fines { over: number, fine: number }[]
---@param over number
---@return number? fine
function Utils.radarFine(fines, over)
    local chosen
    for index = 1, #fines do
        if over >= fines[index].over then chosen = fines[index].fine end
    end
    return chosen
end

---Identificador opaco (não previsível pelo source nem pelo relógio sozinho).
---@param prefix string
---@return string
function Utils.opaqueId(prefix)
    local chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'
    local out = {}
    for index = 1, 10 do
        local pick = math.random(1, #chars)
        out[index] = chars:sub(pick, pick)
    end
    return ('%s-%s-%s'):format(prefix, os.time(), table.concat(out))
end

---Soma pendências por item, separando dinheiro (por valor) de itens (por quantidade).
---Usado na conferência do depósito: é a parte pura, testável sem inventário.
---@param deposited { name: string, count: integer }[]
---@param pending { id: integer, item: string, count: integer }[]
---@return integer[] matchedIds, table<string, integer> leftover
function Utils.matchPending(deposited, pending)
    local available = {}
    for index = 1, #deposited do
        local entry = deposited[index]
        available[entry.name] = (available[entry.name] or 0) + entry.count
    end

    local matched = {}
    for index = 1, #pending do
        local entry = pending[index]
        local have = available[entry.item] or 0
        if have >= entry.count then
            available[entry.item] = have - entry.count
            matched[#matched + 1] = entry.id
        end
    end
    return matched, available
end

---Código de DNA: o mesmo personagem sempre gera o mesmo código, mas o código não volta
---para o citizenid sem a chave do servidor. Dois joaat com a chave em lados opostos
---dão 64 bits, o bastante para não colidir entre personagens.
---@param secret string
---@param citizenId string
---@return string
function Utils.dnaCode(secret, citizenId)
    local a = (math.tointeger(joaat(('%s:dna:a:%s'):format(secret, citizenId))) or 0) & 0xFFFFFFFF
    local b = (math.tointeger(joaat(('%s:dna:b:%s'):format(citizenId, secret))) or 0) & 0xFFFFFFFF
    return ('%08X%08X'):format(a, b)
end

return Utils
