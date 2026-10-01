---Layout vivo do servidor: delegacias, radares, câmeras e shotspotter.
---
---Carrega do banco (`noir_police_layout`); o que não tiver linha vem do config, que
---vira só semente. Publica no GlobalState o que o cliente precisa desenhar (o
---shotspotter fica só no servidor) e é o único lugar que os módulos consultam.

local Config = require 'config.shared'
local ServerConfig = require 'config.server'
local Codec = require 'shared.layout'
local Storage = require 'server.storage'

local Layout = {}

local plain, decoded = {}, {}

local PUBLIC = { stations = true, radars = true, cameras = true }

local function seed(kind)
    if kind == 'stations' then return Codec.encode.stations(Config.stations) end
    if kind == 'radars' then return Codec.encode.radars(Config.radars.locations) end
    if kind == 'cameras' then return Codec.encode.cameras(Config.securityCameras) end
    return Codec.encode.shotspotter(ServerConfig.shotspotter.locations)
end

local function apply(kind, data)
    plain[kind] = data
    decoded[kind] = Codec.decode[kind](data)
    if PUBLIC[kind] then GlobalState[('noirPolice:%s'):format(kind)] = data end
end

---Carrega tudo. Chamado no boot, depois da migration.
function Layout.load()
    local saved = {}
    local ok, rows = pcall(Storage.loadLayout)
    if ok then saved = rows else lib.print.error(('[noir_police] layout não carregou: %s'):format(rows)) end
    for kind in pairs(Codec.kinds) do
        local data = saved[kind] and json.decode(saved[kind]) or nil
        apply(kind, type(data) == 'table' and data or seed(kind))
    end
end

---@return table[]
function Layout.stations() return decoded.stations or {} end
---@return table[]
function Layout.radars() return decoded.radars or {} end
---@return table[]
function Layout.cameras() return decoded.cameras or {} end
---@return vector3[]
function Layout.shotspotter() return decoded.shotspotter or {} end

---Tudo em formato plano, para o editor.
function Layout.snapshot()
    return { stations = plain.stations, radars = plain.radars, cameras = plain.cameras, shotspotter = plain.shotspotter }
end

---Valida, grava e publica. `data = nil` volta para o config.
---@return boolean ok, string? err
function Layout.save(kind, data, updatedBy)
    if not Codec.kinds[kind] then return false, 'invalid_layout' end
    if data == nil then
        Storage.deleteLayout(kind)
        apply(kind, seed(kind))
        return true
    end
    local clean, err = Codec.validate[kind](data, Config.departments)
    if not clean then return false, err end
    Storage.saveLayout(kind, json.encode(clean), updatedBy)
    apply(kind, clean)
    return true
end

return Layout
