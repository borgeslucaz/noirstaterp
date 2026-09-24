if not lib then return end

-- Slots de equipamento do jogador (corpo e roupas). Ficam numa faixa fixa de
-- numeros, fora da grade (1..inv.slots), para a grade poder crescer sem colidir
-- com eles. Cada slot so aceita os itens da sua lista.
-- Os numeros ficam salvos no inventario dos jogadores: nao renumerar.
local Equipment = {}

local phones = { 'phone', 'phone_black', 'phone_blue', 'phone_green', 'phone_orange', 'phone_pink', 'phone_purple', 'phone_red', 'phone_yellow', 'burner_phone' }
local keys = { 'vehiclekey', 'keybag' }
-- Mesmos nomes da lista de mochilas em modules/items/containers.lua.
local backpacks = { 'backpack_fashion', 'backpack_small', 'backpack_urban', 'backpack_gamer', 'backpack_medium', 'backpack_hiking', 'backpack_large', 'duffel_bag_sport', 'duffel_bag' }

local definitions = {
	{ slot = 1001, group = 'clothing', name = 'mask',     label = 'Máscara',  items = { 'clothing_mask' } },
	{ slot = 1002, group = 'clothing', name = 'hat',      label = 'Chapéu',   items = { 'clothing_hat' } },
	{ slot = 1003, group = 'clothing', name = 'glasses',  label = 'Óculos',   items = { 'clothing_glasses' } },
	{ slot = 1004, group = 'clothing', name = 'jacket',   label = 'Jaqueta',  items = { 'clothing_jacket' } },
	{ slot = 1005, group = 'clothing', name = 'pants',    label = 'Calça',    items = { 'clothing_pants' } },
	{ slot = 1006, group = 'clothing', name = 'shoes',    label = 'Sapatos',  items = { 'clothing_shoes' } },
	{ slot = 1007, group = 'clothing', name = 'bag',      label = 'Bolsa',    items = { 'clothing_bag' } },
	{ slot = 1008, group = 'clothing', name = 'vest',     label = 'Colete',   items = { 'clothing_vest' } },
	{ slot = 1009, group = 'clothing', name = 'watch',    label = 'Relógio',  items = { 'clothing_watch' } },
	{ slot = 1010, group = 'clothing', name = 'necklace', label = 'Colar',    items = { 'clothing_necklace' } },

	{ slot = 1011, group = 'body', name = 'phone',    label = 'Celular',  items = phones },
	{ slot = 1012, group = 'body', name = 'radio',    label = 'Rádio',    items = { 'radio' } },
	{ slot = 1013, group = 'body', name = 'keys',     label = 'Chaves',   items = keys },
	{ slot = 1014, group = 'body', name = 'keys',     label = 'Chaves',   items = keys },
	{ slot = 1015, group = 'body', name = 'wallet',   label = 'Carteira', items = { 'wallet' } },
	{ slot = 1016, group = 'body', name = 'backpack', label = 'Mochila',  items = backpacks },
}

---Slot da mochila equipada, cujo conteudo fica aberto ao lado do inventario.
Equipment.BACKPACK = 1016

local bySlot = {}

for i = 1, #definitions do
	local def = definitions[i]
	local accepts = {}

	for j = 1, #def.items do accepts[def.items[j]] = true end

	def.accepts = accepts
	bySlot[def.slot] = def
end

---@return table[] definitions
function Equipment.list() return definitions end

---@param slot any
---@return boolean
function Equipment.isSlot(slot) return bySlot[slot] ~= nil end

---@param slot any
---@param itemName string
---@return boolean
function Equipment.accepts(slot, itemName)
	local def = bySlot[slot]
	return def ~= nil and def.accepts[itemName] == true
end

---Primeiro slot de equipamento vazio que aceita o item.
---@param items table<number, table> inventario (inv.items)
---@param itemName string
---@return number?
function Equipment.freeSlotFor(items, itemName)
	for i = 1, #definitions do
		local def = definitions[i]

		if def.accepts[itemName] and not items[def.slot] then return def.slot end
	end
end

---Quantos slots de equipamento vazios aceitam o item.
---@param items table<number, table>
---@param itemName string
---@return number
function Equipment.freeSlotCount(items, itemName)
	local free = 0

	for i = 1, #definitions do
		local def = definitions[i]

		if def.accepts[itemName] and not items[def.slot] then free += 1 end
	end

	return free
end

---Se o slot pode guardar o item: um slot da grade ou, no inventario de um
---jogador, um slot de equipamento que aceite o item.
---@param inv { slots: number, player?: table, type?: string }
---@param slot any
---@param itemName string
---@return boolean
function Equipment.validSlot(inv, slot, itemName)
	if type(slot) ~= 'number' or slot % 1 ~= 0 then return false end
	if slot >= 1 and slot <= inv.slots then return true end

	return (inv.player ~= nil or inv.type == 'player') and Equipment.accepts(slot, itemName)
end

return Equipment
