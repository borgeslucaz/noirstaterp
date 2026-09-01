-- modules/entity_inspector.lua
-- Raycast-based entity inspector with live overlay + per-entity action menu.

SFD = SFD or {}
SFD.Inspector = {}

local active = false
local lastEntity = 0
local lastHit, lastCam

-- ───────────────────────────────────────────────
-- Raycast
-- ───────────────────────────────────────────────
local function performRaycast(distance)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rZ, rX = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.cos(rX)
    local dest = vec3(
        cam.x + (-math.sin(rZ) * cosX) * distance,
        cam.y + ( math.cos(rZ) * cosX) * distance,
        cam.z + ( math.sin(rX))        * distance
    )
    local handle = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local result, hit, endCoords, _, entity = 0
    local tries = 0
    repeat
        result, hit, endCoords, _, entity = GetShapeTestResult(handle)
        tries = tries + 1
        if result == 0 then Wait(0) end
    until result ~= 0 or tries > 50
    return hit == 1, endCoords, entity or 0, cam
end

-- ───────────────────────────────────────────────
-- Entity info builder
-- ───────────────────────────────────────────────
local ENTITY_TYPE_NAMES = { [1] = 'Ped', [2] = 'Vehicle', [3] = 'Object/Prop' }

local function buildEntityInfo(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local etype = GetEntityType(entity)
    local coords = GetEntityCoords(entity)
    local rot    = GetEntityRotation(entity, 2)
    local model  = GetEntityModel(entity)
    local heading = GetEntityHeading(entity)
    local speed  = GetEntitySpeed(entity)
    local netId  = NetworkGetNetworkIdFromEntity(entity)
    local isNet  = NetworkGetEntityIsNetworked(entity)
    local isMission = IsEntityAMissionEntity(entity)
    local frozen = IsEntityPositionFrozen(entity)
    local visible = IsEntityVisible(entity)
    local collision = GetEntityCollisionDisabled(entity) ~= true
    local alpha = GetEntityAlpha(entity)
    local health = GetEntityHealth(entity)
    local pcoords = GetEntityCoords(PlayerPedId())
    local distance = #(pcoords - coords)

    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)

    local owner
    if isNet then
        local ok, p = pcall(NetworkGetEntityOwner, entity)
        if ok then owner = p end
    end

    return {
        entity     = entity,
        type       = etype,
        typeName   = ENTITY_TYPE_NAMES[etype] or 'Unknown',
        isPlayer   = etype == 1 and IsPedAPlayer(entity),
        model      = model,
        coords     = coords,
        rotation   = rot,
        heading    = heading,
        speed      = speed,
        distance   = distance,
        netId      = (netId and netId ~= 0) and netId or nil,
        isNet      = isNet,
        isMission  = isMission,
        frozen     = frozen,
        visible    = visible,
        collision  = collision,
        alpha      = alpha,
        health     = health,
        owner      = owner,
        groundZ    = groundZ,
    }
end

-- ───────────────────────────────────────────────
-- Snippet generation per entity type
-- ───────────────────────────────────────────────
local function snippetForObject(info)
    return string.format([[
local hash = `%s`
lib.requestModel(hash)
local obj = CreateObject(hash, %s, %s, %s, true, true, false)
SetEntityHeading(obj, %s)
SetEntityCollision(obj, true, true)
FreezeEntityPosition(obj, true)
]], info.model,
    SFD.Round(info.coords.x), SFD.Round(info.coords.y), SFD.Round(info.coords.z),
    SFD.Round(info.heading))
end

local function snippetForVehicle(info)
    return string.format([[
local hash = `%s`
lib.requestModel(hash)
local veh = CreateVehicle(hash, %s, %s, %s, %s, true, false)
SetVehicleNumberPlateText(veh, 'DEV')
SetVehicleOnGroundProperly(veh)
]], info.model,
    SFD.Round(info.coords.x), SFD.Round(info.coords.y), SFD.Round(info.coords.z),
    SFD.Round(info.heading))
end

local function snippetForPed(info)
    return string.format([[
local hash = `%s`
lib.requestModel(hash)
local ped = CreatePed(4, hash, %s, %s, %s, %s, true, false)
SetEntityInvincible(ped, true)
SetBlockingOfNonTemporaryEvents(ped, true)
FreezeEntityPosition(ped, true)
]], info.model,
    SFD.Round(info.coords.x), SFD.Round(info.coords.y), SFD.Round(info.coords.z),
    SFD.Round(info.heading))
end

local function snippetFor(info)
    if info.type == 3 then return snippetForObject(info) end
    if info.type == 2 then return snippetForVehicle(info) end
    if info.type == 1 then return snippetForPed(info) end
    return SFD.FormatVec3(info.coords)
end

-- ───────────────────────────────────────────────
-- Action menu
-- ───────────────────────────────────────────────
local ACTIONS_ID = 'sfd_inspector_actions'

local function dangerous(action)
    if not SFD.HasPermission('dangerous') then
        SFD.Notify.error('Dangerous actions are permission-locked.')
        return false
    end
    return true
