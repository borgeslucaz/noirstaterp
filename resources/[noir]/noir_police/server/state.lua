---Estado autoritativo de contenção: quem está algemado, escoltado ou carregado.
---
---A verdade mora nestas tabelas. O state bag é só o espelho que o cliente lê para
---desenhar; se um cliente mexer no próprio state bag, o servidor regrava (ver o
---handler no fim do arquivo) e nada aqui é lido de volta do state bag.

local Integrations = require 'server.integrations'

local State = {
    ---@type table<integer, { type: 'cuffs'|'zipties', angle: 'front'|'back' }>
    cuffed = {},
    ---@type table<integer, integer> alvo -> quem escolta
    escortedBy = {},
    ---@type table<integer, integer> quem escolta -> alvo
    escorting = {},
    ---@type table<integer, integer> alvo -> quem carrega
    carriedBy = {},
    ---@type table<integer, integer> quem carrega -> alvo
    carrying = {},
    ---@type table<integer, boolean> ação de contenção em andamento
    busy = {},
}

local CUFF_METADATA = 'noir_police_cuff'

local function mirror(source, key, value)
    local player = Player(source)
    if player and player.state then player.state:set(key, value, true) end
end

---@param source integer
---@return boolean
function State.isCuffed(source)
    return State.cuffed[source] ~= nil
end

---@param source integer
---@return boolean
function State.isRestrained(source)
    return State.cuffed[source] ~= nil or State.escortedBy[source] ~= nil or State.carriedBy[source] ~= nil
end

---Algema e persiste. `persist = false` quando é a reaplicação do login.
---@param source integer
---@param cuffType 'cuffs'|'zipties'
---@param angle 'front'|'back'
---@param persist? boolean
function State.cuff(source, cuffType, angle, persist)
    State.cuffed[source] = { type = cuffType, angle = angle }
    mirror(source, 'isCuffed', true)
    mirror(source, 'cuffType', cuffType)
    mirror(source, 'cuffAngle', angle)
    mirror(source, 'invBusy', true)
    if persist ~= false then
        Integrations.setMetadata(source, 'ishandcuffed', true)
        Integrations.setMetadata(source, CUFF_METADATA, { type = cuffType, angle = angle })
    end
    TriggerClientEvent('noir_police:client:setCuffed', source, true, cuffType, angle)
end

---@param source integer
function State.uncuff(source)
    local wasCuffed = State.cuffed[source] ~= nil
    State.cuffed[source] = nil
    mirror(source, 'isCuffed', false)
    mirror(source, 'cuffType', false)
    mirror(source, 'cuffAngle', false)
    mirror(source, 'invBusy', false)
    Integrations.setMetadata(source, 'ishandcuffed', false)
    Integrations.setMetadata(source, CUFF_METADATA, false)
    if wasCuffed then
        TriggerClientEvent('noir_police:client:setCuffed', source, false)
    end
end

---Solta a escolta em que o jogador estiver, dos dois lados.
---@param source integer
function State.releaseEscort(source)
    local target = State.escorting[source]
    if target then
        State.escorting[source] = nil
        State.escortedBy[target] = nil
        mirror(target, 'isEscorted', false)
    end
    local escorter = State.escortedBy[source]
    if escorter then
        State.escortedBy[source] = nil
        State.escorting[escorter] = nil
        mirror(source, 'isEscorted', false)
        TriggerClientEvent('noir_police:client:escortEnded', escorter)
    end
end

---@param source integer
function State.releaseCarry(source)
    local target = State.carrying[source]
    if target then
        State.carrying[source] = nil
        State.carriedBy[target] = nil
        mirror(target, 'isCarried', false)
        TriggerClientEvent('noir_police:client:carryEnded', source)
    end
    local carrier = State.carriedBy[source]
    if carrier then
        State.carriedBy[source] = nil
        State.carrying[carrier] = nil
        mirror(source, 'isCarried', false)
        TriggerClientEvent('noir_police:client:carryEnded', carrier)
    end
end

---@param source integer
function State.releaseAll(source)
    State.releaseEscort(source)
    State.releaseCarry(source)
end

---Descarregou o personagem sem sair do servidor: limpa o espelho sem mexer no
---metadata salvo (a algema volta no próximo login desse personagem).
---@param source integer
function State.forget(source)
    State.releaseAll(source)
    State.cuffed[source] = nil
    State.busy[source] = nil
    for _, key in ipairs({ 'isCuffed', 'cuffType', 'cuffAngle', 'invBusy', 'isEscorted', 'isCarried' }) do
        mirror(source, key, false)
    end
    TriggerClientEvent('noir_police:client:setCuffed', source, false)
end

---Reaplica a algema salva no login. Sair do jogo algemado não solta ninguém.
---@param source integer
function State.restore(source)
    local saved = Integrations.getMetadata(source, CUFF_METADATA)
    if type(saved) ~= 'table' then return end
    local cuffType = saved.type == 'zipties' and 'zipties' or 'cuffs'
    local angle = saved.angle == 'front' and 'front' or 'back'
    State.cuff(source, cuffType, angle, false)
end

---Cliente mexeu no próprio state bag de contenção: o servidor regrava.
local guarded = { isCuffed = true, cuffType = true, isEscorted = true, isCarried = true }

local function expected(source, key)
    local cuff = State.cuffed[source]
    if key == 'isCuffed' then return cuff ~= nil end
    if key == 'cuffType' then return cuff and cuff.type or false end
    if key == 'isEscorted' then return State.escortedBy[source] or false end
    if key == 'isCarried' then return State.carriedBy[source] or false end
end

for key in pairs(guarded) do
    AddStateBagChangeHandler(key, nil, function(bagName, _, value)
        -- As escritas do próprio servidor batem com as tabelas e saem aqui.
        local source = GetPlayerFromStateBagName(bagName)
        if not source or source == 0 then return end
        local want = expected(source, key)
        if value == want or (not value and not want) then return end
        -- Escrita que não veio do servidor. Regrava fora do handler.
        SetTimeout(0, function()
            if GetPlayerPing(source) == 0 then return end
            mirror(source, key, expected(source, key))
        end)
        Integrations.log(source, 'statebag_tamper', ('%s=%s, esperado %s'):format(key, tostring(value), tostring(want)))
    end)
end

-- Restart do resource: as tabelas zeraram, mas os state bags e o metadata ficaram.
-- Reconstrói a algema pelo metadata e solta escolta e ombro, que não persistem.
CreateThread(function()
    Wait(1000)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then
            for _, key in ipairs({ 'isEscorted', 'isCarried', 'isCuffed', 'cuffType', 'cuffAngle', 'invBusy' }) do
                mirror(src, key, false)
            end
            if Integrations.getCitizenId(src) then State.restore(src) end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    State.releaseAll(src)
    State.cuffed[src] = nil
    State.busy[src] = nil
end)

return State
