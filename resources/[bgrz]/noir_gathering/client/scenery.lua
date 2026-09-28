---Props fixos das rotas (a pilha de caixas da carga), vistos por todo mundo que chega
---perto. Cada client cria o seu, local, quando se aproxima, e apaga quando se afasta: não
---há entidade de rede para ficar órfã quando alguém cai. O model vem da lista do config e
---ainda é conferido antes do request — prop que não existe derruba o cliente no Enhanced.

local Scenery = {}

local SPAWN_DISTANCE = 80.0

---@type table<string, { point: table, model: string, entity: integer?, loading: boolean }>
local entries = {}
local running = false

local function despawn(entry)
    if entry.entity and DoesEntityExist(entry.entity) then
        SetEntityAsMissionEntity(entry.entity, true, true)
        DeleteObject(entry.entity)
    end
    entry.entity = nil
end

local function spawn(key, entry)
    entry.loading = true
    CreateThread(function()
        local model = joaat(entry.model)
        local ready = IsModelInCdimage(model) and pcall(lib.requestModel, model, 5000)
        if not ready or entries[key] ~= entry then
            entry.loading = false
            return
        end
        local p = entry.point
        local entity = CreateObject(model, p.x, p.y, p.z, false, false, false)
        SetModelAsNoLongerNeeded(model)
        entry.loading = false
        if entity == 0 then return end
        SetEntityHeading(entity, p.w or 0.0)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        entry.entity = entity
    end)
end

local function watch()
    if running then return end
    running = true
    CreateThread(function()
        while next(entries) do
            local coords = GetEntityCoords(cache.ped)
            for key, entry in pairs(entries) do
                local close = #(coords - vector3(entry.point.x, entry.point.y, entry.point.z)) <= SPAWN_DISTANCE
                if close and not entry.entity and not entry.loading then
                    spawn(key, entry)
                elseif not close and entry.entity then
                    despawn(entry)
                end
            end
            Wait(1000)
        end
        running = false
    end)
end

---@param key string
---@param point { x: number, y: number, z: number, w: number }
---@param model string
function Scenery.add(key, point, model)
    Scenery.remove(key)
    entries[key] = { point = point, model = model, loading = false }
    watch()
end

---@param key string
function Scenery.remove(key)
    local entry = entries[key]
    if not entry then return end
    entries[key] = nil
    despawn(entry)
end

function Scenery.clear()
    for key in pairs(entries) do Scenery.remove(key) end
end

return Scenery
