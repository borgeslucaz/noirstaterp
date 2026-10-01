-- Normaliza uma semente de dev/seed/ pela mesma validação do editor e grava em missions/.
--   lua5.4 dev/build_seed.lua meth_elysian_precursors
local cache = {}
require = function(path)
    if cache[path] ~= nil then return cache[path] end
    local chunk = assert(loadfile(path:gsub('%.', '/') .. '.lua'))
    cache[path] = chunk()
    return cache[path]
end
local Json = dofile('dev/json.lua')
local Definition = require 'shared.types.definition'

local id = assert(arg[1], 'uso: lua5.4 dev/build_seed.lua <id>')
local raw = dofile(('dev/seed/%s.lua'):format(id))
local def, errors = Definition.normalize(raw)
for index = 1, #errors do
    io.stderr:write(('erro: %s: %s\n'):format(errors[index].path, errors[index].message))
end
if #errors > 0 then os.exit(1) end

local record = {
    id = def.id,
    status = 'draft',
    updatedAt = os.time(),
    updatedBy = 'seed',
    draft = def,
}
local file = assert(io.open(('missions/%s.json'):format(id), 'w'))
file:write(Json.encode(record, true), '\n')
file:close()
print(('missions/%s.json gravado (%d passos, %d gatilhos)'):format(id, #def.steps, #def.triggers))
