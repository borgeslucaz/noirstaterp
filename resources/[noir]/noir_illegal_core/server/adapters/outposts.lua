-- Outposts (noir_outposts).
--
-- O id da operação que o outpost grava no próprio ledger vira o id da transação aqui: a mesma
-- operação nunca rende duas vezes, mesmo que o evento chegue repetido.

local Adapters = NoirIllegal.Adapters
local V = NoirIllegal.Validators

local function operationId(event)
    return type(event) == 'table' and V.uuid(event.operationId) and event.operationId or nil
end

-- Venda passiva: não tem autor, é da gang dona do posto.
AddEventHandler('noir_outposts:server:saleCommitted', function(sale)
    if not Adapters.from('noir_outposts') then return end
    local id = operationId(sale)
    if not id or not V.string(sale.organizationId, 1, 64) then return end

    Adapters.recordOrganization(sale.organizationId, 'outpost_sale', id, {
        metadata = {
            outpostId = sale.outpostId,
            dealerId = sale.dealerId,
            product = sale.item,
            quantity = sale.quantity,
        },
    })
end)

-- Tomada: ato de força, rende de uma vez para a gang de quem tomou. Se o mesmo posto já foi
-- dela na janela (Config.OutpostRetakeSeconds), a gang não ganha de novo; quem tomou continua
-- com a parte pessoal.
AddEventHandler('noir_outposts:server:claimCompleted', function(claim)
    if not Adapters.from('noir_outposts') then return end
    local id = operationId(claim)
    if not id or type(claim.source) ~= 'number' then return end

    CreateThread(function()
        local retake = V.string(claim.organizationId, 1, 64) and V.string(claim.outpostId, 1, 64)
            and NoirIllegal.Repositories.Activity.recentForOrganization(claim.organizationId,
                'outpost_claim', 'outpostId', claim.outpostId, NoirIllegal.Config.OutpostRetakeSeconds)
        Adapters.record(claim.source, 'outpost_claim', id, {
            organizationId = claim.organizationId,
            withoutOrganization = retake == true or nil,
            metadata = {
                outpostId = claim.outpostId,
                previousOwnerId = claim.previousOwnerId,
            },
        })
    end)
end)

-- Assalto: rende rua para quem assaltou e custa reputação à gang dona do posto. São dois fatos
-- de uma operação só, então o segundo deriva o id do primeiro — de forma estável, para o
-- replay continuar valendo.
AddEventHandler('noir_outposts:server:robberyCompleted', function(robbery)
    if not Adapters.from('noir_outposts') then return end
    local id = operationId(robbery)
    if not id then return end

    if type(robbery.source) == 'number' then
        Adapters.record(robbery.source, 'outpost_robbery', id, {
            metadata = {
                outpostId = robbery.outpostId,
                dealerId = robbery.dealerId,
                lootValue = robbery.lootValue,
            },
        })
    end

    if V.string(robbery.ownerOrganizationId, 1, 64) then
        Adapters.recordOrganization(robbery.ownerOrganizationId, 'outpost_robbed',
            V.stableUuid('outpost_robbed:' .. id), {
                metadata = {
                    outpostId = robbery.outpostId,
                    dealerId = robbery.dealerId,
                },
            })
    end
end)
