-- Lata de spray na mão, animação e tinta saindo do bico.
--
-- Isto já foi o `anim` e o `prop` embutidos da `lib.progressCircle`, e saiu quando o crash se
-- mostrou preso à janela da barra de progresso. Voltou como módulo próprio, e a lata local se
-- provou estável — o mesmo modelo e o mesmo dicionário que derrubavam pelo caminho do ox_lib.
-- A diferença está em como o prop chega nos outros jogadores, e por isso a parte remota daqui
-- é escrita com as guardas que faltavam lá: ped conferido antes de anexar, nada bloqueando
-- dentro do handler, e prazo de validade no prop.
--
-- A animação não precisa viajar: `TaskPlayAnim` no próprio ped o servidor replica sozinho.
-- Prop e partícula é que são criados na máquina de cada um.

NoirSpray = {}

local ANIM_DICT = 'anim@scripted@freemode@postertag@graffiti_spray@male@'
local SHAKE_CLIP = 'shake_can_male'
-- Alterna entre as duas para a pintura não ficar com cara de loop de um segundo.
local SPRAY_CLIPS = { 'spray_can_var_01_male', 'spray_can_var_02_male' }

local PROP_NAME = 'prop_cs_spray_can'
local PROP_MODEL = joaat(PROP_NAME)
-- PH_R_Hand: o osso de prop da mão direita, onde o jogo pendura o que o ped segura.
local HAND_BONE = 28422
local PROP_OFFSET = vec3(0.0, 0.0, 0.07)
local PROP_ROTATION = vec3(0.0, 0.0, 0.0)

-- A tinta da missão de graffiti do Lamar. É o efeito que a Rockstar fez para sair de uma lata
-- de spray na mão do jogador, então é aerosol de verdade: fino, curto e discreto. Extintor,
-- vapor e fumaça de oficina são os outros candidatos óbvios do jogo, e os três são grandes
-- demais para caber num bico de lata.
local PTFX_ASSET = 'scr_playerlamgraff'
local PTFX_NAME = 'scr_lamgraff_paint_spray'
-- Posição e direção do jato, em relação à lata. Estes números são um ponto de partida: quem
-- ajusta é o /graffitispray, lá embaixo, porque isso se resolve olhando e não calculando.
local PTFX_OFFSET = vec3(0.0, 0.0, 0.05)
local PTFX_ROTATION = vec3(0.0, 0.0, 0.0)
local PTFX_SCALE = 1.0

local SHAKE_DURATION = 1800 -- Sacudir antes de pintar, como quem chacoalha a lata de verdade.
local CLIP_DURATION = 4000 -- De quanto em quanto tempo troca a variação da pintura.
-- Prazo de validade da lata. É o que garante que ninguém fica com um spray colado na mão
-- porque o aviso de parada se perdeu no caminho — e do lado remoto não há quem conserte.
local LIFETIME = Config.Placement.duration + 3000
-- A sequência é de estado, não de frame: este laço só existe enquanto se está pintando, e
-- serve para trocar de clipe, ver o prazo e perceber morte ou troca de ped. A partícula não
-- depende dele — `StartParticleFxLoopedOnEntity` se sustenta sozinho depois de começar.
local TICK = 250

-- [chave] = sessão. A chave é `false` para a sua lata e o id de servidor para a dos outros.
-- O `token` invalida o que estava em andamento: quem foi disparado por uma pintura anterior
-- confere o seu antes de mexer no ped, no prop ou na partícula.
local sessions = {}
local token = 0

---@return number? r, number? g, number? b componentes de 0 a 1
local function hexToRgb(hex)
    if type(hex) ~= 'string' then return end
    local r, g, b = hex:match('^#?(%x%x)(%x%x)(%x%x)$')
    if not r then return end
    return tonumber(r, 16) / 255.0, tonumber(g, 16) / 255.0, tonumber(b, 16) / 255.0
end

---@return boolean
local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    if not DoesAnimDictExist(dict) then
        print(('[noir_graffiti] dicionário de animação ausente neste build: %s'):format(dict))
        return false
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(0) end

    return HasAnimDictLoaded(dict)
end

---@return boolean
local function loadModel(model)
    if HasModelLoaded(model) then return true end
    if not IsModelValid(model) or not IsModelInCdimage(model) then
        print(('[noir_graffiti] modelo ausente neste build: %s'):format(PROP_NAME))
        return false
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 2000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end

    return HasModelLoaded(model)
