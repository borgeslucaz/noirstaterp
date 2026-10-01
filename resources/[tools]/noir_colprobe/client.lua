---Mede o que segura o personagem: raios para frente em três alturas (todos os tipos, só
---mapa, só objetos), o interior e a sala onde ele está, e os objetos em volta.

local function fmt(v) return ('%.2f %.2f %.2f'):format(v.x, v.y, v.z) end

local function archetype(entity)
    local ok, name = pcall(GetEntityArchetypeName, entity)
    return ok and name ~= '' and name or tostring(GetEntityModel(entity))
end

local function probe(from, to, flags)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, flags, cache.ped, 7)
    local _, hit, hitAt, normal, material, entity = GetShapeTestResultIncludingMaterial(handle)
    if hit ~= 1 then return 'nada' end
    local text = ('bate a %.2f m em %s normal %s material %s'):format(#(hitAt - from), fmt(hitAt), fmt(normal), material)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        text = text .. (' entidade tipo %d %s'):format(GetEntityType(entity), archetype(entity))
    end
    return text
end

RegisterNetEvent('noir_colprobe:run', function()
    local ped = cache.ped
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local lines = {}
    local function add(s) lines[#lines + 1] = s; print(s) end

    add(('pos %s heading %.1f'):format(fmt(pos), GetEntityHeading(ped)))
    add(('colisão carregada em volta: %s | congelado: %s | ped em interior: %s sala %s'):format(
        tostring(HasCollisionLoadedAroundEntity(ped)), tostring(IsEntityPositionFrozen(ped)),
        GetInteriorFromEntity(ped), GetRoomKeyFromEntity(ped)))

    local interior = GetInteriorAtCoords(pos.x, pos.y, pos.z)
    if interior ~= 0 then
        local ipos, hash = GetInteriorLocationAndNamehash(interior)
        add(('interior nas coords: %d hash %s (mrp_house = %s) em %s pronto: %s'):format(interior, hash, `mrp_house`,
            fmt(ipos), tostring(IsInteriorReady(interior))))
    else
        add('interior nas coords: nenhum')
    end

    for _, h in ipairs({ -0.6, 0.0, 0.6 }) do
        local from = vec3(pos.x, pos.y, pos.z + h)
        local to = from + fwd * 2.5
        add(('altura %+.1f | tudo: %s'):format(h, probe(from, to, -1)))
        add(('altura %+.1f | mapa: %s'):format(h, probe(from, to, 1)))
        add(('altura %+.1f | objetos: %s'):format(h, probe(from, to, 16)))
    end

    for _, obj in ipairs(GetGamePool('CObject')) do
        local d = #(GetEntityCoords(obj) - pos)
        if d < 5.0 then
            add(('objeto a %.1f m: %s colisão %s'):format(d, archetype(obj), tostring(not GetEntityCollisionDisabled(obj))))
        end
    end

    TriggerServerEvent('noir_colprobe:report', lines)
    lib.notify({ title = 'colprobe', description = ('%d linhas enviadas ao servidor'):format(#lines) })
end)
