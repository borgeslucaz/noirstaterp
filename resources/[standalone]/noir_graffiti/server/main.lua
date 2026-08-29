local cooldowns = {}

local function waitForStore()
    while not NoirStore.ready do Wait(50) end
end

local function colorForGang(gangName)
    local color = gangName and Config.GangColors[gangName] or Config.DefaultColor
    if type(color) ~= 'string' or not color:match('^#%x%x%x%x%x%x$') then return '#FFFFFF' end
    return color:upper()
end

local function closeToPlayer(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    return ped and ped > 0 and #(GetEntityCoords(ped) - coords) <= maxDistance
end

lib.callback.register('noir_graffiti:server:prepare', function(source, rawText, rawFont, slot)
    local player = NoirValidation.player(source)
    if not player then return { success = false, error = 'Jogador inválido.' } end
    if not NoirValidation.hasItem(source, Config.Items.spray, slot) then return { success = false, error = 'Você não possui uma lata de spray válida.' } end
    local gang = NoirValidation.gang(source, player)
    if Config.RequireGang and not gang then return { success = false, error = 'Você não pertence a uma gang.' } end
    local text, textError = NoirValidation.text(rawText)
    if not text then return { success = false, error = textError } end
    local font, fontError = NoirValidation.font(rawFont)
    if not font then return { success = false, error = fontError } end
    return { success = true, text = text, font = font, color = colorForGang(gang and gang.name or nil) }
end)

lib.callback.register('noir_graffiti:server:place', function(source, request)
    waitForStore()
    local player, citizenId = NoirValidation.player(source)
    if not player then return { success = false, error = 'Jogador inválido.' } end
    local hasSpray = NoirValidation.hasItem(source, Config.Items.spray, request and request.slot)
    if not hasSpray then return { success = false, error = 'Você não possui uma lata de spray válida.' } end

    local gang = NoirValidation.gang(source, player)
    if Config.RequireGang and not gang then return { success = false, error = 'Você não pertence a uma gang.' } end
    local text, textError = NoirValidation.text(request and request.text)
    if not text then return { success = false, error = textError } end
    local font, fontError = NoirValidation.font(request and request.font)
    if not font then return { success = false, error = fontError } end
    local placement, placementError = NoirValidation.placement(request)
    if not placement then return { success = false, error = placementError } end
    if not closeToPlayer(source, placement.coords, Config.Placement.maxDistance + 0.5) then return { success = false, error = 'Você está longe demais da parede.' } end

    local now = os.time()
    if (cooldowns[source] or 0) > now then
        return { success = false, error = ('Aguarde %d segundos.'):format(cooldowns[source] - now) }
    end
    for _, graffiti in pairs(NoirStore.active) do
        if #(placement.coords - graffiti.coords) < Config.Placement.minimumGraffitiDistance then
            return { success = false, error = 'Já existe um graffiti muito próximo.' }
        end
    end

    local gangName = gang and gang.name or nil
    local graffiti = NoirStore.insert({
        text = text, font = font, color = colorForGang(gangName), gang = gangName,
        coords = placement.coords, normal = placement.normal, scale = placement.scale, rotation = placement.rotation,
        territory = NoirValidation.territory(placement.coords), placedBy = citizenId,
    })
    if not graffiti then return { success = false, error = 'Falha ao salvar no banco.' } end

    if not NoirValidation.consumeSpray(source, request.slot) then
        NoirStore.softDelete(graffiti.id, citizenId)
        return { success = false, error = 'A lata de spray não está mais disponível.' }
    end

    cooldowns[source] = now + Config.Placement.cooldownSeconds
    TriggerClientEvent('noir_graffiti:client:add', -1, graffiti)
    TriggerEvent('noir_graffiti:server:placed', {
        graffitiId = graffiti.id, gang = gangName, territory = graffiti.territory,
        text = text, font = font, actorCitizenId = citizenId,
    })
    return { success = true, id = graffiti.id }
end)

lib.callback.register('noir_graffiti:server:remove', function(source, id)
    waitForStore()
    local player, citizenId = NoirValidation.player(source)
    if not player then return { success = false, error = 'Jogador inválido.' } end
    if not NoirValidation.hasItem(source, Config.Items.remover) then return { success = false, error = 'Você não possui removedor.' } end
    id = tonumber(id)
    local graffiti = id and NoirStore.active[id]
    if not graffiti then return { success = false, error = 'Graffiti não encontrado.' } end
    if not closeToPlayer(source, graffiti.coords, Config.Remove.serverDistance) then return { success = false, error = 'Você está longe demais.' } end

    local actorGang = NoirValidation.gang(source, player)
    local removed = NoirStore.softDelete(id, citizenId)
    if not removed then return { success = false, error = 'Não foi possível remover.' } end
    TriggerClientEvent('noir_graffiti:client:remove', -1, id)
    TriggerEvent('noir_graffiti:server:removed', {
        graffitiId = id, ownerGang = removed.gang, actorGang = actorGang and actorGang.name or nil,
        territory = removed.territory, actorCitizenId = citizenId,
    })
    return { success = true }
end)

RegisterNetEvent('noir_graffiti:server:request', function()
    local source = source
    waitForStore()
    TriggerClientEvent('noir_graffiti:client:setAll', source, NoirStore.list())
end)

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)
