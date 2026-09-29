NoirGraffiti = { All = {}, Geometry = {} }

-- Chave do desenho, ligada em jogo pelo /graffitidraw. O `Config.Debug.noDraw` continua
-- decidindo o estado inicial; o comando existe porque testar isso editando config obriga a
-- reiniciar o resource, e reiniciar é uma das coisas sob suspeita.
NoirGraffiti.drawEnabled = not Config.Debug.noDraw

local Geometry = NoirGraffiti.Geometry
local renderers = {} -- [token] = renderer, todos os que existem
local idle = {} -- prontos para reuso, na ordem em que foram liberados
local liveCount = 0
local nextToken = 0
-- Vaga cedida por um graffiti quando a prévia precisa nascer com o pool cheio. Fica
-- declarada aqui porque quem sabe qual graffiti está mais longe é a seção lá de baixo.
local evict
-- Criação de DUI suspensa até este instante, depois de uma que não deu certo.
local blockedUntil = 0

local function normalize(v)
    local length = #(v)
    if length < 0.0001 then return vector3(1.0, 0.0, 0.0) end
    return v / length
end

---Base ortonormal do plano da parede: `right` acompanha a parede na horizontal e `up` sai
---do produto vetorial. `rotation` gira as duas dentro do próprio plano.
function Geometry.basis(normal, rotation)
    normal = normalize(normal)
    local right = normalize(vector3(-normal.y, normal.x, 0.0))
    local up = normalize(vector3(
        normal.y * right.z - normal.z * right.y,
        normal.z * right.x - normal.x * right.z,
        normal.x * right.y - normal.y * right.x
    ))
    local angle = math.rad(rotation or 0.0)
    local cosine, sine = math.cos(angle), math.sin(angle)
    return normalize(right * cosine + up * sine), normalize(up * cosine - right * sine)
end

---Os quatro cantos do retângulo. O desenho não usa mais isto — quem usa é o posicionamento,
---para a caixa que o jogador vê e para as sondas que conferem se a parede cabe.
function Geometry.corners(coords, normal, rotation, scale)
    local right, up = Geometry.basis(normal, rotation)
    local halfWidth = Config.Render.worldWidth * (scale or 1.0) * 0.5
    local halfHeight = halfWidth / Config.Render.aspect
    return {
        topLeft = coords - right * halfWidth + up * halfHeight,
        topRight = coords + right * halfWidth + up * halfHeight,
        bottomLeft = coords - right * halfWidth - up * halfHeight,
        bottomRight = coords + right * halfWidth - up * halfHeight,
    }
end

-- O glm vem no Lua 5.4 do FiveM e é o que o upstream usa para orientar a cena na parede.
-- O `vector3(90, 0, heading)` que eu tinha copiado é o fallback dele, para quando a
-- biblioteca não carrega: põe o plano de pé virado para o lado certo, mas não diz qual eixo
-- da textura é o de cima — e a tag saía deitada.
local hasGlm, glm = pcall(require, 'glm')
if not hasGlm then glm = nil end

---Euler do marcador a partir da normal da parede, e do giro que o jogador deu no Q/E.
---
---A conta do `look` é a do upstream, sem mudança. O giro do jogador entra depois, como
---rolagem em torno do eixo que o `quatlookRotation` aponta para a normal da parede: girar em
---torno da normal é girar a tag dentro do próprio plano, que é o que o Q/E faz.
---
---Esse eixo é o Z do quadro (`glm.up()`), e não o Y: o `quatlookRotation` segue a convenção
---do GLM, em que a direção olhada vai para o Z. Com `glm.forward()` a tag tomba para fora da
---parede em vez de girar sobre ela — está testado em jogo, não mexa para lá de novo. Se o
---giro sair só invertido, troque o sinal do `spin`; se voltar a tombar, o último eixo que
---resta é `glm.right()`.
---@return vector3
function Geometry.markerRotation(normal, spin)
    spin = spin or 0.0

    if glm then
        local ok, rotation = pcall(function()
            local unit = glm.normalize(normal)
            local epsilon = 0.01
            local quatRot = quat(180, glm.forward())
            local finalQuat

            if glm.approx(glm.abs(unit.z), 1, epsilon) then
                local camRot = GetFinalRenderedCamRot(2)
                local signZ = glm.sign(unit.z) * -camRot.z - 90.0
                finalQuat = glm.quatlookRotation(unit, glm.right()) * quat(signZ, glm.up())
            elseif glm.approx(unit.y, 1, epsilon) then
                finalQuat = glm.quatlookRotation(unit, -glm.up())
                quatRot = quat(180, glm.right())
            else
                finalQuat = glm.quatlookRotation(unit, glm.up())
            end

            local euler = vec3(glm.extractEulerAngleYXZ(
                finalQuat * quatRot * quat(spin, glm.up())))
            return glm.deg(vec3(euler[2], euler[1], euler[3]))
        end)

        if ok and rotation then return rotation end
    end

    return vector3(90.0, spin, GetHeadingFromVector_2d(normal.x, normal.y))
