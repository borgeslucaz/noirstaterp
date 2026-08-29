local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.AdminAce)
end

RegisterCommand('graffitiadmin', function(source)
    if not isAdmin(source) then
        return TriggerClientEvent('noir_graffiti:client:notify', source, 'Acesso negado.', 'error')
    end
    TriggerClientEvent('noir_graffiti:client:openAdmin', source)
end, false)

RegisterNetEvent('noir_graffiti:server:adminList', function(nearbyOnly)
    local source = source
    if not isAdmin(source) then return end
    local rows = NoirStore.list()
    if nearbyOnly then
        local coords, nearby = GetEntityCoords(GetPlayerPed(source)), {}
        for _, graffiti in ipairs(rows) do if #(coords - graffiti.coords) <= 25.0 then nearby[#nearby + 1] = graffiti end end
        rows = nearby
    end
    TriggerClientEvent('noir_graffiti:client:adminMenu', source, rows, nearbyOnly == true)
end)

RegisterNetEvent('noir_graffiti:server:adminRemove', function(id)
    local source = source
    if not isAdmin(source) then return end
    local player, citizenId = NoirValidation.player(source)
    if not player then return end
    local removed = NoirStore.softDelete(id, citizenId)
    if not removed then return TriggerClientEvent('noir_graffiti:client:notify', source, 'Graffiti não encontrado.', 'error') end
    TriggerClientEvent('noir_graffiti:client:remove', -1, removed.id)
    local actorGang = NoirValidation.gang(source, player)
    TriggerEvent('noir_graffiti:server:removed', {
        graffitiId = removed.id, ownerGang = removed.gang, actorGang = actorGang and actorGang.name or nil,
        territory = removed.territory, actorCitizenId = citizenId,
    })
    TriggerClientEvent('noir_graffiti:client:notify', source, 'Graffiti removido.', 'success')
end)
