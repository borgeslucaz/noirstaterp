RegisterNetEvent('noir_graffiti:client:notify', function(description, kind)
    lib.notify({ description = description, type = kind or 'inform' })
end)

RegisterNetEvent('noir_graffiti:client:openAdmin', function()
    lib.registerContext({ id = 'noir_graffiti_admin', title = 'Administração de Graffiti', options = {
        { title = 'Graffitis próximos', description = 'Até 25 metros', icon = 'location-dot',
            serverEvent = 'noir_graffiti:server:adminList', args = true },
        { title = 'Listar todos', icon = 'list',
            serverEvent = 'noir_graffiti:server:adminList', args = false },
    } })
    lib.showContext('noir_graffiti_admin')
end)

RegisterNetEvent('noir_graffiti:client:adminMenu', function(rows, nearbyOnly)
    local options = {}
    for _, graffiti in ipairs(rows or {}) do
        options[#options + 1] = {
            title = ('#%s — %s'):format(graffiti.id, graffiti.text),
            description = ('Fonte: %s'):format(graffiti.font),
            icon = 'spray-can-sparkles',
            iconColor = graffiti.color,
            metadata = {
                { label = 'Autor', value = graffiti.placedBy },
                { label = 'Cor', value = graffiti.color },
                { label = 'Coordenadas', value = ('%.2f, %.2f, %.2f'):format(
                    graffiti.coords.x, graffiti.coords.y, graffiti.coords.z) },
            },
            onSelect = function()
                lib.registerContext({
                    id = 'noir_graffiti_admin_actions',
                    title = ('Graffiti #%s'):format(graffiti.id),
                    menu = 'noir_graffiti_admin_list',
                    options = {
                        { title = 'Teleportar', icon = 'location-arrow', onSelect = function()
                            SetEntityCoords(cache.ped, graffiti.coords.x, graffiti.coords.y,
                                graffiti.coords.z + 0.5, false, false, false, false)
                        end },
                        { title = 'Excluir', icon = 'trash', iconColor = '#c44747', onSelect = function()
                            local confirmed = lib.alertDialog({
                                header = 'Excluir graffiti',
                                content = 'A remoção será registrada no banco.',
                                cancel = true, centered = true,
                            })
                            if confirmed == 'confirm' then
                                TriggerServerEvent('noir_graffiti:server:adminRemove', graffiti.id)
                            end
                        end },
                    },
                })
                lib.showContext('noir_graffiti_admin_actions')
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Nenhum graffiti encontrado', disabled = true } end
    lib.registerContext({
        id = 'noir_graffiti_admin_list',
        title = nearbyOnly and 'Graffitis próximos' or 'Todos os graffitis',
        menu = 'noir_graffiti_admin',
        options = options,
    })
    lib.showContext('noir_graffiti_admin_list')
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == cache.resource then TriggerServerEvent('noir_graffiti:server:request') end
end)
