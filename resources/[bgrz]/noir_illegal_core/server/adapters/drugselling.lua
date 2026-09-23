-- Venda de rua (noir_drugselling).
--
-- É o trabalho diário da gang: pouco por venda, muito no volume. Rende também para quem vende
-- sem gang — a parte pessoal —, e a parte da organização simplesmente não se aplica.

local Adapters = NoirIllegal.Adapters

AddEventHandler('noir_drugselling:server:saleCompleted', function(sale)
    if not Adapters.from('noir_drugselling') or type(sale) ~= 'table' then return end
    if type(sale.source) ~= 'number' then return end

    Adapters.record(sale.source, 'drug_sale', NoirIllegal.Validators.randomUuid(), {
        metadata = {
            drug = type(sale.drug) == 'string' and sale.drug or nil,
            amount = tonumber(sale.amount),
            saleType = sale.cornerSelling and 'corner' or 'ped',
        },
    })
end)
