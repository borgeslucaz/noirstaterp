-- Usar o chaveiro no inventario (export do item no ox_inventory): lista as chaves para tirar uma ou
-- todas. Quem tira e confere e o servidor (server/keybag.lua).

exports('openKeybag', function(_, slot)
    local keys = slot.metadata and slot.metadata.plates or {}
    local options = {}
    for i, key in ipairs(keys) do
        options[#options + 1] = {
            title = key.label or key.plate,
            description = 'Placa ' .. key.plate,
            icon = 'key',
            onSelect = function()
                TriggerServerEvent('mri_Qcarkeys:server:takeFromKeybag', slot.slot, i, key.plate)
            end,
        }
    end
    options[#options + 1] = {
        title = 'Separar todas',
        icon = 'layer-group',
        onSelect = function()
            TriggerServerEvent('mri_Qcarkeys:server:takeFromKeybag', slot.slot, 'all')
        end,
    }
    lib.registerContext({ id = 'mri_Qcarkeys:keybag', title = 'Chaveiro', options = options })
    lib.showContext('mri_Qcarkeys:keybag')
end)
