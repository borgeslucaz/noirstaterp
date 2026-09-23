-- Territórios (noir_territories).
--
-- Segurar bairro rende um pouco por dia; perder bairro custa. Bairro fixo (dono por config) não
-- entra em nenhum dos dois: ele não foi tomado e não pode ser perdido, e o noir_territories nem
-- o lista entre as placas.

local Adapters = NoirIllegal.Adapters
local V = NoirIllegal.Validators

AddEventHandler('noir_territories:server:ownerChanged', function(zone, owner, previous)
    if not Adapters.from('noir_territories') then return end
    if not V.string(zone, 1, 64) or not V.string(previous, 1, 64) then return end

    Adapters.recordOrganization(previous, 'territory_lost', V.randomUuid(), {
        metadata = { zone = zone, newOwner = type(owner) == 'string' and owner or 'none' },
    })
end)

local function ownedTerritories()
    if GetResourceState('noir_territories') ~= 'started' then return nil end
    local ok, owned = pcall(function() return exports.noir_territories:getOwnedTerritories() end)
    if not ok or type(owned) ~= 'table' then return nil end
    return owned
end

---Paga o período corrente a quem estiver com cada placa. O id sai de bairro + gang + período, e
---é isso que torna o laço repetível: a segunda passada no mesmo dia, ou a primeira depois de um
---restart, cai em replay no ledger e não paga de novo.
function Adapters.payHeldTerritories(now)
    local owned = ownedTerritories()
    if not owned then return 0 end
    local period = math.floor((now or os.time()) / NoirIllegal.Config.Territories.heldPeriodSeconds)
    local count = 0
    for zone, gang in pairs(owned) do
        if V.string(zone, 1, 64) and V.string(gang, 1, 64) then
            Adapters.recordOrganization(gang, 'territory_held',
                V.stableUuid(('territory_held:%s:%s:%d'):format(zone, gang, period)), {
                    metadata = { zone = zone, period = period },
                })
            count = count + 1
        end
    end
    return count
end

CreateThread(function()
    while true do
        if NoirIllegal.Ready then Adapters.payHeldTerritories() end
        Wait(NoirIllegal.Config.Territories.checkSeconds * 1000)
    end
end)
