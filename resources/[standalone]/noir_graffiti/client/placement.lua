local Geometry = NoirGraffiti.Geometry

-- Só geometria do mundo e objetos: ped e veículo não são parede.
local WALL_FLAGS = 1 | 16

-- Movimento, armas, veículo e as teclas que o posicionamento usa.
local DISABLED = { 14, 15, 23, 24, 25, 30, 31, 32, 33, 34, 35, 37, 38, 44, 45, 47, 75,
    140, 141, 142, 172, 173, 174, 175, 177, 191, 200, 241, 242, 257, 263, 264 }

-- As teclas e o que elas fazem, num lugar só. O painel da direita é montado a partir
-- daqui, então mudar um controle e esquecer a legenda deixou de ser possível.
local HELP = {
    { key = 'RODA', label = 'Tamanho' },
    { key = 'Q / E', label = 'Girar' },
    { key = 'SETAS', label = 'Mover' },
    { key = 'ENTER', label = 'Aplicar' },
    { key = 'BACKSPACE', label = 'Voltar' },
}

local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

local placing = false
local preview
local probes
local formPromise
local formOpened = false

---O raio sai da câmera, não do jogador, e em terceira pessoa a câmera fica metros atrás
---dele: um raio do tamanho do alcance morre antes da parede. Estende o raio pela distância
---câmera→ped e deixa o alcance para a medição a partir do jogador, como o ox_target faz.
---@return vector3? coords, vector3? normal, string? err
local function findWall()
    local pedCoords = GetEntityCoords(cache.ped)
    local range = #(GetFinalRenderedCamCoord() - pedCoords) + Config.Placement.maxDistance
    local hit, _, coords, normal = lib.raycast.fromCamera(WALL_FLAGS, 4, range)
    if not hit or not coords or not normal then
        return nil, nil, 'Aponte para uma parede.'
    end
    if #(pedCoords - coords) > Config.Placement.maxDistance then
        return nil, nil, 'Chegue mais perto da parede.'
    end
    local rise = coords.z - pedCoords.z
    if rise > Config.Placement.maxHeightUp or rise < -Config.Placement.maxHeightDown then
        return nil, nil, 'Mire mais perto da sua altura.'
    end
    if math.abs(normal.z) > Config.Placement.maxWallNormalZ then
        return nil, nil, 'Isso não é uma parede: mire numa superfície vertical.'
    end
    return coords, normal
end

-- NUI -------------------------------------------------------------------------------

local function closeForm(result)
    local pending = formPromise
    if not pending then return end
    formPromise = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    pending:resolve(result)
end

---A página confirma que abriu. Sem esse aviso o jogador ficaria com o foco da NUI preso
---num erro de JavaScript: sem teclado no jogo, sem ESC — que é tratado pela própria
---página que falhou — e com a lata inutilizável até o relog.
RegisterNUICallback('graffiti:opened', function(_, cb)
    cb('ok')
    formOpened = true
end)

---Prazo só do aperto de mão, não do preenchimento: quem está escolhendo a fonte com calma
---já respondeu faz tempo.
local FORM_HANDSHAKE = 3000

local function watchForm(pending)
    CreateThread(function()
        Wait(FORM_HANDSHAKE)
        if formPromise ~= pending or formOpened then return end
        print('[noir_graffiti] a janela não respondeu; foco devolvido ao jogo')
        closeForm(false)
        lib.notify({ description = 'A janela do graffiti não abriu. Tente de novo.', type = 'error' })
    end)
end

---@param previous? table valores para reabrir preenchido, quando o jogador volta
---@return table|false form { text, font, color, thickness }
local function openForm(previous)
    formPromise = promise.new()
    formOpened = false
    watchForm(formPromise)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = {
        fonts = Config.Fonts,
        presets = Config.ColorPresets,
        thickness = Config.Thickness,
        previous = previous,
        defaultColor = Config.DefaultColor,
        defaultFont = Config.Fonts[1] and Config.Fonts[1].id,
        minLength = Config.Text.minLength,
        maxLength = Config.Text.maxLength,
        maxLines = Config.Text.maxLines,
    } })
    return Citizen.Await(formPromise)
