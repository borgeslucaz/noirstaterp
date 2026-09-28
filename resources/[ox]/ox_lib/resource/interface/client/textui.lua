--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@class TextUIOptions
---@field position? 'right-center' | 'left-center' | 'top-center' | 'bottom-center';
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string;
---@field style? string | table;
---@field alignIcon? 'top' | 'center';
---@field key? string tecla na caixa à esquerda do texto

local isOpen = false
local currentText

-- O textUI daqui desenha a tecla numa caixa própria (options.key). Muito resource ainda escreve
-- a tecla no texto ("[E] Abrir", "[E] - Abrir", "E - Abrir", "[~g~E~w~] Bater", "Pressione [E]
-- para abrir"): sem key a caixa fica vazia. Aqui a tecla sai do texto e vira key, para todo
-- chamador, sem mexer em locale de ninguém. Texto com várias teclas fica como está.
---@param text string
---@return string? key, string? rest
local function extractKey(text)
    local clean = text:gsub('~%a~', '')
    local key, rest = clean:match('^%s*%[([^%]]+)%]%s*%-?%s*(.+)$')
    if not key then key, rest = clean:match('^%s*(%w)%s+%-%s+(.+)$') end
    if not key then
        key, rest = clean:match('^%s*[Pp]ressione%s+%[?([%w]+)%]?%s+para%s+(.+)$')
        if rest then rest = rest:gsub('^%l', string.upper) end
    end
    if not key or rest:find('%[') then return end
    return key, rest
end

---@param text string
---@param options? TextUIOptions
function lib.showTextUI(text, options)
    if currentText == text then return end

    -- cópia: vários chamadores passam a mesma tabela de config a cada chamada
    options = options and table.clone(options) or {}
    currentText = text

    if not options.key and type(text) == 'string' then
        local key, rest = extractKey(text)
        if key then
            options.key = #key <= 2 and key:upper() or key
            text = rest
        end
    end

    options.text = text

    SendNUIMessage({
        action = 'textUi',
        data = options
    })

    isOpen = true
end

function lib.hideTextUI()
    SendNUIMessage({
        action = 'textUiHide'
    })

    isOpen = false
    currentText = nil
end

---@return boolean, string | nil
function lib.isTextUIOpen()
    return isOpen, currentText
end