end

---Um marcador do tipo 8, com dicionário e textura próprios.
---
---Era `DrawSpritePoly`, quatro chamadas por tag por frame, e é onde o dump de crash
---apontava: o render resolvendo a textura para índice -1 e chamando um método virtual em
---cima disso. O upstream usa polígono só na pintura à mão livre; texto na parede ele desenha
---assim, com uma chamada só, por um caminho que o jogo percorre em todo servidor que existe.
function Geometry.drawMarker(coords, rotation, scale, dict, txt, alpha)
    local width = Config.Render.worldWidth * (scale or 1.0)
    local height = width / Config.Render.aspect
    DrawMarker(8,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        rotation.x, rotation.y, rotation.z,
        width, height, 0.0,
        255, 255, 255, alpha or 255,
        false, false, 2, false,
        dict, txt, false)
end

-- Renderers (DUI) -------------------------------------------------------------------
--
-- Um DUI é caro para nascer e para morrer: subir o CEF leva frames, e foi da destruição
-- que vieram todos os crashes. Depois de pronto, porém, ele não custa quase nada — a
-- página desenha uma vez e fica parada.
--
-- Por isso renderer não é destruído quando a tag sai de alcance: volta para uma pilha e é
-- reaproveitado pela próxima, que só precisa de uma mensagem nova.

---Destruir um DUI que ainda está subindo derruba o cliente, e um que falhou na criação está
---exatamente nesse estado. A destruição espera; quem chamou segue em frente.
local function discard(dui)
    CreateThread(function()
        local timeout = GetGameTimer() + 5000
        while not IsDuiAvailable(dui) and GetGameTimer() < timeout do
            Wait(50)
        end
        Wait(100)
        DestroyDui(dui)
    end)
end

---Quanto tempo um renderer reaproveitado fica escondido depois de receber conteúdo novo.
---Sem a página confirmando, é uma estimativa: tempo de o CEF redesenhar uma vez.
local REPAINT_GRACE = 800

---Manda o conteúdo. Quem chama recebe o renderer na hora; a entrega acontece atrás.
---
---Antes isto repetia a mensagem a cada 100ms, até cinquenta vezes, esperando uma
---confirmação da página que nunca chegava — e cada repetição fazia a página redesenhar do
---zero, que era a tag piscando na parede. Agora o DUI já está de pé quando chega aqui, e a
---mensagem sai três vezes bem espaçadas só como seguro: a página ignora conteúdo repetido.
local function sendScene(renderer, data)
    renderer.generation = (renderer.generation or 0) + 1
    local generation = renderer.generation

    -- Um renderer reaproveitado ainda mostra o texto da tag anterior, e só nesse caso vale
    -- segurar o desenho — num DUI novo não há nada a esconder.
    renderer.stale = generation > 1
    renderer.staleUntil = GetGameTimer() + REPAINT_GRACE

    local message = json.encode({ action = 'setSceneData', payload = {
        text = data.text,
        font = data.font,
        color = data.color,
        thickness = data.thickness or Config.Thickness.default,
    } })

    CreateThread(function()
        for _ = 1, 3 do
            if not renderers[renderer.token] or renderer.generation ~= generation then return end
            SendDuiMessage(renderer.dui, message)
            Wait(1000)
        end
    end)