end

local function buildActionsMenu(info)
    local options = {
        { title = 'Entity', description = ('Handle %d · %s'):format(info.entity, info.typeName), icon = 'tag', readOnly = true },
        { title = 'Model', description = ('hash: %s'):format(info.model), icon = 'fingerprint',
          onSelect = function() SFD.Copied('model hash', info.model) end },
        { title = 'Coords', description = SFD.FormatVec3(info.coords), icon = 'location-dot',
          onSelect = function() SFD.Copied('vector3', SFD.FormatVec3(info.coords)) end },
        { title = 'Coords + heading', description = SFD.FormatVec4(info.coords, info.heading), icon = 'compass',
          onSelect = function() SFD.Copied('vector4', SFD.FormatVec4(info.coords, info.heading)) end },
        { title = 'Rotation', description = SFD.FormatVec3(info.rotation), icon = 'rotate',
          onSelect = function() SFD.Copied('rotation', SFD.FormatVec3(info.rotation)) end },
        { title = 'Spawn snippet', description = 'Copy CreateObject/Vehicle/Ped template', icon = 'code',
          onSelect = function()
              SFD.Copied('snippet', snippetFor(info))
              SFD.LogServer('snippet', { kind = info.typeName })
          end },
        { title = 'Debug table', description = 'Copy full info as Lua table', icon = 'table',
          onSelect = function()
              local t = string.format([[{
    handle    = %d,
    type      = '%s',
    model     = %s,
    coords    = %s,
    heading   = %s,
    rotation  = %s,
    netId     = %s,
    isMission = %s,
    frozen    = %s,
    visible   = %s,
    collision = %s,
    alpha     = %s,
    health    = %s,
}]],
                info.entity, info.typeName, info.model,
                SFD.FormatVec3(info.coords), tostring(SFD.Round(info.heading)),
                SFD.FormatVec3(info.rotation), tostring(info.netId),
                tostring(info.isMission), tostring(info.frozen),
                tostring(info.visible), tostring(info.collision),
                tostring(info.alpha), tostring(info.health))
              SFD.Copied('debug table', t)
          end },
        { title = info.frozen and 'Unfreeze' or 'Freeze', icon = 'snowflake',
          onSelect = function()
              if not dangerous() then return end
              FreezeEntityPosition(info.entity, not info.frozen)
              SFD.Notify.success(info.frozen and 'Entity unfrozen.' or 'Entity frozen.')
          end },
        { title = info.visible and 'Hide entity' or 'Show entity', icon = 'eye',
          onSelect = function()
              if not dangerous() then return end
              SetEntityVisible(info.entity, not info.visible, false)
              SFD.Notify.success(info.visible and 'Entity hidden.' or 'Entity shown.')
          end },
        { title = info.collision and 'Disable collision' or 'Enable collision', icon = 'circle-nodes',
          onSelect = function()
              if not dangerous() then return end
              SetEntityCollision(info.entity, not info.collision, true)
              SFD.Notify.success('Collision toggled.')
          end },
        { title = info.isMission and 'Unmark mission entity' or 'Mark as mission entity', icon = 'flag',
          onSelect = function()
              if not dangerous() then return end
              if info.isMission then
                  SetEntityAsNoLongerNeeded(info.entity)
              else
                  SetEntityAsMissionEntity(info.entity, true, true)
              end
              SFD.Notify.success('Mission flag toggled.')
          end },
        { title = 'Delete entity', description = 'Permission-locked', icon = 'trash', iconColor = '#ff6b35',
          onSelect = function()
              if not dangerous() then return end
              if info.isPlayer then SFD.Notify.error('Refusing to delete a player ped.') return end
              SetEntityAsMissionEntity(info.entity, true, true)
              DeleteEntity(info.entity)
              SFD.Notify.success('Entity deleted.')
              SFD.LogServer('delete', { type = info.typeName, model = info.model })
          end },
        { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.Inspector.openMenu() end },
    }

    -- Health row only for peds & vehicles
    if info.type == 1 or info.type == 2 then
        table.insert(options, 4, { title = 'Health', description = tostring(info.health), icon = 'heart-pulse', readOnly = true })
    end
    if info.netId then
        table.insert(options, 4, { title = 'Network', description = ('netId %s · owner %s'):format(info.netId, tostring(info.owner)), icon = 'network-wired', readOnly = true })
    end
    table.insert(options, 4, { title = 'Distance', description = ('%.2fm · ground Z %.2f'):format(info.distance, info.groundZ or 0.0), icon = 'ruler', readOnly = true })

    lib.registerContext({
        id = ACTIONS_ID,
        title = ('Inspector — %s'):format(info.typeName),
        menu = 'sfd_inspector_main',
        canClose = true,
        options = options,
    })
    lib.showContext(ACTIONS_ID)
end

