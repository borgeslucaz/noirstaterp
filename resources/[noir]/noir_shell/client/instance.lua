local ShellInstance = {}
ShellInstance.__index = ShellInstance

function ShellInstance.new(id, model, entity, origin)
    return setmetatable({
        id = id,
        model = model,
        entity = entity,
        origin = origin,
        destroyed = false,
    }, ShellInstance)
end

function ShellInstance:IsValid()
    return not self.destroyed and self.entity ~= 0 and DoesEntityExist(self.entity)
end

function ShellInstance:GetEntity()
    return self.entity
end

function ShellInstance:GetOrigin()
    return self.origin
end

-- Converts a shell-relative offset (vec3) into a world-space vector3.
function ShellInstance:GetOffset(offset)
    if not self:IsValid() then
        Utils.debugPrint('GetOffset called on invalid shell', self.id)
        return nil
    end

    return GetOffsetFromEntityInWorldCoords(self.entity, offset.x, offset.y, offset.z)
end

-- params = { offset = vec3, heading = number (optional, relative to shell heading) }
-- returns { coords = vec3, heading = number } or nil
function ShellInstance:GetOffsetTransform(params)
    if not self:IsValid() then
        Utils.debugPrint('GetOffsetTransform called on invalid shell', self.id)
        return nil
    end

    local coords = self:GetOffset(params.offset)

    if not coords then
        return nil
    end

    local heading = self.origin.w or 0.0

    if params.heading then
        heading = (heading + params.heading) % 360.0
    end

    return {
        coords = coords,
        heading = heading,
    }
end

-- offset is a vec4 (x, y, z relative to the shell, w = absolute heading to apply)
function ShellInstance:TeleportPed(ped, offset)
    if not self:IsValid() then
        Utils.debugPrint('TeleportPed called on invalid shell', self.id)
        return false
    end

    local coords = self:GetOffset(vec3(offset.x, offset.y, offset.z))

    if not coords then
        return false
    end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)

    if offset.w then
        SetEntityHeading(ped, offset.w)
    end

    return true
end

function ShellInstance:Destroy()
    if self.destroyed then
        return
    end

    self.destroyed = true

    Utils.debugPrint('Destroying shell', self.id, self.entity)

    if self.entity ~= 0 and DoesEntityExist(self.entity) then
        SetEntityAsMissionEntity(self.entity, false, true)
        DeleteEntity(self.entity)
    end

    self.entity = 0

    Manager.Unregister(self.id)
end

Instance = {
    new = ShellInstance.new,
}
