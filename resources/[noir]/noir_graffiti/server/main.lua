local cooldowns = {}
local busy = {}

local function waitForStore()
    while not NoirStore.ready do Wait(50) end
end

---Serializa as chamadas de um mesmo jogador. Sem isto, dois `place` disparados no mesmo
---tick passam os dois pelo cooldown e pela checagem de item enquanto o INSERT cede, e uma
---lata paga dois graffitis.
local function exclusive(source, handler)
    if busy[source] then return { success = false, error = 'Aguarde a ação anterior terminar.' } end
    busy[source] = true
    local ok, result = pcall(handler)
    busy[source] = nil
    if not ok then
        print(('[noir_graffiti] erro ao atender %s: %s'):format(source, result))
        return { success = false, error = 'Erro interno.' }
    end
    return result
end

lib.callback.register('noir_graffiti:server:place', function(source, request)
    return exclusive(source, function()
        waitForStore()
        local citizenId = NoirValidation.citizenId(source)
        if not citizenId then return { success = false, error = 'Jogador inválido.' } end
        if not NoirValidation.hasItem(source, Config.Items.spray, request and request.slot) then
            return { success = false, error = 'Você não possui uma lata de spray.' }
        end

        local text, textError = NoirValidation.text(request and request.text)
        if not text then return { success = false, error = textError } end
        local font, fontError = NoirValidation.font(request and request.font)
        if not font then return { success = false, error = fontError } end
        local color, colorError = NoirValidation.color(request and request.color)
        if not color then return { success = false, error = colorError } end
        local thickness, thicknessError = NoirValidation.thickness(request and request.thickness)
        if not thickness then return { success = false, error = thicknessError } end
        local placement, placementError = NoirValidation.placement(request)
        if not placement then return { success = false, error = placementError } end

        -- O cliente manda as coordenadas; a única âncora que o servidor tem é o próprio
        -- jogador. O mesmo alcance que o posicionamento respeita, com folga para latência.
        local reach = Config.Placement.maxReach + 0.5
        if not NoirValidation.nearPlayer(source, placement.coords, reach) then
            return { success = false, error = 'Você está longe demais da parede.' }
        end
        if not NoirValidation.withinHeight(source, placement.coords,
            Config.Placement.maxHeightUp + 0.5, Config.Placement.maxHeightDown + 0.5) then
            return { success = false, error = 'O graffiti está alto demais.' }
        end

        local now = os.time()
        if (cooldowns[source] or 0) > now then
            return { success = false, error = ('Aguarde %d segundos.'):format(cooldowns[source] - now) }
        end
        for _, graffiti in pairs(NoirStore.active) do
            if #(placement.coords - graffiti.coords) < Config.Placement.minimumDistance then
                return { success = false, error = 'Já existe um graffiti muito próximo.' }
            end
        end

        if not NoirValidation.consumeSpray(source, request.slot) then
            return { success = false, error = 'A lata de spray não está mais disponível.' }
        end

        local graffiti = NoirStore.insert({
            text = text, font = font, color = color, thickness = thickness,
            coords = placement.coords, normal = placement.normal,
            rotation = placement.rotation, scale = placement.scale,
            gang = NoirValidation.gang(source), placedBy = citizenId,
        })
        if not graffiti then return { success = false, error = 'Falha ao salvar no banco.' } end

        NoirTerritories.Register(graffiti)

        cooldowns[source] = now + Config.Placement.cooldownSeconds
        TriggerClientEvent('noir_graffiti:client:add', -1, graffiti)
        return { success = true }
    end)
end)

lib.callback.register('noir_graffiti:server:remove', function(source, id)
    return exclusive(source, function()
        waitForStore()
        local citizenId = NoirValidation.citizenId(source)
        if not citizenId then return { success = false, error = 'Jogador inválido.' } end
        if not NoirValidation.hasItem(source, Config.Items.remover) then
            return { success = false, error = 'Você não possui removedor.' }
        end
        id = tonumber(id)
        local graffiti = id and NoirStore.active[id]
        if not graffiti then return { success = false, error = 'Graffiti não encontrado.' } end
        if not NoirValidation.nearPlayer(source, graffiti.coords, Config.Remove.serverDistance) then
            return { success = false, error = 'Você está longe demais.' }
        end
        if not NoirStore.softDelete(id, citizenId) then
            return { success = false, error = 'Não foi possível remover.' }
        end

        NoirTerritories.Remove(id)
        TriggerClientEvent('noir_graffiti:client:remove', -1, id)
        return { success = true }
    end)
end)

---Avisa os outros de que este jogador está com a lata na mão, para o prop aparecer na tela
---deles. O evento não carrega nada além do próprio source: o cliente não escolhe o modelo,
---nem a duração, nem quem recebe. O pior uso possível é aparecer segurando um spray sem
---estar pichando, e o limite abaixo impede até de fazer isso repetidamente.
local sprayThrottle = {}

RegisterNetEvent('noir_graffiti:server:spray', function(active, color)
    local source = source
    active = active == true

    if active then
        local now = GetGameTimer()
        if (sprayThrottle[source] or 0) > now then return end
        sprayThrottle[source] = now + 1000
    end

    -- A cor vira tintura de partícula na tela dos outros, então passa pela mesma validação
    -- do graffiti. Cor recusada não impede o spray: sai na cor original do efeito.
    TriggerClientEvent('noir_graffiti:client:spray', -1, source, active,
        active and NoirValidation.color(color) or nil)
end)

RegisterNetEvent('noir_graffiti:server:request', function()
    local source = source
    waitForStore()
    TriggerClientEvent('noir_graffiti:client:setAll', source, NoirStore.list())
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
    busy[source] = nil
    sprayThrottle[source] = nil
end)

-- Administração ---------------------------------------------------------------------

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
        for _, graffiti in ipairs(rows) do
            if #(coords - graffiti.coords) <= 25.0 then nearby[#nearby + 1] = graffiti end
        end
        rows = nearby
    end
    TriggerClientEvent('noir_graffiti:client:adminMenu', source, rows, nearbyOnly == true)
end)

RegisterNetEvent('noir_graffiti:server:adminRemove', function(id)
    local source = source
    if not isAdmin(source) then return end
    local citizenId = NoirValidation.citizenId(source)
    if not citizenId then return end
    local removed = NoirStore.softDelete(id, citizenId)
    if not removed then
        return TriggerClientEvent('noir_graffiti:client:notify', source, 'Graffiti não encontrado.', 'error')
    end

    NoirTerritories.Remove(removed.id)
    TriggerClientEvent('noir_graffiti:client:remove', -1, removed.id)
    TriggerClientEvent('noir_graffiti:client:notify', source, 'Graffiti removido.', 'success')
end)
