-- Fala do ped: um balão acima da cabeça, em vez de uma notificação no canto. "Quero essa
-- merda não, vou chamar a polícia" no NPC que recusou diz a mesma coisa que o aviso, e fica
-- na cena. Um balão por ped; fala nova no mesmo ped troca a anterior. Só quem chama vê.

---@alias NoirSpeechTone 'neutral' | 'alert'

---@class NoirPedSayOptions
---@field duration? integer ms na tela; padrão pelo tamanho do texto (3,5 a 7 s)
---@field tone? NoirSpeechTone 'alert' marca o balão em vermelho (ameaça, polícia)
---@field offset? number metros acima do centro da cabeça; padrão 0.28
---@field maxDistance? number metros até onde aparece; padrão 15

local MAX_TEXT = 140
local MAX_BUBBLES = 8
local HEAD_BONE = 31086 -- SKEL_Head
local VISIBILITY_EVERY_MS = 200
local TONES = { neutral = true, alert = true }

---@class NoirBubble
---@field id integer
---@field ped integer
---@field owner string
---@field expires integer
---@field offset number
---@field maxDistance number
---@field visible boolean
---@field lastX number?
---@field lastY number?
---@field lastScale number?

---@type table<integer, NoirBubble>
local bubbles = {}
local count = 0
local nextId = 0
local running = false

local function callerResource()
    return GetInvokingResource() or GetCurrentResourceName()
end

---@param id integer
local function removeBubble(id)
    if not bubbles[id] then return end
    bubbles[id] = nil
    count = count - 1
    SendNUIMessage({ action = 'speech:remove', id = id })
end

---@param ped integer
---@return integer?
local function bubbleOf(ped)
    for id, bubble in pairs(bubbles) do
        if bubble.ped == ped then return id end
    end
    return nil
end

---Balão fora de vista: ped longe, atrás de parede ou fora da tela não mostra nada.
---@param bubble NoirBubble
---@param camera vector3
---@return boolean
local function inSight(bubble, camera)
    local head = GetPedBoneCoords(bubble.ped, HEAD_BONE, 0.0, 0.0, 0.0)
    if #(camera - head) > bubble.maxDistance then return false end
    return HasEntityClearLosToEntity(cache.ped, bubble.ped, 17)
end

-- Um loop só, vivo enquanto houver balão: posição a cada frame (o balão acompanha a cabeça),
-- visibilidade a cada 200 ms (a linha de visão custa mais que a conta de tela).
local function run()
    if running then return end
    running = true
    CreateThread(function()
        local lastCheck = 0
        while count > 0 do
            local now = GetGameTimer()
            local camera = GetFinalRenderedCamCoord()
            local checkSight = now - lastCheck >= VISIBILITY_EVERY_MS
            if checkSight then lastCheck = now end

            local frame = {}
            for id, bubble in pairs(bubbles) do
                if now >= bubble.expires or not DoesEntityExist(bubble.ped) then
                    removeBubble(id)
                else
                    if checkSight then bubble.visible = inSight(bubble, camera) end
                    -- O deslocamento do GetPedBoneCoords é nos eixos do osso, e o Z da cabeça
                    -- aponta para o lado: a altura soma no eixo vertical do mundo.
                    local head = GetPedBoneCoords(bubble.ped, HEAD_BONE, 0.0, 0.0, 0.0) + vec3(0.0, 0.0, bubble.offset)
                    local onScreen, x, y = GetScreenCoordFromWorldCoord(head.x, head.y, head.z)
                    local show = bubble.visible and onScreen
                    -- Mais longe, menor: de 100% colado a 75% no limite.
                    local distance = #(camera - head)
                    local scale = 1.0 - math.min(distance / bubble.maxDistance, 1.0) * 0.25
                    local sx, sy = show and x or -1, show and y or -1
                    if sx ~= bubble.lastX or sy ~= bubble.lastY or scale ~= bubble.lastScale then
                        bubble.lastX, bubble.lastY, bubble.lastScale = sx, sy, scale
                        frame[#frame + 1] = { id = id, x = sx, y = sy, scale = scale, visible = show }
                    end
                end
            end
            if #frame > 0 then SendNUIMessage({ action = 'speech:frame', items = frame }) end
            Wait(0)
        end
        running = false
    end)
end

---@param text string | string[]
---@return string? text, string? err
local function pickText(text)
    if type(text) == 'table' then
        if #text == 0 then return nil, 'lista de falas vazia' end
        text = text[math.random(#text)]
    end
    if type(text) ~= 'string' or text == '' then return nil, 'fala precisa ser um texto ou uma lista de textos' end
    if #text > MAX_TEXT then return nil, ('fala acima de %d caracteres'):format(MAX_TEXT) end
    return text
end

--- Mostra um balão de fala acima da cabeça do ped. Com uma lista, sorteia uma das falas.
---@param ped integer
---@param text string | string[]
---@param options? NoirPedSayOptions
---@return integer? id do balão, ou nil (dados inválidos; o motivo vai para o F8)
local function pedSay(ped, text, options)
    local resource = callerResource()
    if type(ped) ~= 'number' or not DoesEntityExist(ped) or not IsEntityAPed(ped) then
        lib.print.warn(('PedSay de %s: ped inválido'):format(resource))
        return nil
    end
    local picked, err = pickText(text)
    if not picked then
        lib.print.warn(('PedSay de %s: %s'):format(resource, err))
        return nil
    end
    options = type(options) == 'table' and options or {}
    local tone = TONES[options.tone] and options.tone or 'neutral'
    local duration = tonumber(options.duration) or math.min(7000, math.max(3500, 1500 + #picked * 80))

    local previous = bubbleOf(ped)
    if previous then removeBubble(previous) end
    if count >= MAX_BUBBLES then
        -- Cheio: sai o que vence antes.
        local oldest
        for id, bubble in pairs(bubbles) do
            if not oldest or bubble.expires < bubbles[oldest].expires then oldest = id end
        end
        removeBubble(oldest)
    end

    nextId = nextId + 1
    bubbles[nextId] = {
        id = nextId,
        ped = ped,
        owner = resource,
        expires = GetGameTimer() + duration,
        offset = tonumber(options.offset) or 0.28,
        maxDistance = tonumber(options.maxDistance) or 15.0,
        visible = false,
    }
    count = count + 1
    SendNUIMessage({ action = 'speech:add', id = nextId, text = picked, tone = tone })
    run()
    return nextId
end

--- Tira o balão antes da hora: pelo id que o PedSay devolveu ou pelo ped.
---@param target integer id ou ped
---@return boolean removed
local function pedSayStop(target)
    local id = bubbles[target] and target or bubbleOf(target)
    if not id then return false end
    removeBubble(id)
    return true
end

--- O ped está com um balão na tela?
---@param ped integer
---@return boolean
local function isPedSaying(ped)
    return bubbleOf(ped) ~= nil
end

exports('PedSay', pedSay)
exports('PedSayStop', pedSayStop)
exports('IsPedSaying', isPedSaying)

-- Quem criou parou (restart, crash): os balões dele somem junto.
AddEventHandler('onClientResourceStop', function(resource)
    for id, bubble in pairs(bubbles) do
        if bubble.owner == resource then removeBubble(id) end
    end
end)