end

---A tinta é enfeite: se o asset não existir neste build, a pintura acontece sem ela. É a
---mesma regra do prop e do dicionário — nada que o jogo não tenha entra em cena.
---@return boolean
local function loadPtfxAsset(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do Wait(0) end

    if not HasNamedPtfxAssetLoaded(asset) then
        print(('[noir_graffiti] efeito de partícula ausente neste build: %s'):format(asset))
        return false
    end
    return true
end

---@return number? prop
local function createSprayCan(ped)
    if not loadModel(PROP_MODEL) then return end

    local coords = GetEntityCoords(ped)
    -- Não é objeto de rede: cada cliente cria o seu. Um objeto networked para cinco segundos
    -- de enfeite paga dono, sincronia e um slot de entidade por pintura acontecendo no mapa.
    local prop = CreateObject(PROP_MODEL, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(PROP_MODEL)
    if not prop or prop == 0 or not DoesEntityExist(prop) then return end

    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, HAND_BONE),
        PROP_OFFSET.x, PROP_OFFSET.y, PROP_OFFSET.z,
        PROP_ROTATION.x, PROP_ROTATION.y, PROP_ROTATION.z,
        true, true, false, true, 0, true)

    return prop
end

---O jato nasce na lata, e não no personagem: com o prop como pai, ele acompanha o braço
---sozinho durante a animação, sem ninguém reposicionando nada por frame.
local function startSprayParticles(session, color, offset, rotation, scale)
    if session.fx or not session.prop or not DoesEntityExist(session.prop) then return end
    if not loadPtfxAsset(PTFX_ASSET) then return end

    offset, rotation = offset or PTFX_OFFSET, rotation or PTFX_ROTATION

    UseParticleFxAssetNextCall(PTFX_ASSET)
    local fx = StartParticleFxLoopedOnEntity(PTFX_NAME, session.prop,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        scale or PTFX_SCALE, false, false, false)
    if not fx or fx == 0 then return end

    session.fx = fx

    -- A tinta sai na cor escolhida para o graffiti. Se este efeito não aceitar tintura, o
    -- native não faz nada e a partícula continua na cor original — sem forçar.
    local r, g, b = hexToRgb(color)
    if r then SetParticleFxLoopedColour(fx, r, g, b, false) end
end

local function stopSprayParticles(session)
    if not session.fx then return end
    StopParticleFxLooped(session.fx, false)
    session.fx = nil
end

---Ordem importa: a partícula está pendurada na lata, então parar o jato antes de apagar a
---lata é o que impede o efeito de ficar solto no mundo sem pai.
local function cleanupSpray(key)
    local session = sessions[key]
    if not session then return end
    sessions[key] = nil

    stopSprayParticles(session)

    if session.prop and DoesEntityExist(session.prop) then
        DetachEntity(session.prop, true, true)
        DeleteEntity(session.prop)
    end

    -- Só o dono para as próprias animações: nos outros, quem manda no ped é o cliente deles.
    if key == false and DoesEntityExist(session.ped) then
        StopAnimTask(session.ped, ANIM_DICT, SHAKE_CLIP, 1.0)
        for i = 1, #SPRAY_CLIPS do
            StopAnimTask(session.ped, ANIM_DICT, SPRAY_CLIPS[i], 1.0)
        end
        RemoveAnimDict(ANIM_DICT)
    end

    -- O asset é um só para todas as latas em cena, a sua e as dos outros: soltar enquanto
    -- alguém ainda pinta tiraria a tinta da mão dele.
    if next(sessions) == nil then RemoveNamedPtfxAsset(PTFX_ASSET) end
end

---Flag 49 = em laço, só do tronco para cima e como tarefa secundária: o ped continua de pé
---e olhando para onde o jogador aponta, em vez de virar uma estátua tocando uma cena.
local function playClip(ped, clip, blendIn)
    TaskPlayAnim(ped, ANIM_DICT, clip, blendIn or 3.0, 1.0, -1, 49, 0.0, false, false, false)
end

