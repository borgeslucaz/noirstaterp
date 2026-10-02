-- Faz o caminho inverso do build_seed: lê o rascunho de missions/<id>.json (o que o admin
-- montou no jogo) e grava dev/seed/<id>.lua, para a semente versionada acompanhar o jogo.
--   lua5.4 dev/export_seed.lua meth_elysian_precursors
local Json = dofile('dev/json.lua')

local id = assert(arg[1], 'uso: lua5.4 dev/export_seed.lua <id>')
local record = Json.decode(assert(io.open(('missions/%s.json'):format(id))):read('a'))
local def = assert(record.draft, 'arquivo sem rascunho')

local KEY_ORDER = {
    'id', 'type', 'label', 'name', 'description', 'category', 'difficulty', 'minPlayers', 'maxPlayers',
    'cooldownMinutes', 'timeLimitMinutes', 'gangRequired', 'gangMinGrade', 'participantRadius',
    'start', 'variables', 'zones', 'pedGroups', 'vehicles', 'props', 'cargo', 'interactions',
    'reinforcements', 'chases', 'deliveryGroups', 'steps', 'triggers', 'rewards',
}
local rank = {}
for index, key in ipairs(KEY_ORDER) do rank[key] = index end

local function isArray(value)
    if next(value) == nil then return true end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then return false end
        count = count + 1
    end
    return count == #value
end

local function keyText(key)
    if key:match('^[%a_][%w_]*$') and key ~= 'then' and key ~= 'else' and key ~= 'end' then return key end
    return ('[%q]'):format(key)
end

local function scalar(value)
    if type(value) == 'string' then return ('%q'):format(value):gsub('\\\n', '\\n') end
    if type(value) == 'number' then
        if value % 1 == 0 then return ('%d'):format(value) end
        return (('%.3f'):format(value):gsub('0+$', ''):gsub('%.$', '.0'))
    end
    return tostring(value)
end

local function isPosition(value)
    return type(value) == 'table' and type(value.x) == 'number' and type(value.y) == 'number' and type(value.z) == 'number'
end

local function write(value, indent)
    if type(value) ~= 'table' then return scalar(value) end
    if isPosition(value) then
        return ('{ x = %s, y = %s, z = %s%s }'):format(scalar(value.x), scalar(value.y), scalar(value.z),
            value.w and (', w = ' .. scalar(value.w)) or '')
    end
    local pad = ('    '):rep(indent + 1)
    local close = ('    '):rep(indent)
    if isArray(value) then
        if #value == 0 then return '{}' end
        local simple = true
        for _, item in ipairs(value) do if type(item) == 'table' then simple = false end end
        local parts = {}
        for _, item in ipairs(value) do parts[#parts + 1] = write(item, indent + 1) end
        if simple then return '{ ' .. table.concat(parts, ', ') .. ' }' end
        return '{\n' .. pad .. table.concat(parts, ',\n' .. pad) .. ',\n' .. close .. '}'
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local ra, rb = rank[a] or 1000, rank[b] or 1000
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = ('%s = %s'):format(keyText(key), write(value[key], indent + 1))
    end
    return '{\n' .. pad .. table.concat(parts, ',\n' .. pad) .. ',\n' .. close .. '}'
end

def.schema = nil
local out = assert(io.open(('dev/seed/%s.lua'):format(id), 'w'))
out:write(('-- Semente da missão %s, exportada do rascunho montado no jogo\n'):format(def.name or id))
out:write(('-- (lua5.4 dev/export_seed.lua %s). Para gravar de volta em missions/:\n'):format(id))
out:write(('--   lua5.4 dev/build_seed.lua %s\n\n'):format(id))
out:write('return ', write(def, 0), '\n')
out:close()
print(('dev/seed/%s.lua atualizado'):format(id))