-- ───────────────────────────────────────────────
-- Live overlay loop
-- ───────────────────────────────────────────────
local function startOverlay()
    if active then return end
    active = true
    lib.showTextUI('[E] Select  ·  [G] Print info to F8  ·  [Backspace] Stop', {
        position = 'right-center',
        icon = 'magnifying-glass',
    })

    CreateThread(function()
        local maxDist = Config.Inspector.maxDistance or 30.0
        local color   = Config.Inspector.markerColor or { r = 192, g = 160, b = 255, a = 200 }

        while active do
            local hit, endPos, entity, cam = performRaycast(maxDist)
            lastHit = hit and endPos or nil
            lastCam = cam

            if hit and entity ~= 0 and DoesEntityExist(entity) then
                lastEntity = entity
                if Config.Inspector.drawHitMarker and endPos then
                    DrawMarker(28, endPos.x, endPos.y, endPos.z, 0,0,0, 0,0,0,
                        0.10, 0.10, 0.10,
                        color.r, color.g, color.b, color.a,
                        false, false, 2, false, nil, nil, false)
                end
                if Config.Inspector.drawLine and cam then
                    DrawLine(cam.x, cam.y, cam.z, endPos.x, endPos.y, endPos.z,
                        color.r, color.g, color.b, color.a)
                end
            else
                lastEntity = 0
            end

            -- E to select
            if IsControlJustPressed(0, 38) and lastEntity ~= 0 then
                local info = buildEntityInfo(lastEntity)
                if info then
                    active = false
                    lib.hideTextUI()
                    buildActionsMenu(info)
                    return
                end
            end
            -- G to print
            if IsControlJustPressed(0, 47) and lastEntity ~= 0 then
                local info = buildEntityInfo(lastEntity)
                if info then
                    print(('^5[SFD Inspector]^7 entity=%d type=%s model=%s coords=%s'):format(
                        info.entity, info.typeName, info.model, SFD.FormatVec3(info.coords)))
                end
            end
            -- Backspace to exit
            if IsControlJustPressed(0, 177) then
                SFD.Inspector.stop()
                return
            end
            Wait(0)
        end
    end)
end

function SFD.Inspector.stop()
    active = false
    lib.hideTextUI()
    SFD.Notify.info('Inspector stopped.')
end

function SFD.Inspector.openMenu()
    lib.registerContext({
        id = 'sfd_inspector_main',
        title = 'Entity Inspector',
        menu = 'sfd_main_menu',
        canClose = true,
        options = {
            {
                title = active and 'Stop inspector' or 'Start inspector',
                description = active and 'Hide overlay' or 'Show overlay & raycast',
                icon = active and 'stop' or 'play',
                onSelect = function()
                    if active then SFD.Inspector.stop()
                    else startOverlay() end
                end,
            },
            {
                title = 'Inspect aimed entity now',
                description = 'One-shot: open actions menu for what you are looking at',
                icon = 'crosshairs',
                onSelect = function()
                    local hit, _, entity = performRaycast(Config.Inspector.maxDistance or 30.0)
                    if not hit or entity == 0 then
                        SFD.Notify.warning('No entity detected.')
                        return
                    end
                    local info = buildEntityInfo(entity)
                    if info then buildActionsMenu(info) end
                end,
            },
            {
                title = 'Inspect closest entity',
                description = 'Within 5m of player',
                icon = 'location-crosshairs',
                onSelect = function()
                    local pcoords = GetEntityCoords(PlayerPedId())
                    local closest, closestDist = 0, 999.0
                    for ent in EnumerateEntities() do
                        if ent ~= PlayerPedId() then
                            local d = #(pcoords - GetEntityCoords(ent))
                            if d < closestDist then closest, closestDist = ent, d end
                        end
                    end
                    if closest == 0 then SFD.Notify.warning('No entities near you.') return end
                    local info = buildEntityInfo(closest)
                    if info then buildActionsMenu(info) end
                end,
            },
            {
                title = 'Configure raycast distance',
                description = ('Current: %.1fm'):format(Config.Inspector.maxDistance or 30.0),
                icon = 'ruler-horizontal',
                onSelect = function()
                    local input = lib.inputDialog('Inspector — Raycast distance', {
                        { type = 'slider', label = 'Max distance', min = 5, max = 100, default = math.floor(Config.Inspector.maxDistance or 30) }
                    })
                    if input and input[1] then
                        Config.Inspector.maxDistance = input[1] + 0.0
                        SFD.Notify.success(('Distance set to %.1fm'):format(Config.Inspector.maxDistance))
                    end
                    SFD.Inspector.openMenu()
                end,
            },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_inspector_main')
end

-- Fallback enumerator for "closest entity"
function EnumerateEntities()
    return coroutine.wrap(function()
        local handle, ent = FindFirstObject()
        repeat
            coroutine.yield(ent)
            local ok
            ok, ent = FindNextObject(handle)
            if not ok then break end
        until not ok
        EndFindObject(handle)
    end)
end

-- ───────────────────────────────────────────────
-- Register module
-- ───────────────────────────────────────────────
SFD.RegisterModule({
    id = 'entity_inspector',
    label = 'Entity Inspector',
    description = 'Raycast at any entity and inspect or modify it',
    icon = 'magnifying-glass',
    open = function() SFD.Inspector.openMenu() end,
})
