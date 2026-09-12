if not lib then return end

-- Dedicated equipment slots for the dynamic clothingmenu items.  These slots are
-- intentionally separate from the normal player inventory and are never used by
-- automatic item placement.
local Clothing = {}

local definitions = {
    { name = 'mask',     label = 'Máscara',  item = 'clothing_mask',     side = 'left' },
    { name = 'hat',      label = 'Chapéu',   item = 'clothing_hat',      side = 'left' },
    { name = 'glasses',  label = 'Óculos',   item = 'clothing_glasses',  side = 'left' },
    { name = 'jacket',   label = 'Jaqueta',  item = 'clothing_jacket',   side = 'left' },
    { name = 'pants',    label = 'Calça',    item = 'clothing_pants',    side = 'left' },
    { name = 'shoes',    label = 'Sapatos',  item = 'clothing_shoes',    side = 'right' },
    { name = 'bag',      label = 'Mochila',  item = 'clothing_bag',      side = 'right' },
    { name = 'vest',     label = 'Colete',   item = 'clothing_vest',     side = 'right' },
    { name = 'watch',    label = 'Relógio',  item = 'clothing_watch',    side = 'right' },
    { name = 'necklace', label = 'Colar',    item = 'clothing_necklace', side = 'right' },
}

local byItem = {}
for index = 1, #definitions do byItem[definitions[index].item] = index end

function Clothing.getSlots() return definitions end
function Clothing.getCount() return #definitions end
function Clothing.getStart() return shared.playerslots + 1 end
function Clothing.getPlayerSlots() return shared.playerslots + #definitions end
function Clothing.isEquipmentSlot(inv, slot)
    return inv and inv.type == 'player' and type(slot) == 'number' and slot >= Clothing.getStart() and slot <= Clothing.getPlayerSlots()
end
function Clothing.canEquip(inv, slot, item)
    if not Clothing.isEquipmentSlot(inv, slot) then return false end
    local definition = definitions[slot - Clothing.getStart() + 1]
    return definition ~= nil and type(item) == 'table' and item.name == definition.item
end
function Clothing.isAllowedItem(item)
    return type(item) == 'table' and byItem[item.name] ~= nil
end

return Clothing
