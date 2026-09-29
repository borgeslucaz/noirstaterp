-- ESTÚDIO DESLIGADO (2026-09-29): as fotos da central já foram feitas (html/img/vehicles/*-fixed.png).
-- Para refazer: tirar este bloco de comentário (aqui e no server/studio.lua), descomentar a linha no
-- fxmanifest.lua, `ensure noir_taxijob`, rodar /taxifotos e depois `bash dev/fotos.sh`.
--[==[
-- Estúdio de fotos dos carros da central (/taxifotos). O servidor manda a fila; aqui cada carro
-- nasce local, parado no alto, com o visual do aluguel (appearance), num fundo verde. O admin
-- posiciona a câmera em volta do carro e aperta ENTER; o servidor captura a tela e grava o PNG
-- cru. O carro seguinte começa com a câmera onde o anterior ficou.
local busy = false
local origin = nil ---@type { coords: vector3, heading: number }?
local floor = nil
-- Câmera em órbita do carro; fica entre carros e entre rodadas.
local view = nil ---@type { yaw: number, pitch: number, distance: number, height: number, fov: number }?

local function loadModel(name)
    local model = joaat(name)
    -- Modelo ausente derruba o cliente no Enhanced: confere antes de pedir.
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return nil end
    if not pcall(lib.requestModel, model, 10000) then return nil end
    return model
end

-- Piso invisível sob o carro: sem chão as rodas ficam penduradas e a suspensão esticada.
-- Invisível ainda colide, e não aparece nem faz sombra na foto.
local FLOOR_MODELS = { 'stt_prop_stunt_bblock_huge_05', 'stt_prop_stunt_bblock_huge_01', 'prop_container_01a' }

local function createFloor(center)
    for _, name in ipairs(FLOOR_MODELS) do
        local model = joaat(name)
        if IsModelInCdimage(model) and pcall(lib.requestModel, model, 10000) then
            local obj = CreateObjectNoOffset(model, center.x, center.y, center.z, false, false, false)
            SetModelAsNoLongerNeeded(model)
            local min, max = GetModelDimensions(model)
            -- Topo do piso na altura da cena.
            SetEntityCoordsNoOffset(obj, center.x, center.y, center.z - max.z, false, false, false)
            FreezeEntityPosition(obj, true)
            SetEntityVisible(obj, false, false)
            return obj
        end
    end
end

local function applyAppearance(veh, appearance)
    SetVehicleModKit(veh, 0)
    -- Visual copiado de um carro montado no qbx_customs (dev/visuais): pintura, peças, rodas,
    -- película e extras de uma vez. Os campos abaixo continuam valendo por cima.
    if appearance and appearance.props then lib.setVehicleProperties(veh, appearance.props) end
    if not appearance then return end
    for modType, index in pairs(appearance.mods or {}) do
        if GetNumVehicleMods(veh, modType) > index then SetVehicleMod(veh, modType, index, false) end
    end
    if appearance.color then SetVehicleColours(veh, appearance.color, appearance.color) end
    if appearance.livery and GetVehicleLiveryCount(veh) > appearance.livery then SetVehicleLivery(veh, appearance.livery) end
    -- Extras (painel de propaganda, luminoso...) o jogo sorteia a cada spawn: fica ligado só o
    -- que está na lista.
    if appearance.extras then
        local keep = {}
        for _, id in ipairs(appearance.extras) do keep[id] = true end
        for id = 0, 20 do
            if DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, not keep[id]) end
        end
    end
end

---Fundo verde: parede atrás do carro (vira com a câmera) e chão sob ele, para a câmera de cima.
---DrawPoly desenha sem luz: a cor chega pura à foto e o recorte (chromakey) fica limpo. Cada
---face vai nos dois sentidos para não sumir de costas.
local function quad(a, b, d, e, c)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, d.x, d.y, d.z, c[1], c[2], c[3], 255)
    DrawPoly(d.x, d.y, d.z, b.x, b.y, b.z, a.x, a.y, a.z, c[1], c[2], c[3], 255)
    DrawPoly(a.x, a.y, a.z, d.x, d.y, d.z, e.x, e.y, e.z, c[1], c[2], c[3], 255)
    DrawPoly(e.x, e.y, e.z, d.x, d.y, d.z, a.x, a.y, a.z, c[1], c[2], c[3], 255)
end

local function drawBackdrop(center, camDir, scene)
    local c = scene.wallColor
    local back = vec3(center.x - camDir.x * scene.wallDistance, center.y - camDir.y * scene.wallDistance, center.z)
    local side = vec3(-camDir.y, camDir.x, 0.0) * 80.0
    local up = vec3(0.0, 0.0, 60.0)
    quad(back - side - up, back + side - up, back + side + up, back - side + up, c)
    -- Bem abaixo do piso invisível: rente a ele, o verde cobria a base dos pneus.
    local z = center.z - 1.0
    local r = scene.wallDistance
    quad(vec3(center.x - r, center.y - r, z), vec3(center.x + r, center.y - r, z), vec3(center.x + r, center.y + r, z), vec3(center.x - r, center.y + r, z), c)
end

---Pede a captura ao servidor e espera ele gravar.
---@param index integer
---@param variant string?
---@return boolean
local function capture(index, variant)
    local saved = promise.new()
    local handler = RegisterNetEvent('noir_taxijob:client:studioSaved', function(savedIndex, savedVariant, ok)
        if savedIndex == index and savedVariant == (variant or false) then saved:resolve(ok) end
    end)
    TriggerServerEvent('noir_taxijob:server:studioShot', index, variant)
    SetTimeout(15000, function() saved:resolve(false) end)
    local ok = Citizen.Await(saved)
    RemoveEventHandler(handler)
    return ok
end

---Enquadramento automático: de lado, com o comprimento do carro inteiro no quadro.
local function autoView(model, scene)
    local min, max = GetModelDimensions(model)
    local length = (max.y - min.y) * scene.margin
    return {
        yaw = scene.heading, pitch = 3.0, fov = scene.fov,
        distance = (length / 2) / math.tan(math.rad(scene.fov / 2)) * (9 / 16) + (max.x - min.x),
        height = (max.z - min.z) / 2,
    }
end

local function placeCam(cam, center, current)
    local yaw, pitch = math.rad(view.yaw), math.rad(view.pitch)
    local dir = vec3(math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch))
    local target = vec3(center.x, center.y, center.z + view.height)
    local pos = target + dir * view.distance
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, target.x, target.y, target.z)
    SetCamFov(cam, view.fov)
    current.dir = vec3(math.cos(yaw), math.sin(yaw), 0.0)
end

-- Controles (grupo 0): mouse gira em volta do carro, W/S aproxima, Q/E sobe e desce o alvo,
-- roda do mouse muda o zoom (FOV), SHIFT acelera, R volta ao automático.
local KEYS = { forward = 32, back = 33, up = 44, down = 38, fast = 21, reset = 45, scrollUp = 241, scrollDown = 242,
    confirm = 191, skip = 194, cancel = 202 }

---Deixa o admin posicionar a câmera. Devolve 'shoot', 'skip' ou 'cancel'.
local function positionCam(cam, center, current, model, scene, label)
    UI.send('studio:show', { label = label })
    local result
    while not result do
        DisableAllControlActions(0)
        local speed = IsDisabledControlPressed(0, KEYS.fast) and 4.0 or 1.0
        view.yaw = view.yaw - GetDisabledControlNormal(0, 1) * 8.0
        view.pitch = math.max(-10.0, math.min(85.0, view.pitch - GetDisabledControlNormal(0, 2) * 8.0))
        if IsDisabledControlPressed(0, KEYS.forward) then view.distance = math.max(1.5, view.distance - 0.05 * speed) end
        if IsDisabledControlPressed(0, KEYS.back) then view.distance = math.min(60.0, view.distance + 0.05 * speed) end
        if IsDisabledControlPressed(0, KEYS.up) then view.height = math.min(10.0, view.height + 0.01 * speed) end
        if IsDisabledControlPressed(0, KEYS.down) then view.height = math.max(-2.0, view.height - 0.01 * speed) end
        if IsDisabledControlJustPressed(0, KEYS.scrollUp) then view.fov = math.max(8.0, view.fov - 1.5 * speed) end
        if IsDisabledControlJustPressed(0, KEYS.scrollDown) then view.fov = math.min(90.0, view.fov + 1.5 * speed) end
        if IsDisabledControlJustPressed(0, KEYS.reset) then view = autoView(model, scene) end
        if IsDisabledControlJustPressed(0, KEYS.confirm) then result = 'shoot'
        elseif IsDisabledControlJustPressed(0, KEYS.skip) then result = 'skip'
        elseif IsDisabledControlJustPressed(0, KEYS.cancel) then result = 'cancel' end
        placeCam(cam, center, current)
        Wait(0)
    end
    UI.send('studio:hide')
    -- O ESC também abre o menu de pausa se for solto com o controle liberado.
    while IsDisabledControlPressed(0, KEYS.cancel) do DisableAllControlActions(0) Wait(0) end
    Wait(150) -- a NUI some antes da captura
    return result
end

local function runStudio(queue, scene)
    busy = true
    local ped = cache.ped
    origin = { coords = GetEntityCoords(ped), heading = GetEntityHeading(ped) }
    local center = vec3(scene.coords.x, scene.coords.y, scene.coords.z)

    -- O jogador fica junto da cena (para o jogo carregar o carro), congelado e invisível.
    SetEntityCoordsNoOffset(ped, center.x, center.y, center.z - 30.0, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    local drawing, current = true, { dir = vec3(1.0, 0.0, 0.0) }
    CreateThread(function()
        while drawing do
            HideHudAndRadarThisFrame()
            SetOverrideWeather('EXTRASUNNY')
            NetworkOverrideClockTime(12, 0, 0)
            drawBackdrop(center, current.dir, scene)
            Wait(0)
        end
    end)

    floor = createFloor(center)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)

    for index, shot in ipairs(queue) do
        local model = loadModel(shot.model)
        if not model then
            print(('[noir_taxijob] estúdio: modelo %s não existe neste build; pulado'):format(shot.model))
            lib.notify({ description = ('Foto %d/%d · %s não existe neste build'):format(index, #queue, shot.model), type = 'error' })
        else
            local veh = CreateVehicle(model, center.x, center.y, center.z + 0.5, scene.heading, false, false)
            SetModelAsNoLongerNeeded(model)
            SetVehicleOnGroundProperly(veh)
            SetEntityInvincible(veh, true)
            SetVehicleDirtLevel(veh, 0.0)
            SetVehicleEngineOn(veh, false, true, true)
            SetVehicleLights(veh, 1)
            -- Vidro transparente deixa o verde aparecer e o recorte vaza o carro: película na foto.
            SetVehicleModKit(veh, 0)
            SetVehicleWindowTint(veh, scene.windowTint or 1)

            if not view then view = autoView(model, scene) end
            placeCam(cam, center, current)
            Wait(scene.settleMs) -- assenta no piso
            FreezeEntityPosition(veh, true)
            applyAppearance(veh, shot.appearance)

            local action = positionCam(cam, center, current, model, scene, ('%d/%d · %s'):format(index, #queue, shot.model))
            if action == 'cancel' then
                DeleteEntity(veh)
                break
            elseif action == 'skip' then
                lib.notify({ description = ('Foto %d/%d · %s pulada'):format(index, #queue, shot.model) })
            elseif shot.liveries then
                -- Modo de escolha: uma foto por livery (nativa e do mod 48) para achar a certa.
                local variants = {}
                for i = 0, GetVehicleLiveryCount(veh) - 1 do variants[#variants + 1] = { name = ('livery%d'):format(i), livery = i } end
                for i = 0, GetNumVehicleMods(veh, 48) - 1 do variants[#variants + 1] = { name = ('mod48_%d'):format(i), mod = i } end
                -- Combinações de cor do carcols (a cor de fábrica que o modelo sorteia).
                for i = 0, GetNumberOfVehicleColours(veh) - 1 do variants[#variants + 1] = { name = ('combo%d'):format(i), combo = i } end
                -- Cada extra sozinho (todos os outros desligados), para escolher o `appearance.extras`.
                for id = 0, 20 do
                    if DoesExtraExist(veh, id) then variants[#variants + 1] = { name = ('extra%d'):format(id), extra = id } end
                end

                -- Diagnóstico no log do servidor: de onde vem a cor que a foto mostra.
                local primary, secondary = GetVehicleColours(veh)
                local pearl, wheel = GetVehicleExtraColours(veh)
                local mods = {}
                for modType = 0, 49 do
                    local count = GetNumVehicleMods(veh, modType)
                    if count > 0 then mods[#mods + 1] = ('%d:%d'):format(modType, count) end
                end
                local extras = {}
                for extra = 0, 20 do
                    if DoesExtraExist(veh, extra) then extras[#extras + 1] = ('%d=%s'):format(extra, IsVehicleExtraTurnedOn(veh, extra) and 'on' or 'off') end
                end
                TriggerServerEvent('noir_taxijob:server:studioInfo', index, {
                    colours = ('prim %d sec %d pearl %d wheel %d interior %d dash %d combo %d/%d'):format(primary, secondary, pearl, wheel,
                        GetVehicleInteriorColor(veh), GetVehicleDashboardColor(veh), GetVehicleColourCombination(veh), GetNumberOfVehicleColours(veh)),
                    mods = table.concat(mods, ' '),
                    extras = table.concat(extras, ' '),
                    liveries = GetVehicleLiveryCount(veh),
                })

                for _, variant in ipairs(variants) do
                    if variant.livery then SetVehicleLivery(veh, variant.livery)
                    elseif variant.mod then SetVehicleMod(veh, 48, variant.mod, false)
                    elseif variant.extra then
                        for id = 0, 20 do
                            if DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, id ~= variant.extra) end
                        end
                    else SetVehicleColours(veh, 0, 0) Wait(250) SetVehicleColourCombination(veh, variant.combo) end
                    Wait(500)
                    local ok = capture(index, variant.name)
                    lib.notify({ description = ('%s · %s %s'):format(shot.model, variant.name, ok and 'salva' or 'falhou'), type = ok and 'success' or 'error' })
                end
                if #variants == 0 then lib.notify({ description = ('%s não tem livery nem combinação de cor'):format(shot.model), type = 'error' }) end
            else
                local ok = capture(index)
                lib.notify({ description = ('Foto %d/%d · %s %s'):format(index, #queue, shot.model, ok and 'salva' or 'falhou'), type = ok and 'success' or 'error' })
            end
            DeleteEntity(veh)
        end
    end

    drawing = false
    if floor then DeleteObject(floor) floor = nil end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    ClearOverrideWeather()
    NetworkClearClockTimeOverride()
    SetEntityCoordsNoOffset(ped, origin.coords.x, origin.coords.y, origin.coords.z, false, false, false)
    SetEntityHeading(ped, origin.heading)
    origin = nil
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    busy = false
end

RegisterNetEvent('noir_taxijob:client:studio', function(queue, scene)
    if source ~= 65535 or busy or type(queue) ~= 'table' or #queue == 0 then return end
    CreateThread(function()
        local ok, err = pcall(runStudio, queue, scene)
        if not ok then
            print(('[noir_taxijob] estúdio falhou: %s'):format(err))
            -- Garante o jogador de volta ao normal mesmo com erro no meio.
            UI.send('studio:hide')
            RenderScriptCams(false, false, 0, true, true)
            if floor then DeleteObject(floor) floor = nil end
            if origin then
                SetEntityCoordsNoOffset(cache.ped, origin.coords.x, origin.coords.y, origin.coords.z, false, false, false)
                SetEntityHeading(cache.ped, origin.heading)
                origin = nil
            end
            ClearOverrideWeather()
            NetworkClearClockTimeOverride()
            SetEntityVisible(cache.ped, true, false)
            SetEntityInvincible(cache.ped, false)
            FreezeEntityPosition(cache.ped, false)
            busy = false
        end
    end)
end)
]==]
