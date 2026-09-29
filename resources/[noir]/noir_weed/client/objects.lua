---Props locais desenhados perto do jogador — plantas e mesas. Nenhuma entidade de rede:
---cada client cria o prop quando entra no raio e apaga quando sai.

local Shared = require 'config.shared'
local Integrations = require 'client.integrations'

local Objects = {}
Objects.__index = Objects

---@param options { model: fun(view: table): integer, targets: fun(id: integer): table[] }
function Objects.new(options)
    return setmetatable({ entries = {}, model = options.model, targets = options.targets }, Objects)
end

local function despawn(entry)
    if not entry.entity then return end
    Integrations.removeEntityTarget(entry.entity)
    if DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
    entry.entity = nil
end

function Objects:spawn(entry)
    despawn(entry)
    local view = entry.view
    local model = self.model(view)
    if not model or not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 5000) then
        lib.print.error(('modelo indisponível: %s'):format(tostring(model)))
        return
    end
    local entity = CreateObjectNoOffset(model, view.x, view.y, view.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if entity == 0 then return end
    SetEntityHeading(entity, view.heading or 0.0)
    FreezeEntityPosition(entity, true)
    entry.entity = entity
    Integrations.addEntityTarget(entity, self.targets(view.id))
end

---Novo, mudou de estágio ou mudou de lugar.
---@param view table
function Objects:upsert(view)
    local entry = self.entries[view.id]
    if entry then
        local moved = entry.view.x ~= view.x or entry.view.y ~= view.y or entry.view.z ~= view.z
        entry.view = view
        if not moved then
            if entry.entity then self:spawn(entry) end
            return
        end
        entry.point:remove()
        despawn(entry)
    else
        entry = { view = view }
        self.entries[view.id] = entry
    end

    entry.point = lib.points.new({
        coords = vector3(view.x, view.y, view.z),
        distance = Shared.renderDistance,
        onEnter = function() self:spawn(entry) end,
        onExit = function() despawn(entry) end,
    })
end

---@param id integer
function Objects:remove(id)
    local entry = self.entries[id]
    if not entry then return end
    despawn(entry)
    if entry.point then entry.point:remove() end
    self.entries[id] = nil
end

function Objects:clear()
    for id in pairs(self.entries) do self:remove(id) end
end

---Só apaga os props, sem mexer na lista (stop do resource).
function Objects:despawnAll()
    for _, entry in pairs(self.entries) do despawn(entry) end
end

---@param id integer
---@return table? view
---@return integer? entity
function Objects:get(id)
    local entry = self.entries[id]
    if not entry then return nil end
    return entry.view, entry.entity
end

return Objects
