---Editor in-game (/editortaxi): tudo passa pela ACE, pelo rate limit e pela validação do
---server/catalog.lua. A tela monta o rascunho; aqui ele é conferido inteiro de novo e cada
---gravação fica em taxijob_editor_log.

local ED = ServerConfig.Editor

local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, ED.AdminAce)
end

---Número inteiro vindo da NUI: o JSON pode chegar como 5.0.
local function intId(value)
    return type(value) == 'number' and math.tointeger(value) or nil
end

---@return table? refusal
local function guard(source, save)
    if not isAdmin(source) then return { ok = false, code = 'not_allowed' } end
    if not Catalog.ready then return { ok = false, code = 'storage_unavailable' } end
    if save and not Security.rateLimit(source, 'editorSave', ED.SaveIntervalMs) then return { ok = false, code = 'busy' } end
end

local function audit(source, action, entity, entityId, data)
    local player = Integrations.character(source)
    Catalog.log(player and player.citizenId or nil, GetPlayerName(source), action, entity, entityId, data and json.encode(data) or nil)
    print(('[noir_taxijob] editor: %s %s %s por %s'):format(action, entity, tostring(entityId), GetPlayerName(source)))
end

local function saved(extra)
    local result = { ok = true, catalog = Catalog.adminView() }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end

lib.addCommand(ED.Command, { help = 'Editor da central de táxi (admin)' }, function(source)
    if not isAdmin(source) then return end
    if not Catalog.ready then
        Integrations.notify(source, 'O catálogo do táxi ainda não carregou.', 'error')
        return
    end
    TriggerClientEvent('noir_taxijob:client:openEditor', source)
end)

lib.callback.register('noir_taxijob:server:editor:data', function(source)
    return guard(source) or saved()
end)

lib.callback.register('noir_taxijob:server:editor:savePoint', function(source, id, point)
    local refused = guard(source, true)
    if refused then return refused end
    if id ~= nil then
        id = intId(id)
        if not id then return { ok = false, code = 'invalid_payload' } end
    end
    local savedId, code = Catalog.savePoint(id, point)
    if not savedId then return { ok = false, code = code } end
    audit(source, id and 'update' or 'create', 'point', savedId, Catalog.point(savedId))
    return saved({ id = savedId })
end)

lib.callback.register('noir_taxijob:server:editor:deletePoint', function(source, id)
    local refused = guard(source, true)
    if refused then return refused end
    id = intId(id)
    if not id then return { ok = false, code = 'invalid_payload' } end
    local before = Catalog.point(id)
    local ok, code = Catalog.deletePoint(id)
    if not ok then return { ok = false, code = code } end
    audit(source, 'delete', 'point', id, before)
    return saved()
end)

lib.callback.register('noir_taxijob:server:editor:saveVehicle', function(source, isNew, vehicle)
    local refused = guard(source, true)
    if refused then return refused end
    local id, code = Catalog.saveVehicle(isNew == true, vehicle)
    if not id then return { ok = false, code = code } end
    audit(source, isNew and 'create' or 'update', 'vehicle', id, vehicle)
    return saved({ id = id })
end)

lib.callback.register('noir_taxijob:server:editor:deleteVehicle', function(source, id)
    local refused = guard(source, true)
    if refused then return refused end
    if type(id) ~= 'string' or #id > 24 then return { ok = false, code = 'invalid_payload' } end
    local ok, code = Catalog.deleteVehicle(id)
    if not ok then return { ok = false, code = code } end
    audit(source, 'delete', 'vehicle', id)
    return saved()
end)

lib.callback.register('noir_taxijob:server:editor:moveVehicle', function(source, id, delta)
    local refused = guard(source, true)
    if refused then return refused end
    if type(id) ~= 'string' or #id > 24 or (delta ~= 1 and delta ~= -1) then return { ok = false, code = 'invalid_payload' } end
    local ok, code = Catalog.moveVehicle(id, delta)
    if not ok then return { ok = false, code = code } end
    audit(source, 'move', 'vehicle', id, { delta = delta })
    return saved()
end)

lib.callback.register('noir_taxijob:server:editor:saveLevels', function(source, levels)
    local refused = guard(source, true)
    if refused then return refused end
    local ok, code = Catalog.saveLevels(levels)
    if not ok then return { ok = false, code = code } end
    audit(source, 'update', 'levels', 'all', levels)
    return saved()
end)

lib.callback.register('noir_taxijob:server:editor:saveDepot', function(source, depot)
    local refused = guard(source, true)
    if refused then return refused end
    local ok, code = Catalog.saveDepot(depot)
    if not ok then return { ok = false, code = code } end
    audit(source, 'update', 'depot', 'all', depot)
    return saved()
end)

lib.callback.register('noir_taxijob:server:editor:saveSettings', function(source, values)
    local refused = guard(source, true)
    if refused then return refused end
    local ok, code = Catalog.saveSettings(values)
    if not ok then return { ok = false, code = code } end
    audit(source, 'update', 'settings', 'all', values)
    return saved()
end)

local function planar(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

---"Ir até": o client teleporta só depois de o servidor confirmar que é admin e que o destino é
---um ponto do catálogo, a Central, uma vaga, ou um lugar livre perto de um deles.
lib.callback.register('noir_taxijob:server:editor:teleport', function(source, kind, id, point)
    local refused = guard(source)
    if refused then return refused end
    local depot = Catalog.depot()
    if kind == 'point' then
        local p = Catalog.point(intId(id) or -1)
        if not p then return { ok = false, code = 'unknown_point' } end
        return { ok = true, point = { x = p.x, y = p.y, z = p.z, w = p.w } }
    elseif kind == 'depot' then
        return { ok = true, point = depot.ped }
    elseif kind == 'free' and type(point) == 'table' and tonumber(point.x) and tonumber(point.y) and tonumber(point.z) then
        local target = { x = tonumber(point.x), y = tonumber(point.y), z = tonumber(point.z), w = tonumber(point.w) or 0.0 }
        local near = planar(target, depot.ped) <= ED.TeleportNear
        for _, spawn in ipairs(depot.spawnPoints) do near = near or planar(target, spawn) <= ED.TeleportNear end
        for _, p in ipairs(Catalog.adminView().points) do
            if near then break end
            near = planar(target, p) <= ED.TeleportNear
        end
        if not near then return { ok = false, code = 'too_far' } end
        return { ok = true, point = target }
    end
    return { ok = false, code = 'invalid_payload' }
end)
