NoirGraffiti = NoirGraffiti or {}
NoirGraffiti.All = NoirGraffiti.All or {}
NoirGraffiti.Geometry = NoirGraffiti.Geometry or {}

local Geometry = NoirGraffiti.Geometry
local renderers, freeSlots, pendingReady = {}, {}, {}
local active = {}

for i = Config.Render.maxActive, 1, -1 do freeSlots[#freeSlots + 1] = i end

local function normalize(v)
    local length = #(v)
    if length < 0.0001 then return vector3(1.0, 0.0, 0.0) end
    return v / length
end

function Geometry.basis(normal, rotation)
    normal = normalize(normal)
    local right = normalize(vector3(-normal.y, normal.x, 0.0))
    local up = normalize(vector3(
        normal.y * right.z - normal.z * right.y,
        normal.z * right.x - normal.x * right.z,
        normal.x * right.y - normal.y * right.x
    ))
    local angle = math.rad(rotation or 0.0)
    local cosine, sine = math.cos(angle), math.sin(angle)
    return normalize(right * cosine + up * sine), normalize(up * cosine - right * sine)
end

function Geometry.corners(coords, normal, scale, rotation)
    local right, up = Geometry.basis(normal, rotation)
    local halfWidth = Config.Render.baseWorldWidth * scale * 0.5
    local halfHeight = halfWidth * (Config.Render.height / Config.Render.width)
    return {
        topLeft = coords - right * halfWidth + up * halfHeight,
        topRight = coords + right * halfWidth + up * halfHeight,
        bottomLeft = coords - right * halfWidth - up * halfHeight,
        bottomRight = coords + right * halfWidth - up * halfHeight,
    }
end

function Geometry.draw(corners, txd, txn, alpha)
    alpha = alpha or 255
    DrawSpritePoly(
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        corners.topRight.x, corners.topRight.y, corners.topRight.z,
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        255, 255, 255, alpha, txd, txn,
        0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0
    )
    DrawSpritePoly(
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z,
        255, 255, 255, alpha, txd, txn,
        0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0
    )
    -- Sprite polys are single-sided. Draw the reverse winding too so the DUI
    -- remains visible regardless of the map surface normal orientation.
    DrawSpritePoly(
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        corners.topRight.x, corners.topRight.y, corners.topRight.z,
        255, 255, 255, alpha, txd, txn,
        0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0
    )
    DrawSpritePoly(
        corners.topLeft.x, corners.topLeft.y, corners.topLeft.z,
        corners.bottomLeft.x, corners.bottomLeft.y, corners.bottomLeft.z,
        corners.bottomRight.x, corners.bottomRight.y, corners.bottomRight.z,
        255, 255, 255, alpha, txd, txn,
        0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0
    )
end

local function displayData(graffiti)
    return {
        text = graffiti.text,
        font = graffiti.font,
        fontSize = 128,
        fontColor = graffiti.color,
        fontOutline = 'none',
        fontOutlineColor = '#000000',
        fontStyle = 'normal',
        background = 'empty',
    }
end

local function rendererUrl(name)
    return ('nui://%s/web/scene.html?renderer=%s'):format(GetCurrentResourceName(), name)
end

RegisterNUICallback('sceneDui:ready', function(data, cb)
    local name = data and data.renderer
    if name and renderers[name] then renderers[name].ready = true
    elseif name then pendingReady[name] = true end
    cb('ok')
end)

function NoirGraffiti.CreateRenderer(name, graffiti)
    local dui = CreateDui(rendererUrl(name), Config.Render.width, Config.Render.height)
    local timeout = GetGameTimer() + 5000
    while not IsDuiAvailable(dui) and GetGameTimer() < timeout do Wait(25) end
    local handle = GetDuiHandle(dui)
    if not handle or handle == '' then DestroyDui(dui) return end

    local txd, txn = 'noir_graffiti_txd_' .. name, 'noir_graffiti_txn_' .. name
    local txdObject = CreateRuntimeTxd(txd)
    CreateRuntimeTextureFromDuiHandle(txdObject, txn, handle)
    renderers[name] = { dui = dui, txd = txd, txn = txn, ready = pendingReady[name] == true }
    pendingReady[name] = nil

    local readyTimeout = GetGameTimer() + 3000
    while renderers[name] and not renderers[name].ready and GetGameTimer() < readyTimeout do Wait(25) end
    if not renderers[name] then return end
    SendDuiMessage(dui, json.encode({ action = 'setSceneData', payload = displayData(graffiti) }))
    SendDuiMessage(dui, json.encode({ action = 'setVisible', payload = true }))
    return renderers[name]
end

function NoirGraffiti.DestroyRenderer(name)
    local renderer = renderers[name]
    if renderer and renderer.dui then DestroyDui(renderer.dui) end
    renderers[name] = nil
end

function NoirGraffiti.UpdateRenderer(name, graffiti)
    local renderer = renderers[name]
    if not renderer then return end
    SendDuiMessage(renderer.dui, json.encode({ action = 'setSceneData', payload = displayData(graffiti) }))
    SendDuiMessage(renderer.dui, json.encode({ action = 'setVisible', payload = true }))
end

local function startRender(graffiti)
    if graffiti.renderer or graffiti.loading then return end
    local slot = table.remove(freeSlots)
    if not slot then return end
    graffiti.loading = true
    local name = tostring(slot)
    local renderer = NoirGraffiti.CreateRenderer(name, graffiti)
    graffiti.loading = nil
    if not renderer or not NoirGraffiti.All[graffiti.id] then
        NoirGraffiti.DestroyRenderer(name)
        freeSlots[#freeSlots + 1] = slot
        return
    end
    graffiti.renderer, graffiti.slot = renderer, slot
end

local function stopRender(graffiti)
    if not graffiti.renderer then return end
    NoirGraffiti.DestroyRenderer(tostring(graffiti.slot))
    freeSlots[#freeSlots + 1] = graffiti.slot
    graffiti.renderer, graffiti.slot = nil, nil
end

function NoirGraffiti.Upsert(data)
    if type(data) ~= 'table' or not data.id or not data.coords or not data.normal then return end
    local old = NoirGraffiti.All[data.id]
    if old then stopRender(old) end
    data.id = tonumber(data.id)
    data.coords = vector3(data.coords.x + 0.0, data.coords.y + 0.0, data.coords.z + 0.0)
    data.normal = normalize(vector3(data.normal.x + 0.0, data.normal.y + 0.0, data.normal.z + 0.0))
    data.scale, data.rotation = tonumber(data.scale) or 1.0, tonumber(data.rotation) or 0.0
    data.corners = Geometry.corners(data.coords, data.normal, data.scale, data.rotation)
    NoirGraffiti.All[data.id] = data
    if NoirGraffiti.AddTarget then NoirGraffiti.AddTarget(data) end
end

function NoirGraffiti.Remove(id)
    id = tonumber(id)
    local graffiti = id and NoirGraffiti.All[id]
    if not graffiti then return end
    stopRender(graffiti)
    if NoirGraffiti.RemoveTarget then NoirGraffiti.RemoveTarget(id) end
    NoirGraffiti.All[id] = nil
end

RegisterNetEvent('noir_graffiti:client:setAll', function(rows)
    local retained = {}
    for _, row in ipairs(rows or {}) do retained[tonumber(row.id)] = true; NoirGraffiti.Upsert(row) end
    local remove = {}
    for id in pairs(NoirGraffiti.All) do if not retained[id] then remove[#remove + 1] = id end end
    for _, id in ipairs(remove) do NoirGraffiti.Remove(id) end
end)

RegisterNetEvent('noir_graffiti:client:add', NoirGraffiti.Upsert)
RegisterNetEvent('noir_graffiti:client:remove', NoirGraffiti.Remove)

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearby = {}
        for _, graffiti in pairs(NoirGraffiti.All) do
            nearby[#nearby + 1] = { graffiti = graffiti, distance = #(playerCoords - graffiti.coords) }
        end
        table.sort(nearby, function(a, b) return a.distance < b.distance end)
        active = {}
        for index, entry in ipairs(nearby) do
            local graffiti, distance = entry.graffiti, entry.distance
            if index <= Config.Render.maxActive and distance <= Config.Render.distance then
                active[graffiti.id] = true
                startRender(graffiti)
            elseif graffiti.renderer and (distance >= Config.Render.unloadDistance or index > Config.Render.maxActive) then
                stopRender(graffiti)
            end
        end
        Wait(Config.Render.checkInterval)
    end
end)

CreateThread(function()
    while true do
        local wait = 500
        for id in pairs(active) do
            local graffiti = NoirGraffiti.All[id]
            if graffiti and graffiti.renderer then
                wait = 0
                Geometry.draw(graffiti.corners, graffiti.renderer.txd, graffiti.renderer.txn)
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for name in pairs(renderers) do NoirGraffiti.DestroyRenderer(name) end
end)
