-- Rota de coleta concluída (noir_gathering).
--
-- O gathering anuncia a entrega com o valor que o admin configurou na rota, e ele vai para a
-- reputação `gang`. O teto por entrega está na atividade `gathering_delivery`; valor acima
-- dele é recusado inteiro, não cortado, para o erro de config aparecer no log em vez de pagar
-- pela metade em silêncio. O teto do dia da gang corta normalmente.

local Adapters = NoirIllegal.Adapters

AddEventHandler('noir_gathering:server:routeCompleted', function(delivery)
    if not Adapters.from('noir_gathering') or type(delivery) ~= 'table' then return end
    if type(delivery.source) ~= 'number' or type(delivery.reward) ~= 'table' then return end

    -- A gang tem uma reputação só: a categoria escolhida na rota é ignorada e o valor vai
    -- para `gang`.
    local total = 0
    for _, amount in pairs(delivery.reward) do
        if type(amount) == 'number' and amount > 0 then total = total + amount end
    end
    if total <= 0 then return end

    Adapters.record(delivery.source, 'gathering_delivery', NoirIllegal.Validators.randomUuid(), {
        reward = { gang = total },
        metadata = {
            routeId = tonumber(delivery.routeId),
            route = type(delivery.route) == 'string' and delivery.route:sub(1, 64) or nil,
        },
    })
end)
