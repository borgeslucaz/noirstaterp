-- Territórios (noir_territories).
--
-- Tomar bairro é o marco; segurar rende um pouco por dia, só para a gang que agiu no bairro nas
-- últimas 24h; perder custa. Bairro fixo (dono por config) não entra em nenhum: ele não foi
-- tomado e não pode ser perdido, e o noir_territories nem o lista entre as placas.

local Adapters = NoirIllegal.Adapters
local V = NoirIllegal.Validators

---Dia do relógio do servidor (o mesmo período do bairro segurado).
local function currentPeriod(now)
    return math.floor((now or os.time()) / NoirIllegal.Config.Territories.heldPeriodSeconds)
end

-- Troca de dono. Troca feita por admin (`reason == 'admin'`) não paga nem cobra: não foi jogo.
AddEventHandler('noir_territories:server:ownerChanged', function(zone, owner, previous, reason)
    if not Adapters.from('noir_territories') then return end
    if not V.string(zone, 1, 64) or reason == 'admin' then return end
    local period = currentPeriod()

    -- Tomada: o marco. Uma vez por bairro e gang por dia.
    if V.string(owner, 1, 64) then
        Adapters.recordOrganization(owner, 'territory_taken',
            V.stableUuid(('territory_taken:%s:%s:%d'):format(zone, owner, period)), {
                metadata = { zone = zone, previousOwner = V.string(previous, 1, 64) and previous or 'none' },
            })
    end

    if V.string(previous, 1, 64) then
        Adapters.recordOrganization(previous, 'territory_lost', V.randomUuid(), {
            metadata = { zone = zone, newOwner = type(owner) == 'string' and owner or 'none' },
        })
    end
end)

---A gang agiu no bairro (venda, pichação) dentro da janela? Sem a resposta do noir_territories,
---não paga: bairro segurado é renda de quem trabalha a rua.
local function activeIn(zone, gang, now)
    local ok, last = pcall(function() return exports.noir_territories:getGangActivity(zone, gang) end)
    if not ok or type(last) ~= 'number' or last <= 0 then return false end
    return (now or os.time()) - last <= NoirIllegal.Config.TerritoryActivitySeconds
end

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
        if V.string(zone, 1, 64) and V.string(gang, 1, 64) and activeIn(zone, gang, now) then
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