end

-- Uma criação por vez. Duas subindo juntas passam do teto, e é a quantidade de CEF vivo que
-- faz a criação de textura falhar em primeiro lugar.
local creating = false

---Sobe um DUI e amarra a textura nele.
---
---A ordem aqui é o ponto todo, e é onde este resource divergia do upstream. O `lib.dui` do
---ox_lib chama `CreateRuntimeTextureFromDuiHandle` no mesmo instante do `CreateDui`, sem
---esperar nada: a textura nasce amarrada a uma superfície que o CEF ainda não entregou, e
---fica registrada assim. O dicionário existe — o `HasStreamedTextureDictLoaded` responde
---que sim, como respondeu no diagnóstico — mas a textura dentro dele não resolve, e desenhar
---com ela é o índice -1 do dump. Por isso o DUI é criado na mão: esperar ficar disponível
---primeiro, criar dicionário e textura só depois.
---
---O nome carrega o relógio do jogo, como o do ox_lib carrega. Eu tinha trocado por nome
---fixo por vaga para não deixar dicionário órfão — mas dicionário de runtime também não tem
---native de destruição, então o do restart anterior continua registrado, com uma textura
---apontando para um DUI que já morreu. Recriar com o mesmo nome esbarra nesse cadáver, e um
---`noir_graffiti_txd_1` de duas sessões atrás é exatamente o tipo de nome que resolve para
---índice -1 na hora de desenhar. Nome novo a cada criação vaza um dicionário por vaga por
---sessão, que é um preço pequeno perto disso.
local function spawnRenderer()
    if creating or liveCount >= Config.Render.maxActive then return end
    if GetGameTimer() < blockedUntil then return end
    creating = true

    local token = nextToken + 1
    local dui = CreateDui(('nui://%s/web/scene.html'):format(cache.resource),
        Config.Render.width, Config.Render.height)

    local timeout = GetGameTimer() + 5000
    while not IsDuiAvailable(dui) and GetGameTimer() < timeout do
        Wait(25)
    end

    local function fail(reason)
        blockedUntil = GetGameTimer() + 10000
        print(('[noir_graffiti] %s; novas tentativas em 10s'):format(reason))
        discard(dui)
        creating = false
    end

    if not IsDuiAvailable(dui) then
        fail('o DUI não ficou disponível em 5s')
        return
    end

    local stamp = GetGameTimer()
    local dict = ('noir_graffiti_txd_%d_%d'):format(stamp, token)
    local txt = ('noir_graffiti_txt_%d_%d'):format(stamp, token)

    local txd = CreateRuntimeTxd(dict)
    if not txd or txd == 0 then
        fail('dicionário de runtime não criado')
        return
    end

    local texture = CreateRuntimeTextureFromDuiHandle(txd, txt, GetDuiHandle(dui))
    if not texture or texture == 0 then
        fail('textura de runtime não criada')
        return
    end

    nextToken = token
    local renderer = { dui = dui, token = token, dict = dict, txt = txt }
    renderers[token] = renderer
    liveCount = liveCount + 1
    creating = false
    return renderer
end

---@param urgent? boolean a prévia espera, e se precisar toma a vaga de um graffiti
---@return table? renderer { dui, dict, txt }
function NoirGraffiti.AcquireRenderer(data, urgent)
    local renderer = table.remove(idle)

    if not renderer and urgent then
        -- Uma vaga pode estar subindo neste instante; esperar é melhor que negar a prévia.
        while creating do Wait(50) end
        renderer = table.remove(idle)
    end

    if not renderer then renderer = spawnRenderer() end

    if not renderer and urgent and evict() then
        -- A prévia é o que o jogador está fazendo agora, e não pode falhar porque a rua está
        -- cheia de tags: a mais distante cede o renderer e volta a desenhar no fim.
        renderer = table.remove(idle)
    end

    if not renderer then return end
    sendScene(renderer, data)
    return renderer
end

