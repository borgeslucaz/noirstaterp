---Persistência das definições. Hoje em JSON dentro do resource; a interface (list, load,
---save, remove) é o que o resto do resource conhece, então trocar por banco é trocar este
---arquivo.
---
---Os arquivos ficam em missions/<id>.json e o índice em missions/index.json. O índice existe
---porque o servidor não lista diretório: sem ele, missão salva não seria encontrada depois
---de um restart.
local Config = require 'config.server'

local Storage = {}

local RESOURCE = GetCurrentResourceName()
local DIRECTORY = Config.storage.directory

local function path(id) return ('%s/%s.json'):format(DIRECTORY, id) end

local function readJson(file)
    local raw = LoadResourceFile(RESOURCE, file)
    if not raw or raw == '' then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        lib.print.error(('[noir_missions] JSON inválido em %s'):format(file))
        return nil
    end
    return decoded
end

---No Enhanced o native devolve 1/0, não booleano (como o IsPlayerAceAllowed): comparar com
---`== true` dava falha numa gravação que tinha dado certo.
---@return boolean
local function saveFile(file, content)
    local result = SaveResourceFile(RESOURCE, file, content, -1)
    return result == true or result == 1
end

local function writeJson(file, value)
    local ok, encoded = pcall(json.encode, value, { indent = true })
    if not ok then return false end
    return saveFile(file, encoded)
end

---@return string[]
function Storage.list()
    local index = readJson(('%s/index.json'):format(DIRECTORY))
    local ids = {}
    if type(index) == 'table' and type(index.missions) == 'table' then
        for i = 1, #index.missions do
            if type(index.missions[i]) == 'string' then ids[#ids + 1] = index.missions[i] end
        end
    end
    return ids
end

---@param ids string[]
local function writeIndex(ids)
    table.sort(ids)
    return writeJson(('%s/index.json'):format(DIRECTORY), { missions = ids })
end

---@param id string
---@return table?
function Storage.load(id)
    return readJson(path(id))
end

---@param id string
---@param record table
---@return boolean
function Storage.save(id, record)
    if not writeJson(path(id), record) then return false end
    local ids = Storage.list()
    for i = 1, #ids do
        if ids[i] == id then return true end
    end
    ids[#ids + 1] = id
    return writeIndex(ids)
end

---Remove do índice. O arquivo fica vazio em vez de apagado: o servidor não apaga arquivo,
---e um JSON vazio é ignorado no load.
---@param id string
---@return boolean
function Storage.remove(id)
    local ids = Storage.list()
    local kept = {}
    for i = 1, #ids do
        if ids[i] ~= id then kept[#kept + 1] = ids[i] end
    end
    saveFile(path(id), '')
    return writeIndex(kept)
end

return Storage
