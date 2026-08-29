NoirGraffiti = NoirGraffiti or {}

local zones = {}

function NoirGraffiti.RemoveTarget(id)
    local zone = zones[tonumber(id)]
    if zone then exports.ox_target:removeZone(zone); zones[tonumber(id)] = nil end
end

function NoirGraffiti.AddTarget(graffiti)
    NoirGraffiti.RemoveTarget(graffiti.id)
    zones[graffiti.id] = exports.ox_target:addSphereZone({
        coords = graffiti.coords,
        radius = 0.65,
        debug = false,
        options = {{
            name = ('noir_graffiti_remove_%s'):format(graffiti.id),
            label = 'Remover Graffiti',
            icon = 'fa-solid fa-spray-can-sparkles',
            items = Config.Items.remover,
            distance = Config.Remove.targetDistance,
            onSelect = function()
                local completed = lib.progressCircle({
                    duration = Config.Remove.duration,
                    label = 'Removendo graffiti',
                    position = 'bottom',
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = { dict = 'amb@world_human_maid_clean@base', clip = 'base' },
                    prop = { model = 'v_res_fa_sponge01', bone = 57005, pos = vec3(0.1, 0.0, -0.02), rot = vec3(90.0, 0.0, 0.0) },
                })
                if not completed then return end
                local result = lib.callback.await('noir_graffiti:server:remove', false, graffiti.id)
                lib.notify({
                    description = result and result.success and 'Graffiti removido.' or ((result and result.error) or 'Não foi possível remover.'),
                    type = result and result.success and 'success' or 'error',
                })
            end,
        }},
    })
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, zone in pairs(zones) do exports.ox_target:removeZone(zone) end
    zones = {}
end)