---Devolve para a pilha em vez de destruir. Quem chama precisa largar a referência: a
---partir daqui o renderer pertence à próxima tag que precisar dele.
function NoirGraffiti.ReleaseRenderer(renderer)
    if not renderer or not renderers[renderer.token] then return end
    for i = 1, #idle do
        if idle[i] == renderer then return end
    end
    idle[#idle + 1] = renderer
end

---Duas checagens, com pesos diferentes.
---
---A obrigatória é o CEF estar entregando a superfície. Ela é refeita a cada frame, e não
---guardada: um CEF sob pressão de memória morre sozinho, sem avisar ninguém, e continuar
---desenhando a textura dele é a mesma violação de acesso do dump.
---
---A outra é acabamento: num renderer reaproveitado, desenhar antes de a página repintar
---mostra o texto da tag anterior. Ela tem prazo, e o prazo é um palpite — do outro lado não
---há ninguém para confirmar.
---@return boolean
function NoirGraffiti.CanDraw(renderer)
    if not renderer then return false end
    if renderer.stale then
        if GetGameTimer() < renderer.staleUntil then return false end
        renderer.stale = false
    end
    return IsDuiAvailable(renderer.dui)
end

-- Renderer pronto nunca é destruído. O `CreateRuntimeTxd` que o acompanha não tem native de
-- destruição, e o pool para em `maxActive`: os ociosos ficam parados, que é o estado barato.

---O resource parando sem destruir os DUIs deixaria um navegador vivo por vaga a cada
---restart. O ox_lib fazia esta faxina sozinho; criando na mão, ela é nossa.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for _, renderer in pairs(renderers) do
        DestroyDui(renderer.dui)
    end
end)

-- Graffitis do mundo ----------------------------------------------------------------

local function stopRender(graffiti)
    if not graffiti.renderer then return end
    NoirGraffiti.ReleaseRenderer(graffiti.renderer)
    graffiti.renderer = nil
end

local function startRender(graffiti)
    if graffiti.renderer then return end
    graffiti.renderer = NoirGraffiti.AcquireRenderer(graffiti)
end

---Quem está mais longe é quem menos perde ao ficar sem desenho por um instante.
function evict()
    local coords = GetEntityCoords(cache.ped)
    local farthest, farthestDistance
    for _, graffiti in pairs(NoirGraffiti.All) do
        if graffiti.renderer then
            local distance = #(coords - graffiti.coords)
            if not farthestDistance or distance > farthestDistance then
                farthest, farthestDistance = graffiti, distance
            end
        end
    end
    if not farthest then return false end
    stopRender(farthest)
    return true
end

---Graffiti mais próximo do jogador dentro do alcance. É por proximidade e não por mira:
---o removedor é um produto que se passa na parede, não uma arma que se aponta.
local function nearest(maxDistance)
    local coords = GetEntityCoords(cache.ped)
    local best, bestDistance
    for _, graffiti in pairs(NoirGraffiti.All) do
        local distance = #(coords - graffiti.coords)
        if distance <= maxDistance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = graffiti, distance
        end
    end
    return best
end

local removing = false

exports('useRemover', function()
    if removing then
        return lib.notify({ description = 'Você já está removendo um graffiti.', type = 'error' })
    end

    local graffiti = nearest(Config.Remove.useDistance)
    if not graffiti then
        return lib.notify({ description = 'Nenhum graffiti por perto.', type = 'error' })
    end

    -- O pcall garante que o sinalizador nunca fique preso: se a barra ou o callback
    -- estourarem, o removedor volta a funcionar em vez de emudecer para sempre.
    removing = true
    -- Sem prop e sem animação, aqui e no posicionamento. O crash só aparecia na janela da
    -- barra de progresso, e prop e dicionário de animação são a única coisa que o resource
    -- pede ao jogo exclusivamente nessa janela — no Enhanced eles podem nem estar no build,
    -- e modelo sem txd residente rende a busca de textura que devolve -1 dos dumps. A barra
    -- roda limpa: é meio segundo de enfeite contra o cliente inteiro.
    local ok, result = pcall(function()
        local completed = lib.progressCircle({
            duration = Config.Remove.duration,
            label = 'Removendo graffiti',
            position = 'bottom',
            canCancel = true,
            disable = { move = true, car = true, combat = true },
        })
        if not completed then return end
        return lib.callback.await('noir_graffiti:server:remove', false, graffiti.id)
    end)
    removing = false

    if not ok then
        print(('[noir_graffiti] erro ao remover: %s'):format(result))
        return lib.notify({ description = 'Erro ao remover o graffiti.', type = 'error' })
    end
    if result == nil then return end -- barra cancelada

    lib.notify({
        description = result.success and 'Graffiti removido.' or (result.error or 'Não foi possível remover.'),
        type = result.success and 'success' or 'error',
    })
end)

