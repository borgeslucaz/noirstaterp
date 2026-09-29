local activeShells = {}

local function unregister(id)
    activeShells[id] = nil
end

local function get(id)
    return activeShells[id]
end

Manager = {
    Unregister = unregister,
    Get = get,
}

-- definition = { model = hash|string, origin = vec4, modelLoadTimeout = number?, collisionTimeout = number? }
-- returns shell, nil on success or nil, errorReason on failure
local function create(definition)
    if type(definition) ~= 'table' then
        return nil, 'invalid_definition'
    end

    local origin = definition.origin or Config.DefaultOrigin

    if not Utils.isValidOrigin(origin) then
        return nil, 'invalid_origin'
    end

    Utils.debugPrint('Loading model', definition.model)

    local hash, loadErr = Utils.loadModel(definition.model, definition.modelLoadTimeout)

    if not hash then
        Utils.debugPrint(('Failed to create shell: %s (%s)'):format(loadErr, tostring(definition.model)))
        return nil, loadErr
    end

    Utils.debugPrint('Model loaded', hash)
    Utils.debugPrint(('Creating shell at %.2f %.2f %.2f'):format(origin.x, origin.y, origin.z))

    local entity = CreateObject(hash, origin.x, origin.y, origin.z, false, false, false)

    SetModelAsNoLongerNeeded(hash)

    if not entity or entity == 0 then
        return nil, 'create_object_failed'
    end

    SetEntityHeading(entity, origin.w or 0.0)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)

    Utils.debugPrint('Shell entity created:', entity)
    Utils.debugPrint('Waiting for collision')

    local hasCollision = Collision.request(entity, definition.collisionTimeout)

    if not hasCollision then
        Utils.debugPrint('Collision timeout, destroying shell', entity)
        SetEntityAsMissionEntity(entity, false, true)
        DeleteEntity(entity)
        return nil, 'collision_timeout'
    end

    -- Freezing before collision has fully loaded doesn't reliably stick -
    -- once the collision streams in, physics can reassert itself and drop
    -- the shell. Re-freeze now that collision is confirmed.
    FreezeEntityPosition(entity, true)

    Utils.debugPrint('Collision ready')

    local id = Utils.generateId()
    local instance = Instance.new(id, hash, entity, origin)

    activeShells[id] = instance

    -- Belt-and-suspenders: a frozen local entity can occasionally get
    -- unfrozen (nearby collisions, streaming hiccups) and silently start
    -- falling. Periodically confirm it's still frozen for as long as the
    -- shell is active.
    CreateThread(function()
        while not instance.destroyed do
            Wait(5000)

            if not instance.destroyed and DoesEntityExist(entity) and not IsEntityPositionFrozen(entity) then
                Utils.debugPrint('Shell was unfrozen, re-freezing', id, entity)
                FreezeEntityPosition(entity, true)
            end
        end
    end)

    Utils.debugPrint('Shell ready', id)

    return instance
end

-- overrides is an optional table merged on top of the registered definition (e.g. { origin = ... })
local function createFromDefinition(name, overrides)
    local definition = Config.Shells[name]

    if not definition then
        return nil, 'unknown_definition'
    end

    local merged = {}

    for k, v in pairs(definition) do
        merged[k] = v
    end

    if overrides then
        for k, v in pairs(overrides) do
            merged[k] = v
        end
    end

    return create(merged)
end

local function destroyAll()
    for _, instance in pairs(activeShells) do
        instance:Destroy()
    end

    activeShells = {}
end

local function getActiveInstances()
    local list = {}

    for _, instance in pairs(activeShells) do
        list[#list + 1] = instance
    end

    return list
end

Manager.Create = create
Manager.CreateFromDefinition = createFromDefinition
Manager.DestroyAll = destroyAll
Manager.GetActiveInstances = getActiveInstances

-- Exported functions cross the resource boundary through Citizen's export
-- serialization, which strips metatables from returned tables. Shell
-- instances (and their :Method() API) only work inside this resource, so the
-- public export surface is id-based: Create returns a plain id, and every
-- other operation takes that id and looks the instance back up here.
-- Consumers inside this resource (e.g. client/dev.lua) should call
-- Manager.Create/etc directly instead of going through exports.

exports('Create', function(definition)
    local instance, err = create(definition)

    if not instance then
        return nil, err
    end

    return instance.id
end)

exports('CreateFromDefinition', function(name, overrides)
    local instance, err = createFromDefinition(name, overrides)

    if not instance then
        return nil, err
    end

    return instance.id
end)

exports('GetEntity', function(id)
    local instance = get(id)

    return instance and instance:GetEntity() or nil
end)

exports('GetOrigin', function(id)
    local instance = get(id)

    return instance and instance:GetOrigin() or nil
end)

exports('GetOffset', function(id, offset)
    local instance = get(id)

    return instance and instance:GetOffset(offset) or nil
end)

exports('GetOffsetTransform', function(id, params)
    local instance = get(id)

    return instance and instance:GetOffsetTransform(params) or nil
end)

exports('TeleportPed', function(id, ped, offset)
    local instance = get(id)

    if not instance then
        return false
    end

    return instance:TeleportPed(ped, offset)
end)

exports('Destroy', function(id)
    local instance = get(id)

    if instance then
        instance:Destroy()
    end
end)

exports('IsValid', function(id)
    local instance = get(id)

    return instance ~= nil and instance:IsValid()
end)

exports('DestroyAll', destroyAll)

exports('GetActiveInstances', function()
    local ids = {}

    for id in pairs(activeShells) do
        ids[#ids + 1] = id
    end

    return ids
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    destroyAll()
end)