end

RegisterNUICallback('graffiti:submit', function(data, cb)
    cb('ok')
    closeForm(data)
end)

RegisterNUICallback('graffiti:cancel', function(_, cb)
    cb('ok')
    closeForm(false)
end)

-- Superfície sob o graffiti -----------------------------------------------------------

-- Amostras numa grade 3x3 sobre o quad, recuadas 4% da borda: o canto exato costuma cair
-- em cima do fim da parede e reprovaria um posicionamento que na prática cabe.
local SAMPLE_INSET = 0.96
-- Quanto o raio de sondagem avança e recua a partir do plano do graffiti. Curto de
-- propósito: o que interessa é se existe parede logo atrás daquele ponto, não o que
-- existe do outro lado do quarteirão.
local PROBE_DEPTH = 0.25

---Ponto do quad em coordenadas normalizadas, com u e v indo de -1 (esquerda/base) a
---1 (direita/topo). Interpola os quatro cantos, então já vem com a rotação aplicada.
local function samplePoint(corners, u, v)
    local alongTop = corners.topLeft + (corners.topRight - corners.topLeft) * ((u + 1.0) * 0.5)
    local alongBottom = corners.bottomLeft + (corners.bottomRight - corners.bottomLeft) * ((u + 1.0) * 0.5)
    return alongBottom + (alongTop - alongBottom) * ((v + 1.0) * 0.5)
end

---Dispara as nove sondas de uma vez. Elas não são lidas neste frame: o resultado de um
---shapetest só fica pronto no frame seguinte, e esperar por ele aqui travaria o loop.
local function startProbes(corners, normal)
    local probe = { handles = {}, normal = normal }
    for i = 1, 3 do
        for j = 1, 3 do
            local point = samplePoint(corners, (i - 2) * SAMPLE_INSET, (j - 2) * SAMPLE_INSET)
            local from = point + normal * PROBE_DEPTH
            local to = point - normal * PROBE_DEPTH
            probe.handles[#probe.handles + 1] = StartShapeTestLosProbe(from.x, from.y, from.z,
                to.x, to.y, to.z, WALL_FLAGS, cache.ped, 4)
        end
    end
    return probe
end

---Cada handle só devolve resultado uma vez: depois de lido, ele é consumido e uma segunda
---leitura responde "nada". Por isso os que já responderam são marcados e o veredito fica
---guardado no `probe` — senão uma única sonda atrasada envenenaria as outras oito.
---
---Não basta perguntar se a sonda acertou alguma coisa: numa quina interna o raio do canto
---acerta a parede perpendicular e passaria. Por isso a normal de cada acerto é comparada
---com a do plano do graffiti; se divergir, aquele canto está encostando em outra face.
---@return boolean? cabe, string? motivo — nil enquanto alguma sonda não respondeu, e aí o
---veredito anterior continua valendo.
local function readProbes(probe)
    local normal = probe.normal
    for i = 1, #probe.handles do
        local handle = probe.handles[i]
        if handle then
            local ready, hit, _, surface = GetShapeTestResult(handle)
            if ready == 1 then return nil end
            probe.handles[i] = false

            -- 2 é resultado. Qualquer outro status é handle que o jogo não reconhece mais,
            -- e ele não tem veredito nenhum: lê-lo como "não acertou nada" reprovaria uma
            -- parede boa.
            if ready == 2 then
                probe.answered = (probe.answered or 0) + 1

                if not hit or hit == 0 then
                    probe.reason = 'Parte do graffiti está fora da parede. Diminua com a roda ou reposicione.'
                elseif surface then
                    local alignment = surface.x * normal.x + surface.y * normal.y + surface.z * normal.z
                    if alignment < Config.Placement.minSurfaceAlignment and not probe.reason then
                        probe.reason = 'A superfície não é plana o bastante: evite quinas, pilares e paredes curvas.'
                    end
                end
            end
        end
    end

    -- Lote inteiro perdido, sem uma medição sequer. Aprovar por omissão deixaria passar
    -- graffiti fora da parede, e reprovar travaria o posicionamento: o lote é descartado e
    -- o veredito anterior segue valendo até o próximo responder.
    if not probe.answered then
        probe.spent = true
        return nil
    end

    return probe.reason == nil, probe.reason