function NoirGraffiti.Remove(id)
    id = tonumber(id)
    local graffiti = id and NoirGraffiti.All[id]
    if not graffiti then return end
    stopRender(graffiti)
    NoirGraffiti.All[id] = nil
end

---Quem está desenhando agora. A thread de desenho não decide nada: ela percorre esta lista
---e mais nada.
local visible = {}

---Quanto mais perto uma tag sem vaga precisa estar para tomar o lugar de uma que já está
---desenhando. É a histerese que separa "dar a vaga para quem está na cara do jogador" de
---"trocar de renderer a cada varredura" — sem margem nenhuma, duas tags a distâncias
---parecidas se revezam para sempre, e cada troca é uma página inteira redesenhada dentro do
---CEF, que é a tag piscando na parede.
---
---Três metros é curto o bastante para a tag recém-pichada, que nasce a dois passos do
---jogador, tomar a vaga de uma do outro lado da rua; e longo o bastante para duas tags da
---mesma parede nunca disputarem entre si.
local PREEMPT_MARGIN = 3.0

---Escolhe quem fica com os renderers.
---
---Vaga só muda de dono quando quem está esperando está claramente mais perto que quem está
---segurando. Já foi das duas maneiras erradas: redistribuir por proximidade a cada varredura
---fazia a tag piscar, e nunca redistribuir fazia a tag recém-pichada não aparecer — a vaga
---que a prévia devolve é tomada por uma vizinha nos cinco segundos da barra de progresso, e
---sem tomada de vaga a tag nova esperava o jogador andar 75 metros para ter a sua.
---
---Isto já foi o `lib.points` do ox_lib, que chama o callback de cada ponto uma vez por
---frame — inclusive o de quem está longe demais para desenhar. Era esse custo que crescia em
---linha reta no monitor conforme as tags se acumulavam na mesma área.
local function pickVisible()
    local coords = GetEntityCoords(cache.ped)
    local holders, waiting = {}, {}

    for _, graffiti in pairs(NoirGraffiti.All) do
        graffiti.distance = #(coords - graffiti.coords)
        if graffiti.renderer then
            -- A saída é mais longe que a entrada. Essa folga é o que impede a tag de largar
            -- e pegar renderer sem parar com o jogador andando em cima da fronteira.
            if graffiti.distance > Config.Render.unloadDistance then
                stopRender(graffiti)
            else
                holders[#holders + 1] = graffiti
            end
        elseif graffiti.distance <= Config.Render.distance then
            waiting[#waiting + 1] = graffiti
        end
    end

    if #waiting > 0 then
        table.sort(waiting, function(a, b) return a.distance < b.distance end)
        -- Mais longe primeiro: é quem cede a vaga.
        table.sort(holders, function(a, b) return a.distance > b.distance end)

        local next_ = 1
        for i = 1, #waiting do
            local graffiti = waiting[i]
            -- Subir um DUI leva segundos, e nesse tempo a tag pode ter sido apagada. Sem
            -- esta conferência o renderer iria para uma tabela órfã, fora de All, e ninguém
            -- mais o devolveria para a pilha.
            if NoirGraffiti.All[graffiti.id] ~= graffiti then break end

            startRender(graffiti)

            if not graffiti.renderer then
                local holder = holders[next_]
                -- A fila está em ordem de proximidade: se esta não merece tomar a vaga, as
                -- seguintes, que estão mais longe, também não.
                if not holder or holder.distance <= graffiti.distance + PREEMPT_MARGIN then break end
                stopRender(holder)
                next_ = next_ + 1
                startRender(graffiti)
                if not graffiti.renderer then break end
            end
        end
    end

    local list = {}
    for _, graffiti in pairs(NoirGraffiti.All) do
        if graffiti.renderer then list[#list + 1] = graffiti end
    end
    visible = list
end

CreateThread(function()
    while true do
        pickVisible()
        Wait(300)
    end
end)

CreateThread(function()
    while true do
        local list = visible
        local count = #list

        for i = 1, count do
            local entry = list[i]
            -- A lista tem até 300ms de idade: a tag pode ter sido apagada nesse intervalo,
            -- e o renderer dela já pertencer a outra.
            if NoirGraffiti.drawEnabled and NoirGraffiti.All[entry.id] == entry
                and NoirGraffiti.CanDraw(entry.renderer) then
                Geometry.drawMarker(entry.coords, entry.euler, entry.scale,
                    entry.renderer.dict, entry.renderer.txt)
            end
        end

        -- Sem nada na tela a thread sai do caminho; o intervalo é curto para a primeira
        -- tag da lista não esperar meio segundo para aparecer.
        Wait(count > 0 and 0 or 250)
    end
end)

---Diagnóstico do estado real, para olhar depois de um crash em vez de adivinhar: quantas
---tags existem, quantas desenham, e o que o jogo acha de cada textura.
---Liga e desliga o desenho sem reiniciar nada. Os DUIs continuam nascendo, recebendo
---conteúdo e sendo reaproveitados; só a chamada de desenho some. É o teste que separa
---"o crash é a nossa textura" de "o crash é de outro lugar", e ele não dá para deduzir
---lendo código.
RegisterCommand('graffitidraw', function()
    NoirGraffiti.drawEnabled = not NoirGraffiti.drawEnabled
    print(('[noir_graffiti] desenho %s'):format(NoirGraffiti.drawEnabled and 'LIGADO' or 'DESLIGADO'))
end, false)

RegisterCommand('graffitistats', function()
    local total = 0
    for _ in pairs(NoirGraffiti.All) do total = total + 1 end

    -- O glm entra na conta porque sem ele a orientação cai no fallback, que deita a tag.
    print(('[noir_graffiti] tags=%d desenhando=%d duis=%d ociosos=%d bloqueado=%s glm=%s'):format(
        total, #visible, liveCount, #idle,
        GetGameTimer() < blockedUntil and 'sim' or 'nao',
        glm and 'sim' or 'nao'))

    for token, renderer in pairs(renderers) do
        print(('  dui #%d disponivel=%s txd_carregado=%s escondido=%s'):format(
            token,
            tostring(IsDuiAvailable(renderer.dui)),
            tostring(HasStreamedTextureDictLoaded(renderer.dict)),
            tostring(renderer.stale and GetGameTimer() < renderer.staleUntil or false)))
    end
end, false)

function NoirGraffiti.Upsert(data)
    if type(data) ~= 'table' or not data.coords or not data.normal then return end
    -- Sem id numérico não há o que indexar, e `All[nil]` estoura.
    local id = tonumber(data.id)
    if not id then return end
    data.id = id
    NoirGraffiti.Remove(id)
    data.coords = vector3(data.coords.x + 0.0, data.coords.y + 0.0, data.coords.z + 0.0)
    data.normal = normalize(vector3(data.normal.x + 0.0, data.normal.y + 0.0, data.normal.z + 0.0))
    data.rotation = tonumber(data.rotation) or 0.0
    data.scale = tonumber(data.scale) or 1.0
    data.thickness = tonumber(data.thickness) or Config.Thickness.default
    data.euler = Geometry.markerRotation(data.normal, data.rotation)
    NoirGraffiti.All[data.id] = data
end

RegisterNetEvent('noir_graffiti:client:setAll', function(rows)
    local received = {}
    for _, row in ipairs(rows or {}) do
        received[tonumber(row.id)] = true
        NoirGraffiti.Upsert(row)
    end
    for id in pairs(NoirGraffiti.All) do
        if not received[id] then NoirGraffiti.Remove(id) end
    end
end)

RegisterNetEvent('noir_graffiti:client:add', NoirGraffiti.Upsert)
RegisterNetEvent('noir_graffiti:client:remove', NoirGraffiti.Remove)
