---Editor in-game (/editoronibus). A NUI monta o rascunho; aqui ficam os modos que mexem no
---mundo (marcar onde o ônibus encosta, desenhar a área de espera, posicionar o atendente e
---a vaga do ônibus, testar passageiros, ir até uma parada). O servidor valida tudo o que for
---salvo.
---
---Sem gizmo: no Enhanced o object_gizmo desenha as alças mas não pega o clique (DESIGN v4
---§ML.7). A área é desenhada pela mira da câmera.

local Config = require 'config.shared'
local Integrations = require 'client.integrations'
local Placement = require 'client.placement'

---@param Bus table contexto do client/main.lua
return function(Bus)
    -- showWorld: desenha paradas e áreas por perto; showAlways: continua com o editor fechado.
    local editor = { open = false, busy = false, catalog = nil, draft = nil, routeBlips = {}, showWorld = true, showAlways = false }
    Bus.editorOpen = false

    local SERVER_METHODS = {
        data = true, saveStop = true, deleteStop = true, saveRoute = true, deleteRoute = true,
        saveVehicle = true, deleteVehicle = true, saveLevels = true, saveSettings = true,
    }

    local function send(data)
        Bus.send('editor', data)
    end

    local function clearRouteBlips()
        for _, blip in ipairs(editor.routeBlips) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
        editor.routeBlips = {}
    end

    local function close()
        if not editor.open then return end
        editor.open, editor.busy, editor.draft = false, false, nil
        Bus.editorOpen = false
        clearRouteBlips()
        Bus.clearWaitingPassengers()
        Integrations.hideKeys()
        send({ visible = false })
        SetNuiFocus(false, false)
    end

    ---A tela some enquanto o admin anda, mira ou dirige; volta com o resultado.
    local function hideForMode()
        editor.busy = true
        send({ hidden = true })
        SetNuiFocus(false, false)
    end

    local function showAfterMode(result)
        Integrations.hideKeys()
        editor.busy = false
        if not editor.open then return end
        send({ hidden = false, result = result })
        SetNuiFocus(true, true)
    end

    -- Desenho no mundo --------------------------------------------------------------------

    local function zoneCorners(zone)
        local angle = math.rad(zone.rotation)
        local fx, fy = -math.sin(angle), math.cos(angle)
        local rx, ry = math.cos(angle), math.sin(angle)
        local hl, hw = zone.length / 2, zone.width / 2
        local corners = {}
        for index, sign in ipairs({ { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }) do
            corners[index] = vec2(zone.x + fx * hl * sign[1] + rx * hw * sign[2], zone.y + fy * hl * sign[1] + ry * hw * sign[2])
        end
        return corners
    end

    ---Caixa em arame (base, topo e colunas) com o chão translúcido, como a prévia do
    ---ZoneBuilder do ShadowForge.
    local function drawZone(zone, r, g, b)
        local corners = zoneCorners(zone)
        local bottom, top = zone.z - zone.height / 2, zone.z + zone.height / 2
        local floor = bottom + 0.05
        DrawPoly(corners[1].x, corners[1].y, floor, corners[2].x, corners[2].y, floor, corners[3].x, corners[3].y, floor, r, g, b, 70)
        DrawPoly(corners[3].x, corners[3].y, floor, corners[2].x, corners[2].y, floor, corners[1].x, corners[1].y, floor, r, g, b, 70)
        DrawPoly(corners[1].x, corners[1].y, floor, corners[3].x, corners[3].y, floor, corners[4].x, corners[4].y, floor, r, g, b, 70)
        DrawPoly(corners[4].x, corners[4].y, floor, corners[3].x, corners[3].y, floor, corners[1].x, corners[1].y, floor, r, g, b, 70)
        for index = 1, 4 do
            local a, c = corners[index], corners[index % 4 + 1]
            DrawLine(a.x, a.y, bottom, c.x, c.y, bottom, r, g, b, 220)
            DrawLine(a.x, a.y, top, c.x, c.y, top, r, g, b, 220)
            DrawLine(a.x, a.y, bottom, a.x, a.y, top, r, g, b, 160)
        end
    end

    ---Onde o ônibus encosta: cilindro no chão e seta no sentido da via.
    local function drawDock(dock, r, g, b)
        DrawMarker(1, dock.x, dock.y, dock.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.4, r, g, b, 120, false, false, 2, false, nil, nil, false)
        local angle = math.rad(dock.w)
        local ax, ay = dock.x - math.sin(angle) * 3.0, dock.y + math.cos(angle) * 3.0
        DrawLine(dock.x, dock.y, dock.z - 0.4, ax, ay, dock.z - 0.4, r, g, b, 255)
        DrawMarker(26, ax, ay, dock.z - 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, dock.w, 0.8, 0.8, 0.8, r, g, b, 200, false, false, 2, false, nil, nil, false)
    end

    ---Enquanto o editor está aberto: paradas por perto em cinza, a do rascunho em destaque.
    local function drawNearby(skipDraft)
        local coords = GetEntityCoords(cache.ped)
        local limit = Config.editor.drawDistance
        local draft = editor.open and editor.draft or nil
        for _, stop in ipairs(editor.showWorld and editor.catalog and editor.catalog.stops or {}) do
            if not (draft and draft.id == stop.id) and #(coords - vec3(stop.dock.x, stop.dock.y, stop.dock.z)) <= limit then
                drawDock(stop.dock, 170, 170, 170)
                if stop.zone then drawZone(stop.zone, 150, 150, 150) end
            end
        end
        if draft and not skipDraft then
            if draft.dock then drawDock(draft.dock, 57, 223, 69) end
            if draft.zone then drawZone(draft.zone, 110, 159, 189) end
        end
    end

    CreateThread(function()
        while true do
            if (editor.open and not editor.busy) or (not editor.open and editor.showAlways and editor.showWorld and editor.catalog) then
                drawNearby(false)
                Wait(0)
            else
                Wait(500)
            end
        end
    end)

    -- Modos -------------------------------------------------------------------------------

    ---Onde o ônibus encosta: o admin para o ônibus (ou qualquer veículo) no lugar certo e
    ---aperta E; vale a posição e o heading do veículo, ou do próprio ped a pé.
    local function captureDock()
        hideForMode()
        Integrations.showKeys({
            { key = 'E', label = locale('editor.key_capture_dock') },
            { key = 'Backspace', label = locale('editor.key_cancel') },
        })
        local result = nil
        while editor.open do
            drawNearby(false)
            DisableControlAction(0, 177, true)
            if IsControlJustReleased(0, 38) then
                local entity = cache.vehicle or cache.ped
                local c = GetEntityCoords(entity)
                result = { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(entity) }
                break
            end
            if IsDisabledControlJustReleased(0, 177) then break end
            Wait(0)
        end
        showAfterMode(result and { kind = 'dock', value = result } or { kind = 'cancel' })
    end

    ---Área de espera: E marca a 1ª ponta da calçada, E marca a 2ª; a roda ajusta a largura
    ---(Shift = mais rápido) e Enter confirma. Backspace volta um passo.
    local function drawZoneMode()
        hideForMode()
        local width, height = Config.editor.zoneWidth, Config.editor.zoneHeight
        local first, aim = nil, nil
        local placing, result = true, nil

        CreateThread(function()
            while placing do
                local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, Config.editor.reach)
                if hit and placing then aim = coords end
            end
        end)

        local function keys()
            Integrations.showKeys(first and {
                { key = 'E', label = locale('editor.key_zone_second') },
                { key = 'Roda', label = locale('editor.key_zone_width') },
                { key = 'Enter', label = locale('editor.key_confirm') },
                { key = 'Backspace', label = locale('editor.key_back') },
            } or {
                { key = 'E', label = locale('editor.key_zone_first') },
                { key = 'Backspace', label = locale('editor.key_cancel') },
            })
        end
        keys()

        local function zoneFrom(a, b)
            local dx, dy = b.x - a.x, b.y - a.y
            local length = math.max(0.5, math.sqrt(dx * dx + dy * dy))
            local ground = math.min(a.z, b.z)
            return {
                x = (a.x + b.x) / 2, y = (a.y + b.y) / 2, z = ground - 0.5 + height / 2,
                length = length, width = width, height = height,
                rotation = GetHeadingFromVector_2d(dx, dy),
            }
        end

        local second = nil
        while placing and editor.open do
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 177, true)
            DisablePlayerFiring(cache.playerId, true)
            drawNearby(true)
            if editor.draft and editor.draft.dock then drawDock(editor.draft.dock, 57, 223, 69) end

            local step = IsControlPressed(0, 21) and 1.0 or 0.25
            if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
                width = math.max(0.5, width - step)
            elseif IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
                width = math.min(40.0, width + step)
            end

            if aim then DrawMarker(28, aim.x, aim.y, aim.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 255, 255, 255, 200, false, false, 2, false, nil, nil, false) end
            local target = second or aim
            if first and target then drawZone(zoneFrom(first, target), 110, 159, 189) end

            if IsControlJustReleased(0, 38) and aim then
                if not first then
                    first = aim
                    keys()
                else
                    second = aim
                end
            elseif (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201)) and first and target then
                result = zoneFrom(first, target)
                placing = false
            elseif IsDisabledControlJustReleased(0, 177) then
                if second then
                    second = nil
                elseif first then
                    first = nil
                    keys()
                else
                    placing = false
                end
            end
            Wait(0)
        end
        placing = false
        showAfterMode(result and { kind = 'zone', value = result } or { kind = 'cancel' })
    end

    local function placeEntity(kind, model, current, resultKind)
        hideForMode()
        local point = Placement.run(kind, model, current)
        showAfterMode(point and { kind = resultKind, value = point } or { kind = 'cancel' })
    end

    -- NUI ---------------------------------------------------------------------------------

    local function open()
        if editor.open or Bus.hasRoute() then
            if Bus.hasRoute() then Integrations.notify(locale('editor.busy_route'), 'error') end
            return
        end
        local response = lib.callback.await('noir_busjob:server:editor:data', false)
        if not response or not response.ok then
            Integrations.notify(locale('editor.open_failed'), 'error')
            return
        end
        editor.open, editor.catalog = true, response.catalog
        Bus.editorOpen = true
        send({ visible = true, catalog = response.catalog, show = { world = editor.showWorld, always = editor.showAlways } })
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end

    RegisterNetEvent('noir_busjob:client:openEditor', function()
        if source ~= 65535 then return end
        open()
    end)

    Bus.onUiReady = function()
        if editor.open and editor.catalog then send({ visible = true, catalog = editor.catalog, hidden = editor.busy }) end
    end

    RegisterNUICallback('editor:close', function(_, cb)
        cb({ ok = true })
        close()
    end)

    ---Chamada ao servidor por nome, com lista fechada de métodos.
    RegisterNUICallback('editor:request', function(data, cb)
        if not editor.open or type(data) ~= 'table' or not SERVER_METHODS[data.method] then
            return cb({ ok = false, code = 'invalid_payload' })
        end
        local args = type(data.args) == 'table' and data.args or {}
        local response = lib.callback.await('noir_busjob:server:editor:' .. data.method, false, table.unpack(args, 1, 3))
        if response and response.ok and response.catalog then editor.catalog = response.catalog end
        cb(response or { ok = false, code = 'internal_error' })
    end)

    ---Rascunho aberto na tela (a parada em edição), para desenhar no mundo.
    RegisterNUICallback('editor:draft', function(data, cb)
        cb({ ok = true })
        editor.draft = type(data) == 'table' and data or nil
    end)

    RegisterNUICallback('editor:mode', function(data, cb)
        if not editor.open or editor.busy or type(data) ~= 'table' then return cb({ ok = false, code = 'busy' }) end
        cb({ ok = true })
        if data.mode == 'dock' then
            CreateThread(captureDock)
        elseif data.mode == 'zone' then
            CreateThread(drawZoneMode)
        elseif data.mode == 'depotPed' and type(data.model) == 'string' then
            CreateThread(function() placeEntity('ped', data.model, data.current, 'depotPed') end)
        elseif data.mode == 'depotSpawn' and type(data.model) == 'string' then
            CreateThread(function() placeEntity('vehicle', data.model, data.current, 'depotSpawn') end)
        else
            showAfterMode({ kind = 'cancel' })
        end
    end)

    ---Passageiros de teste na área do rascunho. Ficam até fechar o editor ou limpar.
    RegisterNUICallback('editor:testPassengers', function(data, cb)
        if not editor.open or type(data) ~= 'table' or type(data.dock) ~= 'table' then return cb({ ok = false }) end
        local count = math.max(1, math.min(8, math.floor(tonumber(data.count) or 4)))
        Bus.spawnWaitingPassengers(count, { dock = data.dock, zone = data.zone })
        cb({ ok = true, count = count })
    end)

    RegisterNUICallback('editor:clearPassengers', function(_, cb)
        Bus.clearWaitingPassengers()
        cb({ ok = true })
    end)

    RegisterNUICallback('editor:teleport', function(data, cb)
        if not editor.open or type(data) ~= 'table' then return cb({ ok = false }) end
        local response = lib.callback.await('noir_busjob:server:editor:teleport', false, data.kind, data.id, data.point)
        if not response or not response.ok then return cb(response or { ok = false }) end
        local point = response.point
        local entity = cache.vehicle or cache.ped
        SetEntityCoords(entity, point.x, point.y, point.z, false, false, false, false)
        SetEntityHeading(entity, point.w or 0.0)
        cb({ ok = true })
    end)

    ---Modelo existe no build? Devolve os assentos de passageiro para sugerir a capacidade.
    RegisterNUICallback('editor:checkModel', function(data, cb)
        if type(data) ~= 'table' or type(data.model) ~= 'string' or #data.model > 32 then return cb({ ok = false }) end
        local hash = joaat(data.model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return cb({ ok = false, code = 'invalid_model' }) end
        cb({ ok = true, seats = math.max(0, GetVehicleModelNumberOfSeats(hash) - 1) })
    end)

    ---Linha no mapa: um blip numerado por parada.
    RegisterNUICallback('editor:showRoute', function(data, cb)
        clearRouteBlips()
        if type(data) == 'table' and type(data.stops) == 'table' then
            local byId = {}
            for _, stop in ipairs(editor.catalog and editor.catalog.stops or {}) do byId[stop.id] = stop end
            for index, id in ipairs(data.stops) do
                local stop = byId[id]
                if stop then
                    local blip = AddBlipForCoord(stop.dock.x, stop.dock.y, stop.dock.z)
                    ShowNumberOnBlip(blip, index)
                    SetBlipColour(blip, 3)
                    SetBlipScale(blip, 0.8)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentSubstringPlayerName(('%d · %s'):format(index, stop.name))
                    EndTextCommandSetBlipName(blip)
                    editor.routeBlips[#editor.routeBlips + 1] = blip
                end
            end
        end
        cb({ ok = true, count = #editor.routeBlips })
    end)

    ---Centro da área como no ZoneBuilder: na posição do jogador ou onde a câmera mira. Volta
    ---o ponto do chão.
    RegisterNUICallback('editor:zoneCenter', function(data, cb)
        if not editor.open or type(data) ~= 'table' then return cb({ ok = false }) end
        if data.source == 'aim' then
            local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, Config.editor.reach)
            if not hit then return cb({ ok = false, code = 'no_hit' }) end
            return cb({ ok = true, x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(cache.ped) })
        end
        local c = GetEntityCoords(cache.ped)
        local found, ground = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
        cb({ ok = true, x = c.x, y = c.y, z = found and ground or c.z - 1.0, heading = GetEntityHeading(cache.ped) })
    end)

    RegisterNUICallback('editor:show', function(data, cb)
        if type(data) == 'table' then
            if data.world ~= nil then editor.showWorld = data.world == true end
            if data.always ~= nil then editor.showAlways = data.always == true end
        end
        cb({ ok = true, world = editor.showWorld, always = editor.showAlways })
    end)

    RegisterNUICallback('editor:position', function(_, cb)
        local entity = cache.vehicle or cache.ped
        local c = GetEntityCoords(entity)
        cb({ x = c.x, y = c.y, z = c.z, w = GetEntityHeading(entity) })
    end)

    -- Mapa de debug ---------------------------------------------------------------------

    local mapOpen, mapFromEditor = false, false

    ---@param extra? { roads?: table<string, table[]>, select?: string }
    local function openMap(data, fromEditor, extra)
        local map = Integrations.territoryMap()
        if not map then
            Integrations.notify(locale('editor.map_unavailable'), 'error')
            return false
        end
        local coords = GetEntityCoords(cache.ped)
        mapOpen, mapFromEditor = true, fromEditor == true
        Bus.send('busMap', {
            visible = true, data = data, map = map, player = { x = coords.x, y = coords.y }, fromEditor = mapFromEditor,
            roads = extra and extra.roads or nil, select = extra and extra.select or nil,
        })
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        return true
    end

    local function closeMap()
        if not mapOpen then return end
        mapOpen = false
        Bus.send('busMap', { visible = false })
        -- Aberto pelo editor, o foco continua com ele.
        if not (mapFromEditor and editor.open) then SetNuiFocus(false, false) end
    end

    RegisterNetEvent('noir_busjob:client:openMap', function(data)
        if source ~= 65535 or mapOpen or editor.open or type(data) ~= 'table' then return end
        openMap(data, false)
    end)

    RegisterNUICallback('editor:openMap', function(_, cb)
        if not editor.open or mapOpen then return cb({ ok = false }) end
        local response = lib.callback.await('noir_busjob:server:editor:mapData', false)
        if not response or not response.ok then return cb(response or { ok = false }) end
        cb({ ok = openMap(response.map, true) })
    end)

    -- Teste do traçado pela estrada (/onibusrota) -----------------------------------------
    --
    -- Rota de GPS multiponto com as paradas na ordem, amostrada a cada STEP metros com
    -- GET_POS_ALONG_GPS_TYPE_ROUTE. Ainda não se sabe se o native responde no Enhanced; por isso
    -- o F8 recebe tudo: qual combinação de parâmetros devolveu ponto, quantos pontos, o
    -- comprimento e o quanto o fim do traçado ficou longe da Central.

    -- STEP é o passo do parâmetro de distância do native (não é metro: 200 caiu a 300–560 m).
    -- SNAP: começo e fim do trecho precisam ficar a até isto das paradas.
    local TRACE_STEP, TRACE_MAX, TRACE_SNAP = 25.0, 80000.0, 150.0
    -- Espera depois de cada teleporte, para a malha de ruas e a colisão carregarem.
    local TRACE_LOAD_MS = 1200
    local tracing = false

    local function traceLog(fmt, ...)
        lib.print.info(('[onibusrota] ' .. fmt):format(...))
    end

    local function isZero(pos)
        return not pos or (math.abs(pos.x) < 0.01 and math.abs(pos.y) < 0.01 and math.abs(pos.z) < 0.01)
    end

    local function planarGap(pos, point)
        local dx, dy = pos.x - point.x, pos.y - point.y
        return math.sqrt(dx * dx + dy * dy)
    end

    ---Qual combinação (p1, tipo) usar. No Enhanced o tipo 1 responde; a distância 0 do p1 = true
    ---cai na posição do JOGADOR, não no primeiro ponto. Prefere a combinação que começa perto da
    ---saída do trecho; se nenhuma começar, usa a que responde e o trecho é cortado depois.
    local function probe(from)
        local fallback = nil
        for _, routeType in ipairs({ 1, 2, 0 }) do
            for _, flag in ipairs({ false, true }) do
                local ok, pos = GetPosAlongGpsTypeRoute(flag, 0.0, routeType)
                if ok and not isZero(pos) then
                    local gap = planarGap(pos, from)
                    traceLog('sonda tipo=%d p1=%s -> começa a %.0f m da saída (%.0f m de você)', routeType, tostring(flag), gap, planarGap(pos, GetEntityCoords(cache.ped)))
                    if gap <= TRACE_SNAP then return { flag = flag, type = routeType, fromPlayer = false } end
                    fallback = fallback or { flag = flag, type = routeType, fromPlayer = true }
                end
            end
        end
        return fallback
    end

    ---Amostra a rota inteira que o GPS tem agora.
    local function sampleRoute(combo)
        local samples, last, still, distance = {}, nil, 0, 0.0
        while distance <= TRACE_MAX do
            local ok, pos = GetPosAlongGpsTypeRoute(combo.flag, distance, combo.type)
            if not ok or isZero(pos) then break end
            -- Passou do fim: o native repete o último ponto.
            if last and #(pos - last) < 0.5 then
                still = still + 1
                if still >= 3 then break end
            else
                still = 0
                samples[#samples + 1] = { x = pos.x, y = pos.y }
            end
            last = pos
            distance = distance + TRACE_STEP
        end
        return samples
    end

    ---Um trecho (de um ponto ao seguinte) pelo GPS. Rota longa demais é cortada pelo jogo;
    ---trecho por trecho fica longe desse limite.
    ---@return table[] samples
    ---@return number gap distância do fim do trecho até o ponto de chegada
    ---@return string? problem
    local function traceLeg(from, to, combo)
        ClearGpsMultiRoute()
        Wait(0)
        StartGpsMultiRoute(6, false, true)
        AddPointToGpsMultiRoute(from.x, from.y, from.z)
        AddPointToGpsMultiRoute(to.x, to.y, to.z)
        SetGpsMultiRouteRender(true)

        -- O GPS recalcula de forma assíncrona e, até terminar, devolve a rota ANTERIOR. A rota
        -- deste trecho está pronta quando termina perto da chegada (até 5 s).
        local deadline = GetGameTimer() + 5000
        local samples, gap = {}, -1
        repeat
            Wait(150)
            if not combo.type then
                local found = probe(from)
                if found then combo.flag, combo.type, combo.fromPlayer = found.flag, found.type, found.fromPlayer end
            end
            if combo.type then
                samples = sampleRoute(combo)
                gap = #samples > 0 and planarGap(samples[#samples], to) or -1
            end
        until (gap >= 0 and gap <= TRACE_SNAP) or GetGameTimer() > deadline
        if gap < 0 then return {}, -1, 'gps_sem_resposta' end
        if gap > TRACE_SNAP then return {}, gap, 'fim_longe_da_parada' end

        -- Começando no jogador, corta o caminho até a saída do trecho.
        local first, best = 1, math.huge
        for index, point in ipairs(samples) do
            local distance = planarGap(point, from)
            if distance < best then first, best = index, distance end
            if distance <= 25.0 then break end
        end
        if best > TRACE_SNAP then return {}, gap, ('nao_passa_pela_saida: começa a %.0f m'):format(best) end
        local leg = {}
        for index = first, #samples do leg[#leg + 1] = samples[index] end
        if #leg < 2 then return {}, gap, 'trecho_curto' end
        return leg, gap
    end

    ---Plano B: a rota do waypoint (a mesma de marcar no mapa), que acha caminhos que a rota
    ---multiponto às vezes não acha. O admin já está na saída do trecho; a rota começa nele.
    ---@return table[] samples
    ---@return number gap
    ---@return string? problem
    local function traceLegByWaypoint(from, to)
        ClearGpsMultiRoute()
        SetNewWaypoint(to.x, to.y)
        local deadline = GetGameTimer() + 6000
        local samples, gap, used = {}, -1, nil
        repeat
            Wait(200)
            for _, flag in ipairs({ true, false }) do
                local combo = { flag = flag, type = 0 }
                local found = sampleRoute(combo)
                local foundGap = #found > 0 and planarGap(found[#found], to) or -1
                if foundGap >= 0 and foundGap <= TRACE_SNAP then
                    samples, gap, used = found, foundGap, flag
                    break
                end
                if #found > #samples then samples, gap = found, foundGap end
            end
        until used ~= nil or GetGameTimer() > deadline
        SetWaypointOff()
        if used == nil then return {}, gap, 'waypoint_sem_rota' end
        traceLog('    waypoint respondeu com tipo=0 p1=%s', tostring(used))

        local first, best = 1, math.huge
        for index, point in ipairs(samples) do
            local distance = planarGap(point, from)
            if distance < best then first, best = index, distance end
            if distance <= 25.0 then break end
        end
        if best > TRACE_SNAP then return {}, gap, ('waypoint_nao_passa_pela_saida: começa a %.0f m'):format(best) end
        local leg = {}
        for index = first, #samples do leg[#leg + 1] = samples[index] end
        if #leg < 2 then return {}, gap, 'trecho_curto' end
        return leg, gap
    end

    local function polylineLength(samples)
        local length = 0.0
        for index = 2, #samples do
            local a, b = samples[index - 1], samples[index]
            length = length + math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
        end
        return length
    end

    ---O GPS só acerta a partida onde o jogo já carregou a malha de ruas (perto do jogador).
    ---Por isso o traçado leva o admin até cada trecho, congelado para não cair sem colisão, e
    ---o devolve no fim.
    local function moveTo(entity, point)
        SetEntityCoordsNoOffset(entity, point.x, point.y, point.z + 1.0, false, false, false)
        Wait(TRACE_LOAD_MS)
    end

    ---Traça uma linha trecho a trecho (o admin já está congelado; volta no fim da passada).
    ---@return table[] samples
    ---@return { length: number, failedLegs: integer, worstGap: number }
    local function traceOne(route, entity, combo)
        traceLog('%s: %d pontos de passagem, %.0f m em linha reta', route.code, #route.points, route.straight)
        local samples, worstGap, failed = {}, 0, 0
        for index = 1, #route.points - 1 do
            local from, to = route.points[index], route.points[index + 1]
            local straight = math.sqrt((from.x - to.x) ^ 2 + (from.y - to.y) ^ 2)
            moveTo(entity, from)
            local leg, gap, problem = traceLeg(from, to, combo)
            -- Longe da cidade a malha de ruas pode demorar mais para carregar: uma segunda
            -- tentativa com o dobro da espera.
            if #leg == 0 and problem == 'gps_sem_resposta' then
                traceLog('  trecho %d: GPS sem resposta, tentando de novo', index)
                Wait(TRACE_LOAD_MS * 2)
                leg, gap, problem = traceLeg(from, to, combo)
            end
            -- Partindo da coordenada da parada, o GPS pode encaixar num nó sem saída. O fim do
            -- trecho anterior já está comprovadamente na estrada, a poucos metros: parte dele.
            local previous = samples[#samples]
            if #leg == 0 and previous and math.sqrt((previous.x - from.x) ^ 2 + (previous.y - from.y) ^ 2) <= TRACE_SNAP then
                traceLog('  trecho %d: partindo do fim do trecho anterior (%.0f m da parada)', index, math.sqrt((previous.x - from.x) ^ 2 + (previous.y - from.y) ^ 2))
                leg, gap, problem = traceLeg({ x = previous.x, y = previous.y, z = from.z }, to, combo)
            end
            if #leg == 0 and problem ~= 'trecho_curto' then
                traceLog('  trecho %d: rota multiponto falhou (%s); tentando pelo waypoint', index, problem or '?')
                leg, gap, problem = traceLegByWaypoint(from, to)
            end
            if #leg == 0 then
                -- Trecho curto (saída do ônibus ↔ terminal) entra reto sem contar como falha.
                if problem ~= 'trecho_curto' then failed = failed + 1 end
                leg = { { x = from.x, y = from.y }, { x = to.x, y = to.y } }
                traceLog('  trecho %d: SEM GPS (%s, fim a %.0f m); reta de %.0f m', index, problem or '?', gap, straight)
            else
                traceLog('  trecho %d: %.0f m pela estrada (%.0f m reto, %.2f×), fim a %.0f m', index, polylineLength(leg), straight, straight > 0 and polylineLength(leg) / straight or 0, gap)
                worstGap = math.max(worstGap, gap)
            end
            for _, point in ipairs(leg) do samples[#samples + 1] = point end
        end
        local length = polylineLength(samples)
        traceLog('%s: %d amostras, %.0f m pela estrada (%.2f× a linha reta), pior fim de trecho a %.0f m, %d trecho(s) sem GPS',
            route.code, #samples, length, route.straight > 0 and length / route.straight or 0, worstGap, failed)
        return samples, { length = length, failedLegs = failed, worstGap = worstGap }
    end

    ---Uma passada: congela o admin, traça cada linha, grava (com `save`) e devolve o admin.
    local function trace(payload)
        if tracing then return end
        tracing = true
        local started = GetGameTimer()
        local entity = cache.vehicle or cache.ped
        local origin, originHeading = GetEntityCoords(entity), GetEntityHeading(entity)
        FreezeEntityPosition(entity, true)

        local combo, roads, saved, partial = {}, {}, 0, 0
        -- Erro no meio não pode deixar o admin congelado longe de onde estava.
        local ok, err = pcall(function()
            for index, route in ipairs(payload.routes) do
                Integrations.notify(locale('editor.trace_running', ('%s (%d/%d)'):format(route.code, index, #payload.routes)), 'inform')
                local samples, stats = traceOne(route, entity, combo)
                roads[route.id] = samples
                if stats.failedLegs > 0 then partial = partial + 1 end
                if payload.save then
                    local response = lib.callback.await('noir_busjob:server:editor:saveTrace', false, route.id, samples, { failedLegs = stats.failedLegs })
                    if response and response.ok then
                        saved = saved + 1
                        traceLog('%s: salvo (%d m pela estrada)', route.code, response.roadMeters)
                    else
                        traceLog('%s: NÃO salvo (%s)', route.code, response and response.code or 'sem resposta')
                        Integrations.notify(locale('editor.trace_save_failed', route.code), 'error')
                    end
                end
            end
        end)
        if not ok then lib.print.error(('[onibusrota] erro no traçado: %s'):format(err)) end

        SetGpsMultiRouteRender(false)
        ClearGpsMultiRoute()
        SetEntityCoordsNoOffset(entity, origin.x, origin.y, origin.z, false, false, false)
        SetEntityHeading(entity, originHeading)
        Wait(TRACE_LOAD_MS)
        FreezeEntityPosition(entity, false)
        tracing = false

        traceLog('passada: %d linha(s), %d salva(s), %d com trecho em reta, %d ms', #payload.routes, saved, partial, GetGameTimer() - started)
        Integrations.notify(locale('editor.trace_batch_done', #payload.routes, saved, partial), partial > 0 and 'warning' or 'success')
        if not mapOpen and not editor.open and next(roads) then
            openMap(payload.map, false, { roads = roads, select = #payload.routes == 1 and payload.routes[1].id or nil })
        end
    end

    RegisterNetEvent('noir_busjob:client:traceRoute', function(payload)
        if source ~= 65535 or type(payload) ~= 'table' or type(payload.routes) ~= 'table' or #payload.routes == 0 then return end
        CreateThread(function() trace(payload) end)
    end)

    RegisterNUICallback('map:close', function(_, cb)
        cb({ ok = true })
        closeMap()
    end)

    AddEventHandler('bgrz_core:client:playerUnloaded', closeMap)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then closeMap() end
    end)

    AddEventHandler('bgrz_core:client:playerUnloaded', close)
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then close() end
    end)
end
