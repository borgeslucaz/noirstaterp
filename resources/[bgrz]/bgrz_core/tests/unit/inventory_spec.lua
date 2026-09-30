local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = { inventory = 'ox_inventory' }, Limits = { maxItemAmount = 100000 } }
local state = 'started'
local calls = {}
local provider = {}

function provider:AddItem(holder, item, amount, metadata)
    calls[#calls + 1] = { 'add', holder, item, amount, metadata }
    return true, { slot = 1 }
end

function provider:RemoveItem(holder, item, amount, metadata, slot)
    calls[#calls + 1] = { 'remove', holder, item, amount, metadata, slot }
    return amount ~= 9, amount == 9 and 'not_enough_items' or nil
end

function provider:GetItemCount(holder, item, metadata)
    calls[#calls + 1] = { 'count', holder, item, metadata }
    return 7
end

function provider:CanCarryItem(holder, item, amount, metadata)
    calls[#calls + 1] = { 'carry', holder, item, amount, metadata }
    return amount < 8
end

exports = T.exports({ ox_inventory = provider })
GetResourceState = function() return state end

dofile('shared/provider.lua')
dofile('server/inventory.lua')

local metadata = { batch = 'alpha' }
local ok, err = BGRZ.AddItem(12, 'weed_brick', 2, metadata)
T.equal(ok, true, 'AddItem success')
T.equal(err, nil, 'AddItem no error')
T.equal(calls[#calls][5], metadata, 'AddItem metadata forwarded')

ok, err = BGRZ.RemoveItem('outpost:docks', 'meth', 9)
T.equal(ok, false, 'RemoveItem provider refusal')
T.equal(err, 'not_enough_items', 'RemoveItem normalized provider reason')

local count, countErr = BGRZ.GetItemCount(12, 'cokebaggy', metadata)
T.equal(count, 7, 'GetItemCount value')
T.equal(countErr, nil, 'GetItemCount no error')

local canCarry, carryErr = BGRZ.CanCarryItem(12, 'weed_brick', 8)
T.equal(canCarry, false, 'CanCarryItem capacity refusal')
T.equal(carryErr, 'cannot_carry', 'CanCarryItem reason')

ok, err = BGRZ.AddItem(12, 'weed_brick', 1.5)
T.equal(ok, false, 'fractional amount rejected')
T.equal(err, 'invalid_amount', 'fractional amount code')

local before = #calls
ok, err = BGRZ.AddItem(12, '', 1)
T.equal(ok, false, 'blank item rejected')
T.equal(err, 'invalid_item', 'blank item code')
T.equal(#calls, before, 'invalid item not forwarded')

state = 'stopped'
ok, err = BGRZ.AddItem(12, 'weed_brick', 1)
T.equal(ok, false, 'stopped inventory rejected')
T.equal(err, 'provider_unavailable', 'stopped inventory code')

state = 'started'
provider.GetItemCount = function() error('provider exploded') end
count, countErr = BGRZ.GetItemCount(12, 'weed_brick')
T.equal(count, nil, 'provider exception count')
T.equal(countErr, 'provider_unavailable', 'provider exception normalized')

-- ---------------------------------------------------------------------------
-- GetItemLabel
-- ---------------------------------------------------------------------------
state = 'started'
provider.Items = function(_, item)
    if item == 'weed_brick' then return { label = 'Tijolo de Maconha' } end
    return nil
end

local label, labelErr = BGRZ.GetItemLabel('weed_brick')
T.equal(label, 'Tijolo de Maconha', 'GetItemLabel devolve o rótulo do provider')
T.equal(labelErr, nil, 'GetItemLabel sem erro no caminho feliz')

label, labelErr = BGRZ.GetItemLabel('item_que_nao_existe')
T.equal(label, 'item_que_nao_existe', 'item desconhecido cai para o próprio nome')
T.equal(labelErr, 'unknown_item', 'item desconhecido é sinalizado')

label, labelErr = BGRZ.GetItemLabel(42)
T.equal(label, nil, 'item não-string recusado')
T.equal(labelErr, 'invalid_item', 'código de erro estável')

state = 'stopped'
label, labelErr = BGRZ.GetItemLabel('weed_brick')
T.equal(label, 'weed_brick', 'provider parado ainda devolve algo legível')
T.equal(labelErr, 'provider_unavailable', 'provider parado é sinalizado')
state = 'started'

provider.Items = function() error('provider exploded') end
label, labelErr = BGRZ.GetItemLabel('weed_brick')
T.equal(label, 'weed_brick', 'exceção do provider não sobe')
T.equal(labelErr, 'unknown_item', 'exceção vira código tratado')

-- ---------------------------------------------------------------------------
-- GetItemList
-- ---------------------------------------------------------------------------
provider.Items = function(_, item)
    if item then return nil end
    return { water = { label = 'Agua' }, bread = { label = 'Pao' }, rock = {} }
end
local list = BGRZ.GetItemList()
T.equal(#list, 3, 'GetItemList devolve todos os itens')
T.equal(list[1].name, 'water', 'GetItemList ordena por rótulo')
T.equal(list[3].label, 'rock', 'item sem label usa o nome')

state = 'stopped'
local noList, listErr = BGRZ.GetItemList()
T.equal(noList, nil, 'GetItemList sem provider')
T.equal(listErr, 'provider_unavailable', 'GetItemList sem provider sinaliza')
state = 'started'

-- ---------------------------------------------------------------------------
-- GetItemDegrade
-- ---------------------------------------------------------------------------
provider.Items = function(_, item)
    if item == 'weed_skunk_baggy' then return { label = 'Saquinho', degrade = 14400 } end
    if item == 'water' then return { label = 'Agua' } end
    if item == 'broken' then return { label = 'X', degrade = 0 / 0 } end
    return nil
end

local degrade, degradeErr = BGRZ.GetItemDegrade('weed_skunk_baggy')
T.equal(degrade, 14400, 'GetItemDegrade devolve os minutos do provider')
T.equal(degradeErr, nil, 'GetItemDegrade sem erro no caminho feliz')

degrade, degradeErr = BGRZ.GetItemDegrade('water')
T.equal(degrade, nil, 'item sem validade devolve nil')
T.equal(degradeErr, nil, 'item sem validade não é erro')

degrade, degradeErr = BGRZ.GetItemDegrade('broken')
T.equal(degrade, nil, 'validade não finita é ignorada')

degrade, degradeErr = BGRZ.GetItemDegrade('item_que_nao_existe')
T.equal(degrade, nil, 'item desconhecido sem validade')
T.equal(degradeErr, 'unknown_item', 'item desconhecido é sinalizado')

degrade, degradeErr = BGRZ.GetItemDegrade(42)
T.equal(degradeErr, 'invalid_item', 'item não-string recusado')

state = 'stopped'
degrade, degradeErr = BGRZ.GetItemDegrade('weed_skunk_baggy')
T.equal(degrade, nil, 'provider parado sem validade')
T.equal(degradeErr, 'provider_unavailable', 'provider parado é sinalizado')
state = 'started'

provider.Items = function() error('provider exploded') end
degrade, degradeErr = BGRZ.GetItemDegrade('weed_skunk_baggy')
T.equal(degradeErr, 'unknown_item', 'exceção do provider vira código tratado')

-- ---------------------------------------------------------------------------
-- Durabilidade
-- ---------------------------------------------------------------------------
local slots = {
    { slot = 3, metadata = { durability = 4 } },
    { slot = 5, metadata = { durability = 1893456000 } },
    { slot = 7, metadata = {} },
}
local durabilitySet = {}
provider.Search = function(_, holder, search, item)
    if item ~= 'pickaxe' then return false end
    return slots
end
provider.SetDurability = function(_, holder, slot, value)
    durabilitySet[#durabilitySet + 1] = { holder, slot, value }
end

T.equal(BGRZ.HasItemDurability(12, 'pickaxe', 4), true, 'slot com durabilidade exata serve')
local has, hasErr = BGRZ.HasItemDurability(12, 'shovel', 1)
T.equal(has, false, 'sem o item')
T.equal(hasErr, 'not_enough_items', 'sem o item sinaliza')

local used, usedErr, remaining = BGRZ.ConsumeItemDurability(12, 'pickaxe', 10)
T.equal(used, true, 'pula slot gasto e o de validade, usa o sem metadata')
T.equal(usedErr, nil, 'consumo sem erro')
T.equal(remaining, 90, 'slot sem durability conta como 100')
T.equal(durabilitySet[1][2], 7, 'gasta o slot certo')
T.equal(durabilitySet[1][3], 90, 'grava o que sobrou')

slots = { { slot = 3, metadata = { durability = 4 } } }
local low, lowErr = BGRZ.ConsumeItemDurability(12, 'pickaxe', 10)
T.equal(low, false, 'durabilidade insuficiente recusa')
T.equal(lowErr, 'low_durability', 'durabilidade insuficiente sinaliza')
T.equal(#durabilitySet, 1, 'recusa não grava nada')

local free = BGRZ.ConsumeItemDurability(12, 'pickaxe', 0)
T.equal(free, true, 'custo zero só confere posse')
T.equal(#durabilitySet, 1, 'custo zero não grava')

local bad, badErr = BGRZ.ConsumeItemDurability(12, 'pickaxe', 101)
T.equal(bad, false, 'custo fora da escala recusado')
T.equal(badErr, 'invalid_amount', 'custo fora da escala sinaliza')

provider.Search = function() error('provider exploded') end
local boom, boomErr = BGRZ.HasItemDurability(12, 'pickaxe', 1)
T.equal(boom, false, 'exceção do provider não sobe')
T.equal(boomErr, 'provider_unavailable', 'exceção vira código tratado')

-- Remover pelo metadata --------------------------------------------------------------------

provider.Search = function(_, holder, search, item)
    return {
        { slot = 1013, count = 1, metadata = { plate = 'CRG00001', noirHaul = true, label = 'CHAVE-CRG00001' } },
        { slot = 4, count = 1, metadata = { plate = 'ABC12345', label = 'CHAVE-ABC12345' } },
        { slot = 9, count = 1, metadata = { plate = 'CRG00002', noirHaul = true } },
    }
end
calls = {}
local removedOk, removed = BGRZ.RemoveItemsWithMetadata(12, 'vehiclekey', { noirHaul = true })
T.truthy(removedOk, 'remove pelo metadata')
T.equal(removed, 2, 'só os slots com a marca')
T.equal(calls[1][6], 1013, 'inclusive o slot de equipamento')
T.equal(calls[2][6], 9, 'e o slot comum')
T.equal(#calls, 2, 'a chave do carro próprio fica')
T.equal(select(2, BGRZ.RemoveItemsWithMetadata(12, 'vehiclekey', {})), 'invalid_metadata', 'marca vazia removeria tudo: recusada')

-- Por slot ---------------------------------------------------------------------------------

provider.Search = function(_, holder, search, item)
    return {
        { slot = 7, count = 3, metadata = { grade = 'A', durability = 1700000000 } },
        { slot = 2, count = 5, metadata = { durability = 1700003600 } },
        { slot = 5, count = 0, metadata = { grade = 'S' } },
    }
end
local slots, slotsErr = BGRZ.GetItemSlots(12, 'weed_skunk_baggy')
T.equal(slotsErr, nil, 'GetItemSlots sem erro')
T.equal(#slots, 2, 'slot vazio fica de fora')
T.equal(slots[1].slot, 2, 'ordenado pelo slot')
T.equal(slots[2].metadata.grade, 'A', 'metadata vem junto')
slots[2].metadata.grade = 'X'
T.equal(BGRZ.GetItemSlots(12, 'weed_skunk_baggy')[2].metadata.grade, 'A', 'metadata é cópia')
T.equal(select(2, BGRZ.GetItemSlots(12, '')), 'invalid_item', 'item vazio recusado')

calls = {}
local fromSlot, fromSlotErr = BGRZ.RemoveItemFromSlot(12, 'weed_skunk_baggy', 2, 7)
T.truthy(fromSlot, 'remove do slot')
T.equal(fromSlotErr, nil, 'sem erro')
T.equal(calls[1][5], nil, 'sem metadata: o slot decide')
T.equal(calls[1][6], 7, 'slot repassado')
T.equal(select(2, BGRZ.RemoveItemFromSlot(12, 'weed_skunk_baggy', 9, 7)), 'not_enough_items', 'recusa do provider normalizada')
T.equal(select(2, BGRZ.RemoveItemFromSlot(12, 'weed_skunk_baggy', 1, 1.5)), 'invalid_slot', 'slot fracionado recusado')

state = 'stopped'
T.equal(select(2, BGRZ.GetItemSlots(12, 'weed_skunk_baggy')), 'provider_unavailable', 'GetItemSlots sem provider')
T.equal(select(2, BGRZ.RemoveItemFromSlot(12, 'weed_skunk_baggy', 1, 7)), 'provider_unavailable', 'RemoveItemFromSlot sem provider')
state = 'started'

print('inventory_spec: ok')