end

---A caixa que o jogador vê: toda a superfície que o graffiti consegue ocupar, e não o
---retângulo do texto. Ela fica parada enquanto o texto desliza por dentro — só muda
---quando o tamanho ou a rotação mudam.
---
---A faixa vertical vem da regra de altura, que é medida a partir do personagem: por isso
---ela é convertida do eixo Z do mundo para o eixo `up` da parede, que numa superfície
---inclinada sobe menos de um metro por metro percorrido.
---@return table corners
local function placementBounds(anchor, right, up, pedZ, scale, rotation)
    local lowest, highest = 0.0, 0.0
    if up.z > 0.05 then
        lowest = (pedZ - Config.Placement.maxHeightDown - anchor.z) / up.z
        highest = (pedZ + Config.Placement.maxHeightUp - anchor.z) / up.z
    end

    local halfWidth = Config.Render.worldWidth * scale * 0.5
    local halfHeight = halfWidth / Config.Render.aspect
    local radians = math.rad(rotation)
    local cosine, sine = math.abs(math.cos(radians)), math.abs(math.sin(radians))
    -- Extensão do quad girado sobre cada eixo da parede: sem isto o texto escaparia pelos
    -- cantos da caixa ao girar.
    local overSide = halfWidth * cosine + halfHeight * sine
    local overUp = halfWidth * sine + halfHeight * cosine

    local side = Config.Placement.maxSide + overSide
    local top, bottom = highest + overUp, lowest - overUp
    return {
        topLeft = anchor + right * -side + up * top,
        topRight = anchor + right * side + up * top,
        bottomLeft = anchor + right * -side + up * bottom,
        bottomRight = anchor + right * side + up * bottom,
    }
end

-- Posicionamento --------------------------------------------------------------------

---Um shapetest só devolve o slot depois que o resultado é lido, e o pool do jogo é
---pequeno. Sair do posicionamento com nove sondas no ar prendia nove slots por sessão,
---até sobrar handle inválido para todo mundo.
local function drainProbes(probe)
    if not probe then return end
    CreateThread(function()
        local timeout = GetGameTimer() + 2000
        while GetGameTimer() < timeout do
            local pending = false
            for i = 1, #probe.handles do
                local handle = probe.handles[i]
                if handle then
                    if GetShapeTestResult(handle) == 1 then
                        pending = true
                    else
                        probe.handles[i] = false
                    end
                end
            end
            if not pending then return end
            Wait(0)
        end
    end)
end

local function stopPlacing()
    placing = false
    SendNUIMessage({ action = 'hideHelp' })
    -- Aqui não há animação rodando no caminho normal — ela começa depois deste ponto. Esta
    -- chamada é para o caminho de erro: um estouro dentro da barra de progresso cai no pcall
    -- lá de baixo, que chama stopPlacing(), e sem isto a lata ficaria na mão para sempre.
    NoirSpray.stopSprayAnimation()
    drainProbes(probes)
    probes = nil
    if preview then
        NoirGraffiti.ReleaseRenderer(preview)
        preview = nil
    end
    FreezeEntityPosition(cache.ped, false)
end

