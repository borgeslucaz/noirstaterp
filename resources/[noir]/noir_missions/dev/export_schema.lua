-- Gera dev/schema.json a partir do esquema real, para o preview da NUI no navegador.
--   lua5.4 dev/export_schema.lua > dev/schema.json
package.path = './?.lua;' .. package.path
local cache = {}
require = function(path)
    if cache[path] ~= nil then return cache[path] end
    local file = path:gsub('%.', '/') .. '.lua'
    local chunk = assert(loadfile(file))
    cache[path] = chunk()
    return cache[path]
end
local Json = dofile('dev/json.lua')
local Schema = require 'shared.types.schema'
io.write(Json.encode(Schema.export(), true), '\n')
