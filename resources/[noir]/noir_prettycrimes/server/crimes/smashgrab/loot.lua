---Smash & Grab — o que vem dentro do objeto.
---
---Lido só no servidor, e rolado só na entrega. Não entra na semente determinística
---de propósito: a semente é reproduzível por quem souber o salt, e o conteúdo do
---saque é a única coisa deste sistema que precisa ser imprevisível. A EXISTÊNCIA
---do objeto não precisa — ela está pendurada no banco de trás, à vista de todos.

local Utils = require 'shared.utils'
local ServerConfig = require 'config.smashgrab_server'
local Integrations = require 'server.integrations'

local Loot = {}

---Um sorteio escolhe UMA entrada, com `chance` valendo como peso em 100. Se as
---chances de uma mesa somam menos de 100, a diferença é a chance de o sorteio sair
---vazio — é assim que "quase sempre vem pouca coisa" se afina sem inventar campo.
---@param entries table[]
---@return table? entry
local function drawOne(entries)
    local roll = math.random() * 100
    local cursor = 0

    for index = 1, #entries do
        local entry = entries[index]
        local chance = entry and entry.chance
        if Utils.isFinite(chance) and chance > 0 then
            cursor = cursor + chance
            if roll < cursor then return entry end
        end
    end

    return nil
end

---@param entry table
---@return integer
local function amountFor(entry)
    return math.max(1, Utils.randomInt({ min = entry.min or 1, max = entry.max or 1 }))
end

---Sorteia o conteúdo. Nada é concedido aqui: só decidido.
---@param tableKey string
---@param moneyMultiplier number?
---@return { kind: 'money'|'item', item?: string, account?: string, amount: integer }[]
function Loot.roll(tableKey, moneyMultiplier)
    local lootTable = ServerConfig.lootTables[tableKey]
    if type(lootTable) ~= 'table' or type(lootTable.items) ~= 'table' then return {} end

    local multiplier = Utils.isFinite(moneyMultiplier) and moneyMultiplier > 0 and moneyMultiplier or 1.0
    local rolls = math.max(1, Utils.randomInt(lootTable.rolls))
    local rewards = {}

    for _ = 1, rolls do
        local entry = drawOne(lootTable.items)
        if entry then
            if type(entry.money) == 'string' then
                local amount = math.floor(amountFor(entry) * multiplier)
                if amount > 0 then
                    rewards[#rewards + 1] = { kind = 'money', account = entry.money, amount = amount }
                end
            elseif type(entry.item) == 'string' then
                rewards[#rewards + 1] = { kind = 'item', item = entry.item, amount = amountFor(entry) }
            end
        end
    end

    return rewards
end

---Entrega e devolve só o que realmente entrou. Item que não cabe na mochila não é
---concedido — e, por consequência, também não é prometido na notificação.
---@param source number
---@param rewards table[]
---@return table[] granted
function Loot.grant(source, rewards)
    local granted = {}

    for index = 1, #rewards do
        local reward = rewards[index]

        if reward.kind == 'money' then
            if Integrations.addMoney(source, reward.account, reward.amount, 'smashgrab') then
                granted[#granted + 1] = reward
            end
        elseif Integrations.addItem(source, reward.item, reward.amount) then
            -- Sem `CanCarryItem` antes: o `AddItem` já recusa o que não cabe, e a
            -- pergunta separada só abria uma janela entre checar e entregar.
            granted[#granted + 1] = reward
        end
    end

    return granted
end

---@param granted table[]
---@return string
function Loot.describe(granted)
    local parts = {}
    for index = 1, #granted do
        local reward = granted[index]
        parts[#parts + 1] = reward.kind == 'money'
            and ('$%d'):format(reward.amount)
            or ('%dx %s'):format(reward.amount, Integrations.itemLabel(reward.item))
    end
    return table.concat(parts, ', ')
end

return Loot
