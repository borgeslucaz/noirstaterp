---Blips e rota do GPS da missão, refeitos a partir do retrato do servidor.
---Blip de entidade (a van) só existe quando a entidade está no escopo deste cliente; até lá
---fica pendente e um laço curto tenta de novo.
local Blips = {}

---@type table<string, { blip: integer?, area: integer?, signature: string, pending: table? }>
local active = {}
local pendingLoop = false

local function remove(entry)
    if entry.blip and DoesBlipExist(entry.blip) then
        SetBlipRoute(entry.blip, false)
        RemoveBlip(entry.blip)
    end
    if entry.area and DoesBlipExist(entry.area) then RemoveBlip(entry.area) end
end

---@param data table
---@return string
local function signature(data)
    -- Blip de entidade: a posição de reserva muda a cada retrato e não pode recriar o blip.
    local coords = data.netId and {} or data.coords or {}
    return ('%s|%s|%s|%s|%s|%s|%s|%s|%s|%s'):format(data.netId or '', coords.x or '', coords.y or '',
        data.sprite or '', data.color or '', data.label or '', tostring(data.route), data.radius or '',
        tostring(data.areaOnly), tostring(data.id))
end

---@param blip integer
---@param data table
local function style(blip, data)
    SetBlipSprite(blip, data.sprite or 1)
    SetBlipColour(blip, data.color or 5)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.label or 'Missão')
    EndTextCommandSetBlipName(blip)
    if data.route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, data.color or 5)
    end
end

---@param data table
---@return table entry
local function create(data)
    local entry = { signature = signature(data) }
    if data.netId then
        if NetworkDoesNetworkIdExist(data.netId) then
            local entity = NetworkGetEntityFromNetworkId(data.netId)
            if entity ~= 0 and DoesEntityExist(entity) then
                entry.blip = AddBlipForEntity(entity)
                style(entry.blip, data)
                return entry
            end
        end
        entry.pending = data
        -- Fora do escopo: blip na última posição conhecida (com rota) até a entidade aparecer.
        if data.coords then
            entry.blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
            style(entry.blip, data)
        end
        return entry
    end
    if data.radius then
        entry.area = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, data.radius + 0.0)
        SetBlipColour(entry.area, data.color or 5)
        SetBlipAlpha(entry.area, 70)
    end
    if not data.areaOnly then
        entry.blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        style(entry.blip, data)
    end
    return entry
end

local function ensurePendingLoop()
    if pendingLoop then return end
    pendingLoop = true
    CreateThread(function()
        while true do
            local waiting = false
            for id, entry in pairs(active) do
                if entry.pending and NetworkDoesNetworkIdExist(entry.pending.netId) then
                    remove(entry)
                    local fresh = create(entry.pending)
                    if fresh.pending then waiting = true end
                    active[id] = fresh
                elseif entry.pending then
                    waiting = true
                end
            end
            if not waiting then break end
            Wait(2000)
        end
        pendingLoop = false
    end)
end

---@param list table[]?
function Blips.sync(list)
    local seen = {}
    for index = 1, #(list or {}) do
        local data = list[index]
        local id = tostring(data.id)
        seen[id] = true
        local current = active[id]
        if not current or current.signature ~= signature(data) then
            if current then remove(current) end
            active[id] = create(data)
        end
    end
    for id, entry in pairs(active) do
        if not seen[id] then
            remove(entry)
            active[id] = nil
        end
    end
    for _, entry in pairs(active) do
        if entry.pending then ensurePendingLoop() break end
    end
end

function Blips.clear()
    for id, entry in pairs(active) do
        remove(entry)
        active[id] = nil
    end
end

return Blips
