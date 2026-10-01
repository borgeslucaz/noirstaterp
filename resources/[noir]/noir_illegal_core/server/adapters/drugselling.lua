-- Venda de rua (noir_drugselling).
--
-- Rende reputação pessoal (drug e street), pesada pelo grau e pela droga. Não rende reputação
-- de gang: venda de rua é coisa que qualquer pessoa faz.

local Adapters = NoirIllegal.Adapters

---Grau × peso da droga (Config.SaleWeight). Puro, para teste.
---@param drug string?
---@param grade string?
---@return number
function Adapters.saleWeight(drug, grade)
    local cfg = NoirIllegal.Config.SaleWeight
    local gradeWeight = cfg.grades[grade] or cfg.grades[cfg.defaultGrade]
    local drugWeight = cfg.defaultDrug
    if type(drug) == 'string' then
        for _, entry in ipairs(cfg.drugs) do
            if drug:match(entry.pattern) then drugWeight = entry.weight break end
        end
    end
    return gradeWeight * drugWeight
end

AddEventHandler('noir_drugselling:server:saleCompleted', function(sale)
    if not Adapters.from('noir_drugselling') or type(sale) ~= 'table' then return end
    if type(sale.source) ~= 'number' then return end

    Adapters.record(sale.source, 'drug_sale', NoirIllegal.Validators.randomUuid(), {
        weight = Adapters.saleWeight(sale.drug, sale.grade),
        metadata = {
            drug = type(sale.drug) == 'string' and sale.drug or nil,
            amount = tonumber(sale.amount),
            saleType = sale.cornerSelling and 'corner' or 'ped',
        },
    })
end)