---`fits == false` pinta o contorno de vermelho: é o aviso de que parte do graffiti está
---sobrando para fora da parede.
local function drawRect(corners, fits)
    local r, g, b = 255, 255, 255
    if fits == false then r, g, b = 220, 60, 60 end
    local tl, tr, bl, br = corners.topLeft, corners.topRight, corners.bottomLeft, corners.bottomRight
    DrawLine(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, r, g, b, 190)
    DrawLine(tr.x, tr.y, tr.z, br.x, br.y, br.z, r, g, b, 190)
    DrawLine(br.x, br.y, br.z, bl.x, bl.y, bl.z, r, g, b, 190)
    DrawLine(bl.x, bl.y, bl.z, tl.x, tl.y, tl.z, r, g, b, 190)
end

---O Enter (ou o clique) que confirmou a NUI ainda está descendo quando o loop começa.
---Sem esperar a soltura, o mesmo toque confirmaria o posicionamento no primeiro frame.
---Esperar a soltura não basta. Se a tecla já subiu enquanto a NUI tinha o foco, o jogo
---entrega o `JustReleased` assim que o foco volta ao jogo, e aí não há o que esperar: a
---confirmação dispara no primeiro frame do posicionamento. Por isso além de esperar, o
---laço ignora confirmação por um instante — é a soltura velha passando.
local ARM_DELAY = 250

---@return number armedAt momento a partir do qual a confirmação vale
local function waitForRelease()
    local timeout = GetGameTimer() + 1000
    while GetGameTimer() < timeout do
        if not IsControlPressed(0, 191) and not IsControlPressed(0, 24) then break end
        Wait(0)
    end
    return GetGameTimer() + ARM_DELAY
end

