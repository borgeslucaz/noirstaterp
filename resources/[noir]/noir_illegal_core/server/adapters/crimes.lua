-- Crimes que só somam heat ao personagem (shared/activities.lua, "Heat de crime").
--
-- Cada resource anuncia o fato por evento de servidor e não sabe quanto ele vale. O id da
-- transação sai do fato quando existe um (contrato, fila da bancada, placa do carro); sem ele,
-- a guarda contra repetição é a do próprio resource (vitrine aberta, carro-forte já saqueado).

local Adapters = NoirIllegal.Adapters
local V = NoirIllegal.Validators

local function isSource(value)
    return type(value) == 'number' and value > 0
end

-- Roubo de casa: heat para cada participante online no fim do contrato.
AddEventHandler('noir_houserobbery:server:robberyCompleted', function(robbery)
    if not Adapters.from('noir_houserobbery') or type(robbery) ~= 'table' then return end
    if not V.string(robbery.id, 1, 128) or type(robbery.sources) ~= 'table' then return end
    for _, source in ipairs(robbery.sources) do
        if isSource(source) then
            Adapters.record(source, 'house_robbery', V.stableUuid(('house_robbery:%s:%d'):format(robbery.id, source)), {
                metadata = { contractId = robbery.id, houseId = robbery.houseId, tier = robbery.tier },
            })
        end
    end
end)

-- Pequenos crimes: o resource manda a activity e a transação; só as duas conhecidas valem.
local PETTY = { petty_smashgrab = true, petty_parkingmeter = true }
AddEventHandler('noir_prettycrimes:server:crimeCompleted', function(source, activityKey, transactionId, metadata)
    if not Adapters.from('noir_prettycrimes') or not isSource(source) or not PETTY[activityKey] then return end
    local id = V.string(transactionId, 1, 128) and V.stableUuid(('%s:%s'):format(activityKey, transactionId)) or V.randomUuid()
    Adapters.record(source, activityKey, id, { metadata = type(metadata) == 'table' and metadata or nil })
end)

AddEventHandler('qbx_storerobbery:server:registerRobbed', function(source, register)
    if not Adapters.from('qbx_storerobbery') or not isSource(source) then return end
    Adapters.record(source, 'store_register', V.randomUuid(), { metadata = { register = tonumber(register) } })
end)

AddEventHandler('qbx_storerobbery:server:safeRobbed', function(source, safe)
    if not Adapters.from('qbx_storerobbery') or not isSource(source) then return end
    Adapters.record(source, 'store_safe', V.randomUuid(), { metadata = { safe = tonumber(safe) } })
end)

AddEventHandler('qbx_jewelery:server:vitrineRobbed', function(source, vitrine)
    if not Adapters.from('qbx_jewelery') or not isSource(source) then return end
    Adapters.record(source, 'jewelery_vitrine', V.randomUuid(), { metadata = { vitrine = tonumber(vitrine) } })
end)

-- Banco: Fleeca tem id numérico; Paleto e Pacific, nome.
AddEventHandler('qbx_bankrobbery:server:bankOpened', function(source, bankId)
    if not Adapters.from('qbx_bankrobbery') or not isSource(source) then return end
    local activityKey = bankId == 'paleto' and 'bank_paleto'
        or bankId == 'pacific' and 'bank_pacific'
        or type(bankId) == 'number' and 'bank_fleeca'
        or nil
    if not activityKey then return end
    Adapters.record(source, activityKey, V.randomUuid(), { metadata = { bankId = tostring(bankId) } })
end)

AddEventHandler('qbx_truckrobbery:server:truckLooted', function(source)
    if not Adapters.from('qbx_truckrobbery') or not isSource(source) then return end
    Adapters.record(source, 'truck_robbery', V.randomUuid(), {})
end)

-- Arrombamento: o mesmo carro (placa e net id) conta uma vez por dia, para ligação direta
-- repetida no mesmo veículo não esquentar sem fim.
AddEventHandler('mri_Qcarkeys:server:vehicleBrokenInto', function(source, kind, netId, plate)
    if not Adapters.from('mri_Qcarkeys') or not isSource(source) then return end
    if kind ~= 'hotwire' and kind ~= 'lockpick' then return end
    plate = type(plate) == 'string' and plate:gsub('%s+', '') or '?'
    local id = V.stableUuid(('vehicle_break_in:%s:%s:%s:%s'):format(kind, tostring(netId), plate, os.date('!%Y%m%d')))
    Adapters.record(source, 'vehicle_break_in', id, { metadata = { kind = kind, plate = plate } })
end)

-- Bancada: a linha da fila é apagada antes de entregar, então o id dela é único.
AddEventHandler('noir_guncraft:server:craftCollected', function(source, queueId, item)
    if not Adapters.from('noir_guncraft') or not isSource(source) then return end
    local id = tonumber(queueId) and V.stableUuid(('gun_craft:%d'):format(tonumber(queueId))) or V.randomUuid()
    Adapters.record(source, 'gun_craft', id, {
        metadata = { queueId = tonumber(queueId), item = type(item) == 'string' and item or nil },
    })
end)
