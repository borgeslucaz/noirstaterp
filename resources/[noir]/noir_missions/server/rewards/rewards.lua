---Recompensa de missão concluída. Calculada só daqui, a partir da cópia da definição que a
---execução levou; nenhum evento de cliente chega aqui (§18).
local Config = require 'config.server'
local Runtime = require 'server.instances.runtime'
local Integrations = require 'server.integrations'

local Rewards = {}

---@param inst table
function Rewards.grant(inst)
    -- Marca antes de qualquer chamada que possa ceder a thread: nunca paga duas vezes.
    if inst.rewarded then return end
    inst.rewarded = true

    local participants = {}
    for _, source in ipairs(Runtime.participantList(inst)) do
        if GetPlayerName(source) then participants[#participants + 1] = source end
    end
    if #participants == 0 then return end

    local reason = ('%s:%s'):format(Config.rewards.moneyReason, inst.missionId)
    for index = 1, #inst.def.rewards do
        local reward = inst.def.rewards[index]
        local amount = math.floor(reward.amount or 0)
        local each, remainder = amount, 0
        if reward.split == 'split' then
            each = math.floor(amount / #participants)
            remainder = amount - each * #participants
        end
        for position = 1, #participants do
            local source = participants[position]
            local value = each + (position == 1 and remainder or 0)
            if value > 0 then
                if reward.type == 'money' then
                    if not Integrations.addMoney(source, reward.account or 'cash', value, reason) then
                        lib.print.error(('[noir_missions] #%d recompensa em dinheiro falhou para %s'):format(inst.id, source))
                    end
                elseif reward.item then
                    local ok, code = Integrations.addItem(source, reward.item, value)
                    if not ok then
                        Integrations.notify(source, 'Sem espaço para a recompensa da missão.', 'error')
                        lib.print.warn(('[noir_missions] #%d item %s x%d para %s falhou: %s'):format(
                            inst.id, reward.item, value, source, code))
                    end
                end
            end
        end
    end
    lib.print.info(('[noir_missions] #%d %s recompensa entregue a %d participantes'):format(
        inst.id, inst.missionId, #participants))
end

return Rewards
