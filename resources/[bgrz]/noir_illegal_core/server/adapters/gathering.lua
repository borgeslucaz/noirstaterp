-- Rota de coleta concluída (noir_gathering).
--
-- O gathering anuncia a entrega com a categoria e o valor que o admin configurou na rota. O
-- teto está na atividade `gathering_delivery`; valor acima dele é recusado inteiro, não
-- cortado, para o erro de config aparecer no log em vez de pagar pela metade em silêncio.

local Adapters = NoirIllegal.Adapters

AddEventHandler('noir_gathering:server:routeCompleted', function(delivery)
    if not Adapters.from('noir_gathering') or type(delivery) ~= 'table' then return end
    if type(delivery.source) ~= 'number' or type(delivery.reward) ~= 'table' then return end

    Adapters.record(delivery.source, 'gathering_delivery', NoirIllegal.Validators.randomUuid(), {
        reward = delivery.reward,
        metadata = {
            routeId = tonumber(delivery.routeId),
            route = type(delivery.route) == 'string' and delivery.route:sub(1, 64) or nil,
        },
    })
end)
