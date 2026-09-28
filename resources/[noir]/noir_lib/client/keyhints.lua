-- Teclas visíveis (DESIGN_v4 §7) para quem não tem NUI própria: "[ESC] FECHAR", "[W] LEVANTAR".
-- Um conjunto na tela por vez; quem mostrou é o dono, e só o dono esconde ou troca.

---@alias NoirKeyHintPosition 'cima' | 'baixo' | 'esquerda' | 'direita'

---@class NoirKeyHint
---@field key string tecla como aparece na pílula ('W', 'Esc', 'Espaço')
---@field label string ação ('Levantar'); a NUI põe em caixa alta

---@class NoirKeyHintsData
---@field position? NoirKeyHintPosition borda da tela; padrão 'baixo'
---@field keys NoirKeyHint[]

local POSITIONS = { cima = true, baixo = true, esquerda = true, direita = true }
local MAX_KEYS = 8

---@type string?
local owner = nil

local function callerResource()
    return GetInvokingResource() or GetCurrentResourceName()
end

---@param data NoirKeyHintsData
---@return NoirKeyHint[]? keys, string? position, string? err
local function validate(data)
    if type(data) ~= 'table' then return nil, nil, 'data precisa ser uma tabela' end

    local position = data.position or 'baixo'
    if not POSITIONS[position] then
        return nil, nil, ('posição inválida %q (use cima, baixo, esquerda ou direita)'):format(tostring(position))
    end

    if type(data.keys) ~= 'table' or #data.keys == 0 then return nil, nil, 'keys precisa ter ao menos uma tecla' end
    if #data.keys > MAX_KEYS then return nil, nil, ('no máximo %d teclas'):format(MAX_KEYS) end

    local keys = {}
    for i, hint in ipairs(data.keys) do
        if type(hint) ~= 'table' or type(hint.key) ~= 'string' or type(hint.label) ~= 'string'
            or hint.key == '' or hint.label == '' then
            return nil, nil, ('keys[%d] precisa de key e label em texto'):format(i)
        end
        keys[i] = { key = hint.key, label = hint.label }
    end

    return keys, position
end

--- Mostra (ou troca) as teclas visíveis.
---@param data NoirKeyHintsData
---@return boolean ok
local function showKeyHints(data)
    local resource = callerResource()
    if owner and owner ~= resource then
        lib.print.warn(('%s tentou mostrar teclas, mas %s já está mostrando'):format(resource, owner))
        return false
    end

    local keys, position, err = validate(data)
    if not keys then
        lib.print.warn(('ShowKeyHints de %s: %s'):format(resource, err))
        return false
    end

    owner = resource
    SendNUIMessage({ action = 'keyhints:show', position = position, keys = keys })
    return true
end

--- Esconde as teclas, se quem chama for quem mostrou.
---@return boolean hidden
local function hideKeyHints()
    if not owner or owner ~= callerResource() then return false end
    owner = nil
    SendNUIMessage({ action = 'keyhints:hide' })
    return true
end

--- As teclas de quem chama estão na tela?
---@return boolean
local function isKeyHintsOpen()
    return owner ~= nil and owner == callerResource()
end

exports('ShowKeyHints', showKeyHints)
exports('HideKeyHints', hideKeyHints)
exports('IsKeyHintsOpen', isKeyHintsOpen)

-- Dono parou sem esconder (restart, crash): não deixa pílula órfã.
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= owner then return end
    owner = nil
    SendNUIMessage({ action = 'keyhints:hide' })
end)
