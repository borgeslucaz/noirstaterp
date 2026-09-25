-- Chaveiro pelo inventario: chave em cima de chave vira chaveiro, chave em cima do chaveiro entra
-- nele, chaveiro em cima de chaveiro junta. Usar o chaveiro (client/keybag.lua) tira uma ou todas.
-- As chaves ficam em metadata.plates, no formato que HasKeyItem e o cliente ja leem.
if Shared.Inventory ~= 'ox' then return end

local ox = exports.ox_inventory
local MAX_KEYS = Shared.keybag.maxKeys
local KEY_ITEMS = { vehiclekey = true, keybag = true }

local function Notify(src, description)
    TriggerClientEvent('ox_lib:notify', src, { description = description, type = 'error' })
end

---Chaves de um slot (chave solta ou chaveiro), no formato da entrada do chaveiro.
---@param item table
---@return table[]
local function KeysOf(item)
    local metadata = item.metadata or {}
    if item.name == 'vehiclekey' then
        if not metadata.plate then return {} end
        return { { plate = metadata.plate, label = metadata.label, gen = metadata.gen } }
    end
    local keys = {}
    for _, v in ipairs(metadata.plates or {}) do
        if v.plate then keys[#keys + 1] = { plate = v.plate, label = v.label, gen = v.gen } end
    end
    return keys
end

local function KeyMetadata(entry)
    return { label = entry.label or ('CHAVE-' .. entry.plate), plate = entry.plate, gen = entry.gen }
end

local function BagMetadata(keys)
    local plates = {}
    for i = 1, #keys do plates[i] = keys[i].plate end
    return { plates = keys, platestxt = table.concat(plates, ', ') }
end

---Junta o slot `fromSlot` no `toSlot`. Roda fora do hook, com os slots relidos.
local function Merge(src, fromSlot, toSlot)
    local from, to = ox:GetSlot(src, fromSlot), ox:GetSlot(src, toSlot)
    if not from or not to or not KEY_ITEMS[from.name] or not KEY_ITEMS[to.name] then return end

    local keys = KeysOf(to)
    for _, key in ipairs(KeysOf(from)) do keys[#keys + 1] = key end
    if #keys > MAX_KEYS then
        return Notify(src, ('O chaveiro comporta no máximo %d chaves'):format(MAX_KEYS))
    end

    if not ox:RemoveItem(src, from.name, 1, nil, fromSlot) then return end
    if to.name == 'keybag' then
        ox:SetMetadata(src, toSlot, BagMetadata(keys))
        return
    end

    -- Duas chaves soltas: a de baixo vira o chaveiro, no mesmo slot. Falhou, devolve o que saiu.
    if not ox:RemoveItem(src, 'vehiclekey', 1, nil, toSlot) then
        ox:AddItem(src, from.name, 1, from.metadata, fromSlot)
        return
    end
    if not ox:AddItem(src, 'keybag', 1, BagMetadata(keys), toSlot) then
        ox:AddItem(src, from.name, 1, from.metadata, fromSlot)
        ox:AddItem(src, 'vehiclekey', 1, to.metadata, toSlot)
    end
end

-- Soltar chave/chaveiro em cima de chave/chaveiro no proprio inventario: cancela a troca de lugar
-- e junta. Entre inventarios diferentes (bau, porta-malas, outro jogador) segue a troca normal.
ox:registerHook('swapItems', function(payload)
    if payload.action ~= 'swap' then return end
    local src = payload.source
    if payload.fromInventory ~= src or payload.toInventory ~= src then return end
    local from, to = payload.fromSlot, payload.toSlot
    if type(from) ~= 'table' or type(to) ~= 'table' then return end
    if not KEY_ITEMS[from.name] or not KEY_ITEMS[to.name] then return end

    local fromSlot, toSlot = from.slot, to.slot
    SetTimeout(0, function() Merge(src, fromSlot, toSlot) end)
    return false
end, { itemFilter = KEY_ITEMS })

---Tira do chaveiro a chave `index` (conferida pela placa, o menu pode estar velho) ou todas
---(`index = 'all'`). Com 0 ou 1 chave restante o chaveiro some e a ultima volta solta no lugar dele.
RegisterNetEvent('mri_Qcarkeys:server:takeFromKeybag', function(slot, index, plate)
    local src = source
    if type(slot) ~= 'number' then return end
    if index ~= 'all' and (type(index) ~= 'number' or type(plate) ~= 'string') then return end

    local bag = ox:GetSlot(src, slot)
    if not bag or bag.name ~= 'keybag' then return end
    local keys = KeysOf(bag)
    if index ~= 'all' and (not keys[index] or keys[index].plate ~= plate) then return end

    local taking, remaining = {}, {}
    for i, key in ipairs(keys) do
        local list = (index == 'all' or i == index) and taking or remaining
        list[#list + 1] = key
    end

    if #remaining >= 2 then
        if not ox:CanCarryItem(src, 'vehiclekey', #taking) then
            return Notify(src, 'Sem espaço para a chave')
        end
        ox:SetMetadata(src, slot, BagMetadata(remaining))
        for _, key in ipairs(taking) do ox:AddItem(src, 'vehiclekey', 1, KeyMetadata(key)) end
        return
    end

    -- O chaveiro sai: todas as chaves voltam soltas, a primeira no slot dele.
    for _, key in ipairs(remaining) do taking[#taking + 1] = key end
    if #taking > 1 and not ox:CanCarryItem(src, 'vehiclekey', #taking - 1) then
        return Notify(src, 'Sem espaço para as chaves')
    end
    if not ox:RemoveItem(src, 'keybag', 1, nil, slot) then return end
    for i, key in ipairs(taking) do
        ox:AddItem(src, 'vehiclekey', 1, KeyMetadata(key), i == 1 and slot or nil)
    end
end)
