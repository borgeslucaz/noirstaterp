---Texto com variáveis: `Lote {{cargo_batch}} no {{warehouse}}`.
---
---Só substituição. Não há expressão, chamada nem laço: o texto vem do editor de admin e vai
---para a tela de jogadores, então nada nele é executado.
local Template = {}

---@param value any
---@return string
local function display(value)
    if value == nil then return '' end
    if type(value) == 'boolean' then return value and 'sim' or 'não' end
    if type(value) == 'number' then
        if value % 1 == 0 then return ('%d'):format(value) end
        return ('%.2f'):format(value)
    end
    if type(value) == 'table' then
        if value.label then return tostring(value.label) end
        return ''
    end
    return tostring(value)
end

---@param text any
---@param resolve fun(name: string): any
---@return string
function Template.render(text, resolve)
    if type(text) ~= 'string' or text == '' then return '' end
    return (text:gsub('{{%s*([%w_%.%-]+)%s*}}', function(name)
        return display(resolve(name))
    end))
end

---Nomes usados num texto, para o editor avisar de variável que não existe.
---@param text any
---@return string[]
function Template.names(text)
    local names = {}
    if type(text) ~= 'string' then return names end
    for name in text:gmatch('{{%s*([%w_%.%-]+)%s*}}') do names[#names + 1] = name end
    return names
end

return Template
