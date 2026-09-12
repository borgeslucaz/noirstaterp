-- Funções puras compartilhadas: validação de payload e fórmulas econômicas.
-- Sem I/O, sem natives, sem estado. Testadas em tests/unit.
NoirOutposts = NoirOutposts or {}

local V = {}
NoirOutposts.Validators = V

local limits = NoirOutposts.Constants.Limits

function V.isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

---@param value any
---@param maximum? number
---@return boolean
function V.isPositiveInteger(value, maximum)
    if not V.isFinite(value) or value % 1 ~= 0 or value < 1 then return false end
    if maximum ~= nil and value > maximum then return false end
    return true
end

---@param value any
---@param maximum? integer
---@return boolean
function V.isIdentifier(value, maximum)
    if type(value) ~= 'string' or #value == 0 then return false end
    if #value > (maximum or limits.maxIdentifierLength) then return false end
    return value:match('^[%w_%-]+$') ~= nil
end

---@param value any
---@return boolean
function V.isRequestId(value)
    if type(value) ~= 'string' or #value < 8 or #value > limits.maxRequestIdLength then return false end
    return value:match('^[%w%-_]+$') ~= nil
end

function V.clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

---Intervalo entre vendas em segundos.
---@param baseInterval number
---@param minimumInterval number
---@param speed number 0..100
---@return integer seconds
function V.saleInterval(baseInterval, minimumInterval, speed)
    local factor = 1.20 - V.clamp(tonumber(speed) or 0, 0, 100) / 100
    local interval = math.floor(baseInterval * factor + 0.5)
    if interval < minimumInterval then interval = minimumInterval end
    return interval
end

---Lote máximo que o dealer processa por venda.
---@param capacity number 0..100
---@param divisor number
---@return integer
function V.dealerLot(capacity, divisor)
    local lot = math.floor(V.clamp(tonumber(capacity) or 0, 0, 100) / (divisor or 20))
    if lot < 1 then lot = 1 end
    return lot
end

---Quantidade efetiva de uma venda: limitada por produto, dealer e estoque.
---@param productRange { min: integer, max: integer }
---@param dealerLot integer
---@param stock integer
---@param roll number 0..1
---@return integer quantity 0 quando não há estoque
function V.saleQuantity(productRange, dealerLot, stock, roll)
    if stock <= 0 then return 0 end
    local span = productRange.max - productRange.min
    local wanted = productRange.min + math.floor(V.clamp(roll, 0, 0.999999) * (span + 1))
    if wanted > dealerLot then wanted = dealerLot end
    if wanted > stock then wanted = stock end
    if wanted < 1 then wanted = 1 end
    return wanted
end

---Valores brutos, comissão e líquido de uma venda.
---@param unitPrice number
---@param quantity integer
---@param jitter number multiplicador de preço (ex.: 0.95..1.05)
---@param negotiation number 0..100
---@param split number percentual do dealer
---@return { unitPrice: integer, gross: integer, commission: integer, net: integer }
function V.saleAmounts(unitPrice, quantity, jitter, negotiation, split)
    local price = unitPrice * jitter * (1 + V.clamp(tonumber(negotiation) or 0, 0, 100) / 1000)
    local roundedPrice = math.floor(price + 0.5)
    local gross = roundedPrice * quantity
    local commission = math.floor(gross * V.clamp(tonumber(split) or 0, 0, 100) / 100)
    return {
        unitPrice = roundedPrice,
        gross = gross,
        commission = commission,
        net = gross - commission,
    }
end

---Loot de um roubo: percentuais sobre a carteira e sobre o estoque de um produto.
---@param purse integer
---@param stock integer
---@param pursePercent number
---@param stockPercent number
---@param maxStockUnits integer
---@return integer purseLoot, integer stockLoot
function V.robberyLoot(purse, stock, pursePercent, stockPercent, maxStockUnits)
    local purseLoot = math.floor(math.max(0, purse) * V.clamp(pursePercent, 0, 100) / 100)
    local stockLoot = math.ceil(math.max(0, stock) * V.clamp(stockPercent, 0, 100) / 100)
    if stockLoot > maxStockUnits then stockLoot = maxStockUnits end
    if stockLoot > stock then stockLoot = stock end
    if stock <= 0 then stockLoot = 0 end
    return purseLoot, stockLoot
end

---Transições permitidas de sessão.
local sessionTransitions = {
    OPENING = { READY = true, ABORTED = true, CLOSED = true },
    READY = { PROCESSING = true, CLOSING = true, ABORTED = true, CLOSED = true },
    PROCESSING = { READY = true, CLOSING = true, ABORTED = true, CLOSED = true },
    CLOSING = { CLOSED = true, ABORTED = true },
    ABORTED = { CLOSED = true },
    CLOSED = {},
}

---@param from string
---@param to string
---@return boolean
function V.canTransitionSession(from, to)
    local allowed = sessionTransitions[from]
    return allowed ~= nil and allowed[to] == true
end

---Transições permitidas de outpost.
local outpostTransitions = {
    inactive = { available = true },
    available = { claiming = true, inactive = true },
    claiming = { available = true, controlled = true, inactive = true },
    controlled = { contested = true, available = true, inactive = true },
    contested = { controlled = true, cooldown = true, inactive = true },
    cooldown = { controlled = true, inactive = true },
}

---@param from string
---@param to string
---@return boolean
function V.canTransitionOutpost(from, to)
    local allowed = outpostTransitions[from]
    return allowed ~= nil and allowed[to] == true
end

---Decide se o painel aberto deve fechar sozinho.
---Pura de propósito: a versão inline já escondeu um bug de verdade, porque o `cache.vehicle`
---do ox_lib devolve `false` a pé, e não `nil`.
---@param facts { dead: boolean, inVehicle: boolean, distance: number? }
---@param maxDistance number
---@return boolean
function V.shouldClosePanel(facts, maxDistance)
    if facts.dead == true or facts.inVehicle == true then return true end
    if not V.isFinite(facts.distance) then return false end
    return facts.distance > maxDistance
end

---Decide se um corredor deve ser considerado derrubado.
---A vida de um ped só é confiável enquanto algum client o transmite: sem dono de rede o
---servidor devolve 0 para um ped perfeitamente vivo, o que derrubaria todo mundo que
---ninguém está olhando. Por isso exige dono e já ter sido visto vivo.
---@param owned boolean algum client é dono de rede da entidade
---@param seenAlive boolean já foi observado vivo enquanto tinha dono
---@param health number
---@return boolean
function V.isDealerDown(owned, seenAlive, health)
    if owned ~= true or seenAlive ~= true then return false end
    if not V.isFinite(health) then return false end
    return health <= 0
end

---Verifica se a grade atende ao mínimo configurado para a ação.
---@param grade number|nil
---@param permissions table<string, number>
---@param action string
---@return boolean
function V.hasGrade(grade, permissions, action)
    local required = permissions[action]
    if required == nil then return false end
    return (tonumber(grade) or -1) >= required
end

---Mapa de permissões efetivas.
---@param grade number|nil
---@param permissions table<string, number>
---@param keys string[]
---@return table<string, boolean>
function V.permissionMap(grade, permissions, keys)
    local result = {}
    for index = 1, #keys do
        result[keys[index]] = V.hasGrade(grade, permissions, keys[index])
    end
    return result
end
