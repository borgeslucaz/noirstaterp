---Editor de missões: abre a NUI (só se o servidor confirmar a ACE), repassa os callbacks da
---página para o servidor e cuida do que é do mundo (posicionar, teleportar, prévia, debug).
local ClientConfig = require 'config.client'
local Schema = require 'shared.types.schema'
local Nui = require 'client.runtime.nui'
local Integrations = require 'client.integrations'
local Placement = require 'client.editor.placement'
local Debug = require 'client.editor.debug'
local Vehicles = require 'client.vehicles.ai'

local Editor = {}

local open = false
local preview = nil ---@type { entity: integer, token: table }?

---@param name string
---@param ... any
---@return table
local function server(name, ...)
    local result = lib.callback.await('noir_missions:server:' .. name, false, ...)
    return type(result) == 'table' and result or { ok = false, code = 'internal_error' }
end

function Editor.open()
    if open then return end
    local result = server('editorOpen')
    if not result.ok then
        Integrations.notify(result.code == 'not_allowed' and 'Sem permissão.' or 'Editor indisponível.', 'error')
        return
    end
    open = true
    Nui.send('editor:open', {
        missions = result.missions,
        instances = result.instances,
        schema = Schema.export(),
        lists = {
            items = result.items or {},
            minigames = Integrations.minigameList(),
            weapons = ClientConfig.weapons,
        },
    })
    Nui.focus('editor', true)
end

function Editor.close()
    if not open then return end
    open = false
    Nui.send('editor:close')
    Nui.focus('editor', false)
    Debug.setMission(false)
end

---@return boolean
function Editor.isOpen() return open end

local function clearPreview()
    if preview then
        Placement.deleteGhost(preview.entity)
        preview = nil
    end
end

-- Callbacks da página. Todo caminho responde (§8.6).

local function forward(nuiName, serverName, pack)
    RegisterNUICallback(nuiName, function(data, cb)
        if not open then return cb({ ok = false, code = 'not_allowed' }) end
        data = type(data) == 'table' and data or {}
        cb(server(serverName, pack(data)))
    end)
end

forward('editorLoad', 'editorLoad', function(data) return data.id end)
forward('editorDelete', 'editorDelete', function(data) return data.id end)
forward('editorStopInstance', 'editorStopInstance', function(data) return data.instanceId end)

RegisterNUICallback('editorCreate', function(data, cb)
    if not open then return cb({ ok = false, code = 'not_allowed' }) end
    cb(server('editorCreate', data.id, data.name))
end)

RegisterNUICallback('editorSave', function(data, cb)
    if not open then return cb({ ok = false, code = 'not_allowed' }) end
    cb(server('editorSave', data.definition))
end)

RegisterNUICallback('editorDuplicate', function(data, cb)
    if not open then return cb({ ok = false, code = 'not_allowed' }) end
    cb(server('editorDuplicate', data.id, data.newId, data.newName))
end)

RegisterNUICallback('editorSetStatus', function(data, cb)
    if not open then return cb({ ok = false, code = 'not_allowed' }) end
    cb(server('editorSetStatus', data.id, data.status))
end)

RegisterNUICallback('editorTest', function(data, cb)
    if not open then return cb({ ok = false, code = 'not_allowed' }) end
    cb(server('editorTest', data.id, data.mode, data.step))
end)

RegisterNUICallback('editorTestTool', function(data, cb)
    if not open then return cb({ ok = false, code = 'not_allowed' }) end
    cb(server('editorTestTool', data.id, data.tool, data.ref))
end)

RegisterNUICallback('editorClose', function(_, cb)
    cb({ ok = true })
    Editor.close()
end)

RegisterNUICallback('editorPlace', function(data, cb)
    if not open or Placement.isActive() then return cb({ ok = false, code = 'busy' }) end
    cb({ ok = true })
    clearPreview()
    Nui.send('editor:placement', { active = true })
    Nui.focus('editor', false)
    Placement.start(data, function(result)
        Nui.send('editor:placementResult', result)
        Nui.send('editor:placement', { active = false })
        if open then Nui.focus('editor', true) end
    end)
end)

RegisterNUICallback('editorTeleport', function(data, cb)
    local position = type(data) == 'table' and data.position
    if not open or type(position) ~= 'table' or not tonumber(position.x) then return cb({ ok = false, code = 'invalid_id' }) end
    cb({ ok = true })
    local ped = cache.ped
    SetEntityCoords(ped, position.x + 0.0, position.y + 0.0, position.z + 0.0, false, false, false, false)
    if tonumber(position.w) then SetEntityHeading(ped, position.w + 0.0) end
end)

RegisterNUICallback('editorPreview', function(data, cb)
    if not open or type(data) ~= 'table' or type(data.position) ~= 'table' then return cb({ ok = false, code = 'invalid_id' }) end
    local model = Placement.validModel(data.kind, data.model)
    if not model then return cb({ ok = false, code = 'invalid_model' }) end
    clearPreview()
    local position = data.position
    local entity = Placement.createGhost(data.kind, model, vector3(position.x, position.y, position.z))
    if not entity then return cb({ ok = false, code = 'invalid_model' }) end
    SetEntityCoordsNoOffset(entity, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(entity, (position.w or 0.0) + 0.0)
    local token = {}
    preview = { entity = entity, token = token }
    SetTimeout(15000, function()
        if preview and preview.token == token then clearPreview() end
    end)
    cb({ ok = true })
end)

RegisterNUICallback('editorValidateModel', function(data, cb)
    if type(data) ~= 'table' then return cb({ ok = false, valid = false }) end
    local kind = data.kind == 'ped' and 'ped' or data.kind == 'vehicle' and 'vehicle' or 'object'
    local valid = Placement.validModel(kind, data.model) ~= nil
    cb({ ok = true, valid = valid, vehicleType = kind == 'vehicle' and valid and Vehicles.serverType(data.model) or nil })
end)

RegisterNUICallback('editorDebug', function(data, cb)
    cb({ ok = true })
    Debug.setMission(type(data) == 'table' and data.enabled == true, data and data.id)
end)

RegisterNetEvent('noir_missions:client:teleport', function(coords)
    if source ~= 65535 or type(coords) ~= 'table' then return end
    SetEntityCoords(cache.ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
end)

function Editor.cleanup()
    clearPreview()
    Debug.clear()
    open = false
end

return Editor