---@param key false|number false para a própria lata, id de servidor para a dos outros
local function startSession(key, ped, color, tuning)
    cleanupSpray(key)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    token = token + 1
    local mine = token
    local expires = GetGameTimer() + LIFETIME
    local session = { ped = ped, token = mine }
    sessions[key] = session

    -- O carregamento acontece em thread para quem chamou seguir em frente: na primeira
    -- pintura da sessão, esperar dicionário, modelo e efeito travaria a barra de progresso
    -- antes de ela aparecer — e, do lado remoto, travaria um handler de evento.
    CreateThread(function()
        local isOwner = key == false
        if isOwner and not loadAnimDict(ANIM_DICT) then return end
        if sessions[key] ~= session then return end

        local prop = createSprayCan(ped)
        if sessions[key] ~= session then
            -- A pintura acabou enquanto o modelo carregava; o prop nasceu órfão.
            if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
            return
        end
        session.prop = prop

        if isOwner then playClip(ped, SHAKE_CLIP) end

        local variant = 0
        local spraying = false
        -- A tinta só começa quando a lata já foi sacudida e o braço está pintando.
        local nextClip = GetGameTimer() + (tuning and 0 or SHAKE_DURATION)

        while sessions[key] == session do
            if not DoesEntityExist(ped) or GetGameTimer() >= expires
                or (isOwner and (IsEntityDead(ped) or cache.ped ~= ped)) then
                return cleanupSpray(key)
            end

            if GetGameTimer() >= nextClip then
                if not spraying then
                    startSprayParticles(session, color,
                        tuning and tuning.offset, tuning and tuning.rotation, tuning and tuning.scale)
                    if sessions[key] ~= session then return end
                end

                if isOwner then
                    variant = variant % #SPRAY_CLIPS + 1
                    -- Da sacudida para a pintura a mistura é lenta, que é o braço mudando de
                    -- gesto; entre as duas variações é rápida, senão aparece uma quebra no
                    -- meio de um movimento que deveria ser contínuo.
                    playClip(ped, SPRAY_CLIPS[variant], spraying and 8.0 or 2.0)
                end

                spraying = true
                nextClip = GetGameTimer() + CLIP_DURATION
            end

            Wait(TICK)
        end
    end)
end

---@param color? string cor do graffiti, para a tinta sair na mesma
function NoirSpray.startSprayAnimation(color)
    startSession(false, cache.ped, color)
    TriggerServerEvent('noir_graffiti:server:spray', true, color)
end

function NoirSpray.stopSprayAnimation()
    local running = sessions[false] ~= nil
    cleanupSpray(false)
    if running then TriggerServerEvent('noir_graffiti:server:spray', false) end
end

---A lata dos outros. O ped é conferido antes de qualquer coisa: jogador fora de alcance de
---streaming não tem ped, e anexar prop em entidade inexistente é pedir para o render tropeçar
---— foi disso que o caminho do ox_lib não se protegia.
RegisterNetEvent('noir_graffiti:client:spray', function(serverId, active, color)
    if serverId == cache.serverId then return end

    if not active then return cleanupSpray(serverId) end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end

    local ped = GetPlayerPed(player)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    startSession(serverId, ped, color)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for key in pairs(sessions) do cleanupSpray(key) end
end)

---Ajuste do jato, que é coisa de olhar e não de calcular: roda a sequência por dez segundos
---com os valores passados, para acertar de onde a tinta sai e para onde ela aponta sem
---reiniciar nada. Sem argumentos, usa os valores que estão no código.
---
---  /graffitispray 0.0 0.0 0.05 0.0 0.0 0.0 1.0
---   └ deslocamento x y z          └ rotação x y z   └ escala
---
---Quando os números estiverem bons, eles sobem para PTFX_OFFSET, PTFX_ROTATION e PTFX_SCALE
---lá em cima, e este comando some junto com este comentário.
RegisterCommand('graffitispray', function(_, args)
    local n = {}
    for i = 1, 7 do n[i] = tonumber(args[i]) end

    local tuning = {
        offset = vec3(n[1] or PTFX_OFFSET.x, n[2] or PTFX_OFFSET.y, n[3] or PTFX_OFFSET.z),
        rotation = vec3(n[4] or PTFX_ROTATION.x, n[5] or PTFX_ROTATION.y, n[6] or PTFX_ROTATION.z),
        scale = n[7] or PTFX_SCALE,
    }

    print(('[noir_graffiti] jato em offset %.2f %.2f %.2f, rotação %.1f %.1f %.1f, escala %.2f')
        :format(tuning.offset.x, tuning.offset.y, tuning.offset.z,
            tuning.rotation.x, tuning.rotation.y, tuning.rotation.z, tuning.scale))

    startSession(false, cache.ped, Config.DefaultColor, tuning)
    SetTimeout(10000, function() cleanupSpray(false) end)
end, false)
