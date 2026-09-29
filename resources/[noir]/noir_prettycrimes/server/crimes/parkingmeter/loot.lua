---Parquímetro — o que sai da caixa de moedas.
---
---Lido só no servidor, e rolado só na entrega. O client nunca vê o intervalo, nem
---antes nem depois: ele recebe o texto do que recebeu, não os números que geraram.

local Utils = require 'shared.utils'
local ServerConfig = require 'config.parkingmeter_server'
local Integrations = require 'server.integrations'

local Loot = {}

---Sorteia o conteúdo. Nada é concedido aqui: só decidido.
---@return { kind: 'money'|'item', item?: string, account?: string, amount: integer }[]
function Loot.roll()
    local reward = ServerConfig.reward
    local rewards = {}

    local money = reward.money
    if type(money) == 'table' then
        local amount = Utils.randomInt({ min = money.min or 0, max = money.max or 0 })
        if amount > 0 then
            rewards[#rewards + 1] = {
                kind = 'money',
                account = money.account or 'cash',
                amount = amount,
            }
        end
    end

    local items = reward.items
    if type(items) == 'table' then
        for index = 1, #items do
            local entry = items[index]
            -- Cada item tem a SUA rolagem, independente das outras: a caixa não
            -- escolhe um prêmio, ela ou tem ou não tem cada coisa.
            if type(entry) == 'table' and type(entry.item) == 'string'
                and Utils.chance(entry.chance) then
                local amount = math.max(1, Utils.randomInt({ min = entry.min or 1, max = entry.max or 1 }))
                rewards[#rewards + 1] = { kind = 'item', item = entry.item, amount = amount }
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
            if Integrations.addMoney(source, reward.account, reward.amount, 'parkingmeter') then
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