local function place(wallCoords, wallNormal, form, slot)
    placing = true
    FreezeEntityPosition(cache.ped, true)
    preview = NoirGraffiti.AcquireRenderer(form, true)
    if not preview then
        stopPlacing()
        return lib.notify({ description = 'Não foi possível carregar a prévia.', type = 'error' })
    end

    -- Eixos da parede medidos sem rotação: subir é subir e a esquerda é a esquerda,
    -- mesmo com o graffiti girado de lado.
    local wallRight, wallUp = Geometry.basis(wallNormal, 0.0)
    -- Em terceira pessoa a câmera fica deslocada para o lado, então o ponto mirado cai à
    -- direita de quem picha. O eixo `right` é horizontal por construção, então recolocar a
    -- âncora sobre o personagem centraliza a área nele sem mexer na altura que ele mirou.
    local pedSide = dot(GetEntityCoords(cache.ped) - wallCoords, wallRight)
    local anchor = wallCoords + wallNormal * Config.Placement.wallOffset + wallRight * pedSide
    local rotation, side, height = 0.0, 0.0, 0.0
    local scale = Config.Placement.defaultScale
    local fits, reason = true, nil
    probes = nil

    local function positionFor(s, h)
        return anchor + wallRight * s + wallUp * h
    end

    ---Um deslocamento só vale se couber no limite do eixo e deixar o graffiti dentro do
    ---alcance do jogador. Movimento recusado simplesmente não acontece, então segurar a
    ---seta encosta no limite e para, sem travar o resto do posicionamento.
    local function allowed(s, h)
        if math.abs(s) > Config.Placement.maxSide then return false end
        local pedCoords = GetEntityCoords(cache.ped)
        local target = positionFor(s, h)
        -- A mesma regra da mira, agora contra o deslocamento: a tag não escapa da faixa
        -- de altura do personagem nem subindo aos poucos com a seta.
        local rise = target.z - pedCoords.z
        if rise > Config.Placement.maxHeightUp or rise < -Config.Placement.maxHeightDown then
            return false
        end
        return #(pedCoords - target) <= Config.Placement.maxReach
    end

    SendNUIMessage({ action = 'help', payload = HELP })
    local armedAt = waitForRelease()

    while placing do
        Wait(0)
        -- O posicionamento pode ter sido encerrado de fora durante a espera — parada do
        -- resource, por exemplo. Sem isto o frame seguinte ainda dispararia um lote de
        -- sondas que ninguém mais leria.
        if not placing then break end
        DisablePlayerFiring(cache.playerId, true)
        for i = 1, #DISABLED do DisableControlAction(0, DISABLED[i], true) end

        local delta = GetFrameTime()
        if IsDisabledControlPressed(0, 44) then rotation = rotation - Config.Placement.rotationSpeed * delta end
        if IsDisabledControlPressed(0, 38) then rotation = rotation + Config.Placement.rotationSpeed * delta end
        rotation = rotation % 360
        local step = Config.Placement.moveSpeed * delta
        if IsDisabledControlPressed(0, 172) and allowed(side, height + step) then height = height + step end
        if IsDisabledControlPressed(0, 173) and allowed(side, height - step) then height = height - step end
        if IsDisabledControlPressed(0, 174) and allowed(side - step, height) then side = side - step end
        if IsDisabledControlPressed(0, 175) and allowed(side + step, height) then side = side + step end

        if IsDisabledControlJustPressed(0, 241) then scale = scale + Config.Placement.scaleStep end
        if IsDisabledControlJustPressed(0, 242) then scale = scale - Config.Placement.scaleStep end
        scale = math.max(Config.Placement.minScale, math.min(Config.Placement.maxScale, scale))

        local coords = positionFor(side, height)
        local corners = Geometry.corners(coords, wallNormal, rotation, scale)
        -- Lê as sondas do frame anterior e dispara as próximas.
        if probes then
            local verdict, why = readProbes(probes)
            if verdict ~= nil then
                fits, reason = verdict, why
                probes = nil
            elseif probes.spent then
                probes = nil
            end
        end
        if not probes then probes = startProbes(corners, wallNormal) end

        -- A prévia só entra quando o CEF entregar a superfície; até lá desenha só a caixa.
        if NoirGraffiti.drawEnabled and NoirGraffiti.CanDraw(preview) then
            Geometry.drawMarker(coords, Geometry.markerRotation(wallNormal, rotation),
                scale, preview.dict, preview.txt, 230)
        end
        drawRect(placementBounds(anchor, wallRight, wallUp,
            GetEntityCoords(cache.ped).z, scale, rotation), fits)

        -- Voltar não cancela: devolve o controle para o formulário, que reabre preenchido.
        local armed = GetGameTimer() >= armedAt

        if armed and IsDisabledControlJustReleased(0, 177) then
            stopPlacing()
            return 'back'
        end

        if armed and (IsDisabledControlJustReleased(0, 191) or IsDisabledControlJustReleased(0, 24)) then
            if not fits then
                lib.notify({ description = reason or 'Posição inválida.', type = 'error' })
                goto continue
            end
            stopPlacing()
            -- A lata na mão e a animação. O `disable` da barra é o que segura o jogador no
            -- lugar durante a pintura, então não há travamento próprio para desfazer aqui.
            NoirSpray.startSprayAnimation(form.color)
            local completed = lib.progressCircle({
                duration = Config.Placement.duration,
                label = 'Aplicando graffiti',
                position = 'bottom',
                canCancel = true,
                disable = { move = true, car = true, combat = true },
            })
            NoirSpray.stopSprayAnimation()
            if not completed then return end

            local result = lib.callback.await('noir_graffiti:server:place', false, {
                text = form.text, font = form.font, color = form.color,
                thickness = form.thickness, slot = slot,
                x = coords.x, y = coords.y, z = coords.z,
                nx = wallNormal.x, ny = wallNormal.y, nz = wallNormal.z,
                rotation = rotation, scale = scale,
            })
            return lib.notify({
                description = result and result.success and 'Graffiti aplicado.'
                    or (result and result.error) or 'Não foi possível aplicar o graffiti.',
                type = result and result.success and 'success' or 'error',
            })
        end

        ::continue::
    end
end

