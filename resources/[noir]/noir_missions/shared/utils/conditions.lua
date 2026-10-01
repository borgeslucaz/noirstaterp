---Condições de missão, avaliadas sem saber de onde vem o valor.
---
---    { mode = 'all' | 'any', rules = { { var = 'alarm_active', op = 'eq', value = true } } }
---
---Quem chama entrega `resolve(nome)`. O servidor resolve variáveis da instância e valores
---calculados (`cargo.barrels.loaded`, `group.guards.alive`); o teste entrega uma tabela.
local Conditions = {}

Conditions.ops = {
    { value = 'eq', label = 'igual a' },
    { value = 'neq', label = 'diferente de' },
    { value = 'gt', label = 'maior que' },
    { value = 'gte', label = 'maior ou igual a' },
    { value = 'lt', label = 'menor que' },
    { value = 'lte', label = 'menor ou igual a' },
    { value = 'true', label = 'é verdadeiro' },
    { value = 'false', label = 'é falso' },
}

local known = {}
for index = 1, #Conditions.ops do known[Conditions.ops[index].value] = true end

---Valor digitado no editor chega como texto. Converte para o tipo do lado esquerdo, para que
---`cargo_loaded >= "2"` compare número com número.
---@param left any
---@param right any
---@return any
local function coerce(left, right)
    if type(left) == 'number' and type(right) == 'string' then
        return tonumber(right) or right
    end
    if type(left) == 'boolean' and type(right) == 'string' then
        if right == 'true' then return true end
        if right == 'false' then return false end
    end
    if type(left) == 'string' and type(right) ~= 'string' and right ~= nil then
        return tostring(right)
    end
    return right
end

---@param value any
---@return boolean
local function truthy(value)
    if value == nil or value == false or value == 0 or value == '' or value == 'false' then return false end
    return true
end

---@param rule table
---@param resolve fun(name: string): any
---@return boolean
function Conditions.rule(rule, resolve)
    if type(rule) ~= 'table' or type(rule.var) ~= 'string' or not known[rule.op] then return false end
    local left = resolve(rule.var)
    local op = rule.op

    if op == 'true' then return truthy(left) end
    if op == 'false' then return not truthy(left) end

    local right = coerce(left, rule.value)
    if op == 'eq' then
        if left == nil then return right == nil or right == '' or right == false end
        return left == right
    end
    if op == 'neq' then
        if left == nil then return not (right == nil or right == '' or right == false) end
        return left ~= right
    end

    -- Comparação de ordem só entre números. Variável ainda não definida conta como 0, que é
    -- o que se espera de um contador que ninguém incrementou.
    left = tonumber(left) or (left == nil and 0 or nil)
    right = tonumber(right)
    if not left or not right then return false end
    if op == 'gt' then return left > right end
    if op == 'gte' then return left >= right end
    if op == 'lt' then return left < right end
    if op == 'lte' then return left <= right end
    return false
end

---Sem condição, ou sem regra, é verdadeiro: um passo sem condição sempre roda.
---@param condition table?
---@param resolve fun(name: string): any
---@return boolean
function Conditions.evaluate(condition, resolve)
    if type(condition) ~= 'table' or type(condition.rules) ~= 'table' or #condition.rules == 0 then
        return true
    end
    local any = condition.mode == 'any'
    for index = 1, #condition.rules do
        local passed = Conditions.rule(condition.rules[index], resolve)
        if any and passed then return true end
        if not any and not passed then return false end
    end
    return not any
end

---@param condition any
---@return boolean
function Conditions.isEmpty(condition)
    return type(condition) ~= 'table' or type(condition.rules) ~= 'table' or #condition.rules == 0
end

return Conditions
