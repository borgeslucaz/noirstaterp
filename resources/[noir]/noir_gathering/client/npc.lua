---NPC do início da rota: PED local, parado, criado só quando o jogador chega perto e
---apagado quando se afasta, como o atendente do noir_garage. O model é conferido antes do
---request: model que não existe derruba o cliente no Enhanced.

local Config = require 'config.shared'
local Integrations = require 'client.integrations'

local Npc = {}

local SPAWN_DISTANCE = 60.0

---@type table<string, { point: table, npc: table, options: table[], ped: integer?, loading: boolean }>
local entries = {}
local running = false

local function despawn(entry)
    if not entry.ped then return end
    Integrations.removeEntityTarget(entry.ped)
    if DoesEntityExist(entry.ped) then
        SetEntityAsMissionEntity(entry.ped, true, true)
        DeleteEntity(entry.ped)
    end
    entry.ped = nil
end

local function spawn(key, entry)
    entry.loading = true
    CreateThread(function()
        local model = joaat(entry.npc.model)
        local ready = IsModelInCdimage(model) and IsModelAPed(model) and pcall(lib.requestModel, model, 5000)
        -- A rota pode ter sido redesenhada enquanto o model carregava.
        if not ready or entries[key] ~= entry then
            entry.loading = false
            if not ready then lib.print.warn(('NPC com model inexistente: %s'):format(entry.npc.model)) end
            return
        end
        local p = entry.point
        local ped = CreatePed(4, model, p.x, p.y, p.z - 1.0, p.w or 0.0, false, false)
        SetModelAsNoLongerNeeded(model)
        entry.loading = false
        if ped == 0 then return end
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        TaskStartScenarioInPlace(ped, entry.npc.scenario or Config.haul.npcScenario, 0, true)
        entry.ped = ped
        if #entry.options > 0 then Integrations.addEntityTarget(ped, entry.options) end
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
                if close and not entry.ped and not entry.loading then
                    spawn(key, entry)
                elseif not close and entry.ped then
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
---@param npc { model: string, scenario: string? }
---@param options table[] opções de alvo no NPC
function Npc.add(key, point, npc, options)
    Npc.remove(key)
    entries[key] = { point = point, npc = npc, options = options, loading = false }
    watch()
end

---@param key string
function Npc.remove(key)
    local entry = entries[key]
    if not entry then return end
    entries[key] = nil
    despawn(entry)
end

function Npc.clear()
    for key in pairs(entries) do Npc.remove(key) end
end

return Npc
