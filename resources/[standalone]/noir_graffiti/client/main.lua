local function fontOptions()
    local options = {}
    for _, font in ipairs(Config.Fonts) do options[#options + 1] = { value = font.id, label = font.label } end
    return options
end

exports('useSpraycan', function(_, slotData)
    local input = lib.inputDialog('GRAFFITI', {
        { type = 'input', label = 'Texto', required = true, min = Config.Text.minLength, max = Config.Text.maxLength },
        { type = 'select', label = 'Fonte', required = true, options = fontOptions(), default = Config.Fonts[1] and Config.Fonts[1].id },
    })
    if not input then return end
    local slot = slotData and slotData.slot
    local prepared = lib.callback.await('noir_graffiti:server:prepare', false, input[1], input[2], slot)
    if not prepared or not prepared.success then
        return lib.notify({ description = prepared and prepared.error or 'Não foi possível iniciar o graffiti.', type = 'error' })
    end
    NoirGraffiti.StartPlacement(prepared.text, prepared.font, slot, prepared.color)
end)

RegisterNetEvent('noir_graffiti:client:adminMenu', function(rows, nearbyOnly)
    local options = {}
    for _, graffiti in ipairs(rows or {}) do
        options[#options + 1] = {
            title = ('#%s — %s'):format(graffiti.id, graffiti.text),
            description = ('Gang: %s | Fonte: %s'):format(graffiti.gang or 'nenhuma', graffiti.font),
            icon = 'spray-can-sparkles',
            metadata = {
                { label = 'Autor', value = graffiti.placedBy },
                { label = 'Território', value = graffiti.territory or 'nenhum' },
                { label = 'Coordenadas', value = ('%.2f, %.2f, %.2f'):format(graffiti.coords.x, graffiti.coords.y, graffiti.coords.z) },
            },
            onSelect = function()
                lib.registerContext({ id = 'noir_graffiti_admin_actions', title = ('Graffiti #%s'):format(graffiti.id), menu = 'noir_graffiti_admin_list', options = {
                    { title = 'Teleportar', icon = 'location-arrow', onSelect = function()
                        SetEntityCoords(PlayerPedId(), graffiti.coords.x, graffiti.coords.y, graffiti.coords.z + 0.5, false, false, false, false)
                    end },
                    { title = 'Excluir', icon = 'trash', iconColor = '#c44747', onSelect = function()
                        if lib.alertDialog({ header = 'Excluir graffiti', content = 'A remoção será registrada no banco.', cancel = true, centered = true }) == 'confirm' then
                            TriggerServerEvent('noir_graffiti:server:adminRemove', graffiti.id)
                        end
                    end },
                } })
                lib.showContext('noir_graffiti_admin_actions')
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Nenhum graffiti encontrado', disabled = true } end
    lib.registerContext({ id = 'noir_graffiti_admin_list', title = nearbyOnly and 'Graffitis próximos' or 'Todos os graffitis', menu = 'noir_graffiti_admin', options = options })
    lib.showContext('noir_graffiti_admin_list')
end)

RegisterNetEvent('noir_graffiti:client:openAdmin', function()
    lib.registerContext({ id = 'noir_graffiti_admin', title = 'Administração de Graffiti', options = {
        { title = 'Graffitis próximos', description = 'Até 25 metros', icon = 'location-dot', serverEvent = 'noir_graffiti:server:adminList', args = true },
        { title = 'Listar todos', icon = 'list', serverEvent = 'noir_graffiti:server:adminList', args = false },
    } })
    lib.showContext('noir_graffiti_admin')
end)

RegisterNetEvent('noir_graffiti:client:notify', function(description, kind)
    lib.notify({ description = description, type = kind or 'inform' })
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == GetCurrentResourceName() then TriggerServerEvent('noir_graffiti:server:request') end
end)
