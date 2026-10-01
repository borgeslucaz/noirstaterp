-- Encoder JSON mínimo para os scripts de dev (Lua puro, sem o runtime do FiveM).
local Json = {}

local function isArray(value)
    if next(value) == nil then return true end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == #value
end

local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }

local function encode(value, indent, depth)
    local kind = type(value)
    if kind == 'nil' then return 'null' end
    if kind == 'boolean' then return tostring(value) end
    if kind == 'number' then
        if value % 1 == 0 then return ('%d'):format(value) end
        return ('%.4f'):format(value):gsub('0+$', ''):gsub('%.$', '')
    end
    if kind == 'string' then
        return '"' .. value:gsub('[%c"\\]', function(char)
            return escapes[char] or ('\\u%04x'):format(char:byte())
        end) .. '"'
    end
    if kind == 'table' then
        local pad = indent and ('\n' .. (' '):rep(depth * 2 + 2)) or ''
        local close = indent and ('\n' .. (' '):rep(depth * 2)) or ''
        local parts = {}
        if isArray(value) then
            if #value == 0 then return '[]' end
            for index = 1, #value do parts[#parts + 1] = pad .. encode(value[index], indent, depth + 1) end
            return '[' .. table.concat(parts, ',') .. close .. ']'
        end
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        for index = 1, #keys do
            local key = keys[index]
            local inner = value[key]
            if inner == nil then inner = value[tonumber(key)] end
            parts[#parts + 1] = pad .. encode(key) .. (indent and ': ' or ':') .. encode(inner, indent, depth + 1)
        end
        return '{' .. table.concat(parts, ',') .. close .. '}'
    end
    error('tipo não serializável: ' .. kind)
end

function Json.encode(value, pretty) return encode(value, pretty, 0) end

-- Decoder mínimo (testes e scripts de dev). Números, strings com escapes simples, true/false/null.
function Json.decode(text)
    local pos = 1
    local function skip()
        pos = text:find('[^%s]', pos) or (#text + 1)
    end
    local value
    local function str()
        local out = {}
        pos = pos + 1
        while true do
            local char = text:sub(pos, pos)
            if char == '"' then pos = pos + 1 break end
            if char == '\\' then
                local nextChar = text:sub(pos + 1, pos + 1)
                local map = { n = '\n', t = '\t', r = '\r', b = '\b', f = '\f' }
                if nextChar == 'u' then
                    out[#out + 1] = utf8.char(tonumber(text:sub(pos + 2, pos + 5), 16))
                    pos = pos + 6
                else
                    out[#out + 1] = map[nextChar] or nextChar
                    pos = pos + 2
                end
            else
                out[#out + 1] = char
                pos = pos + 1
            end
        end
        return table.concat(out)
    end
    value = function()
        skip()
        local char = text:sub(pos, pos)
        if char == '{' then
            local out = {}
            pos = pos + 1
            skip()
            if text:sub(pos, pos) == '}' then pos = pos + 1 return out end
            while true do
                skip()
                local key = str()
                skip()
                pos = pos + 1 -- :
                out[key] = value()
                skip()
                local sep = text:sub(pos, pos)
                pos = pos + 1
                if sep == '}' then return out end
            end
        elseif char == '[' then
            local out = {}
            pos = pos + 1
            skip()
            if text:sub(pos, pos) == ']' then pos = pos + 1 return out end
            while true do
                out[#out + 1] = value()
                skip()
                local sep = text:sub(pos, pos)
                pos = pos + 1
                if sep == ']' then return out end
            end
        elseif char == '"' then
            return str()
        elseif text:sub(pos, pos + 3) == 'true' then
            pos = pos + 4 return true
        elseif text:sub(pos, pos + 4) == 'false' then
            pos = pos + 5 return false
        elseif text:sub(pos, pos + 3) == 'null' then
            pos = pos + 4 return nil
        end
        local number = text:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
        pos = pos + #number
        return tonumber(number)
    end
    return value()
end

return Json