exports('useSpraycan', function(_, slotData)
    -- Estes dois avisam em vez de sair calados. Um erro em qualquer ponto do fluxo deixaria
    -- o sinalizador ligado, e a lata pararia de funcionar para sempre sem dizer por quê —
    -- que é o pior tipo de falha para diagnosticar de dentro do jogo.
    if placing then
        return lib.notify({ description = 'Você já está posicionando um graffiti.', type = 'error' })
    end
    if formPromise then
        return lib.notify({ description = 'A janela do graffiti já está aberta.', type = 'error' })
    end

    local wallCoords, wallNormal, err = findWall()
    if not wallCoords then
        return lib.notify({ description = err, type = 'error' })
    end

    -- A parede fica travada desde o uso do item: com a NUI em foco o jogador não anda,
    -- então o ponto mirado continua válido quando o formulário fecha, inclusive quando
    -- ele reabre pelo Voltar.
    local form
    while true do
        local opened, result = pcall(openForm, form)
        if not opened then
            closeForm(false)
            print(('[noir_graffiti] erro ao abrir a janela: %s'):format(result))
            return lib.notify({ description = 'Não foi possível abrir a janela.', type = 'error' })
        end
        if type(result) ~= 'table' then return end
        form = result

        -- O pcall existe para o `placing` nunca ficar preso: qualquer erro dentro do laço
        -- ainda passa por stopPlacing(), que descongela o jogador e libera a lata.
        local placed, outcome = pcall(place, wallCoords, wallNormal, form, slotData and slotData.slot)
        if not placed then
            stopPlacing()
            print(('[noir_graffiti] erro no posicionamento: %s'):format(outcome))
            return lib.notify({ description = 'Erro ao posicionar o graffiti.', type = 'error' })
        end
        if outcome ~= 'back' then return end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    closeForm(false)
    if placing then stopPlacing() end
end)

---Diagnóstico ao vivo: por 15 segundos desenha onde o raio bate, o retângulo que seria
---aplicado e a distância entre o ponto de impacto e o centro do graffiti. Serve para
---separar "o raio bateu no lugar errado" de "o retângulo é grande demais para o texto".
---Some daqui quando o posicionamento estiver estável.
local debugging = false

RegisterCommand('graffitidebug', function()
    if debugging then return end
    debugging = true
    local until_ = GetGameTimer() + 15000
    CreateThread(function()
        while GetGameTimer() < until_ do
            Wait(0)
            local pedCoords = GetEntityCoords(cache.ped)
            local camCoords = GetFinalRenderedCamCoord()
            local range = #(camCoords - pedCoords) + Config.Placement.maxDistance
            local hit, entity, coords, normal = lib.raycast.fromCamera(WALL_FLAGS, 4, range)

            if hit and coords and normal then
                -- Vermelho: o ponto exato em que o raio encostou na superfície.
                DrawMarker(28, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0,
                    0.06, 0.06, 0.06, 200, 40, 40, 180, false, false, 2, nil, nil, false)

                local anchor = coords + normal * Config.Placement.wallOffset
                local corners = Geometry.corners(anchor, normal, 0.0, Config.Placement.defaultScale)
                drawRect(corners)

                -- Verde: o centro do retângulo. Se ele não estiver colado no marcador
                -- vermelho, o problema é a âncora, não o tamanho.
                DrawMarker(28, anchor.x, anchor.y, anchor.z, 0, 0, 0, 0, 0, 0,
                    0.04, 0.04, 0.04, 40, 200, 40, 180, false, false, 2, nil, nil, false)

                local width = #(corners.topRight - corners.topLeft)
                local height = #(corners.topLeft - corners.bottomLeft)
                lib.showTextUI((
                    'impacto %.2fm do ped | entidade %s | normal %.2f/%.2f/%.2f\n'
                    .. 'retangulo %.2fm x %.2fm | afastamento da parede %.3fm'
                ):format(#(pedCoords - coords), entity, normal.x, normal.y, normal.z,
                    width, height, #(anchor - coords)), { position = 'top-center' })
            else
                lib.showTextUI(('o raio nao acertou nada (alcance %.1fm)'):format(range),
                    { position = 'top-center' })
            end
        end
        lib.hideTextUI()
        debugging = false
    end)
end, false)
