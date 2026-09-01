-- modules/object_placer.lua
-- Spawn props, move them around with WASD/RF/QE, freeze, snap, export.

SFD = SFD or {}
SFD.ObjectPlacer = {}

local recent = {}

local function dangerous() return SFD.HasPermission('dangerous') end

local function spawnAt(model, pos, heading)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        SFD.Notify.error('Invalid model.')
        return nil
    end
    if not lib.requestModel(hash, 5000) then
        SFD.Notify.error('Failed to load model.')
        return nil
    end
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false)
    SetEntityHeading(obj, heading or 0.0)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function trackProp(obj)
    SFD.State.spawnedProps[#SFD.State.spawnedProps + 1] = obj
    if #SFD.State.spawnedProps > (Config.ObjectPlacer.maxDevProps or 50) then
        local old = table.remove(SFD.State.spawnedProps, 1)
        if DoesEntityExist(old) then SetEntityAsMissionEntity(old, true, true); DeleteEntity(old) end
        SFD.Notify.warning('Max dev props reached — oldest removed.')
    end
end

local function rememberRecent(name)
    for i, v in ipairs(recent) do if v == name then table.remove(recent, i) break end end
    table.insert(recent, 1, name)
    while #recent > 12 do table.remove(recent) end
end

-- ───────────────────────────────────────────────
-- Live placement loop
-- ───────────────────────────────────────────────
local function startPlacement(obj, modelName)
    local moveSpeed = Config.ObjectPlacer.moveSpeed or 0.05
    local rotSpeed  = Config.ObjectPlacer.rotateSpeed or 2.0
    local fastMul   = Config.ObjectPlacer.fastMul or 4.0
    local slowMul   = Config.ObjectPlacer.slowMul or 0.25

    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)

    lib.showTextUI(
        '[WASD] move  [R/F] up/down  [Q/E] rotate  [Shift] fast  [Alt] precise  [G] snap-to-ground  [ENTER] place  [BACKSPACE] cancel',
        { position = 'top-center', icon = 'arrows-up-down-left-right' })

    CreateThread(function()
        local placing = true
        while placing do
            -- Disable conflicting controls
            for _, c in ipairs({ 30, 31, 32, 33, 34, 35, 21, 19, 44, 38, 45, 23, 47, 22, 36, 71, 72 }) do
                DisableControlAction(0, c, true)
            end

            local mul = 1.0
            if IsDisabledControlPressed(0, 21) then mul = fastMul
            elseif IsDisabledControlPressed(0, 19) then mul = slowMul end

            local pos = GetEntityCoords(obj)
            local heading = GetEntityHeading(obj)

            -- Movement is camera-relative (so WASD pushes prop away from camera)
            local camRot = GetGameplayCamRot(2)
            local rZ = math.rad(camRot.z)
            local fwd   = vec3(-math.sin(rZ),  math.cos(rZ), 0.0)
            local right = vec3( math.cos(rZ),  math.sin(rZ), 0.0)

            local move = vec3(0, 0, 0)
            if IsDisabledControlPressed(0, 32) then move = move + fwd   end -- W
            if IsDisabledControlPressed(0, 33) then move = move - fwd   end -- S
            if IsDisabledControlPressed(0, 34) then move = move - right end -- A
            if IsDisabledControlPressed(0, 35) then move = move + right end -- D
            if IsDisabledControlPressed(0, 45) then move = move + vec3(0,0,1) end -- R up
            if IsDisabledControlPressed(0, 23) then move = move - vec3(0,0,1) end -- F down

            if move.x ~= 0 or move.y ~= 0 or move.z ~= 0 then
                local np = pos + move * (moveSpeed * mul)
                SetEntityCoords(obj, np.x, np.y, np.z, false, false, false, false)
            end

            if IsDisabledControlPressed(0, 44) then SetEntityHeading(obj, heading - rotSpeed * mul) end -- Q
            if IsDisabledControlPressed(0, 38) then SetEntityHeading(obj, heading + rotSpeed * mul) end -- E

            if IsDisabledControlJustPressed(0, 47) then -- G — snap to ground
                local _, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 5.0, false)
                if gz and gz ~= 0.0 then
                    SetEntityCoords(obj, pos.x, pos.y, gz, false, false, false, false)
                    SFD.Notify.info('Snapped to ground.')
                end
            end

            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 18) then -- Enter
                placing = false
                SetEntityCollision(obj, true, true)
                FreezeEntityPosition(obj, true)
                local p, h = GetEntityCoords(obj), GetEntityHeading(obj)
                trackProp(obj)
                if modelName then rememberRecent(modelName) end
                lib.hideTextUI()
                SFD.Notify.success(('Placed %s at %s'):format(modelName or 'prop', SFD.FormatVec4(p, h)))
                SFD.LogServer('spawn', { type = 'Object', model = modelName, coords = { p.x, p.y, p.z, h } })
                return
            end

            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then -- Backspace / Esc
                placing = false
                if DoesEntityExist(obj) then SetEntityAsMissionEntity(obj, true, true); DeleteEntity(obj) end
                lib.hideTextUI()
                SFD.Notify.warning('Object placement canceled.')
                return
            end

            Wait(0)
        end
    end)
end

-- ───────────────────────────────────────────────
-- Menus
-- ───────────────────────────────────────────────
local function spawnFlow(modelName)
    if not dangerous() then return end
    local ped = PlayerPedId()
    local fwd = GetEntityForwardVector(ped)
    local origin = GetEntityCoords(ped) + fwd * 1.5
    local obj = spawnAt(modelName, origin, GetEntityHeading(ped))
    if not obj then return end
    startPlacement(obj, modelName)
end

local function recentMenu()
    local options = {}
    if #recent == 0 then
        options[#options + 1] = { title = 'No recent props', readOnly = true, icon = 'circle-info' }
    end
    for _, name in ipairs(recent) do
        options[#options + 1] = {
            title = name, icon = 'cube',
            onSelect = function() spawnFlow(name) end,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.ObjectPlacer.openMenu() end }
    lib.registerContext({ id = 'sfd_obj_recent', title = 'Recent props', menu = 'sfd_obj_main', canClose = true, options = options })
    lib.showContext('sfd_obj_recent')
end

local function exportPlaced()
    local lines = { 'local objects = {' }
    for _, obj in ipairs(SFD.State.spawnedProps or {}) do
        if DoesEntityExist(obj) then
            local p, h = GetEntityCoords(obj), GetEntityHeading(obj)
            local hash = GetEntityModel(obj)
            lines[#lines + 1] = ('    { model = %s, coords = vector4(%s, %s, %s, %s) },'):format(
                hash, SFD.Round(p.x), SFD.Round(p.y), SFD.Round(p.z), SFD.Round(h))
        end
    end
    lines[#lines + 1] = '}'
    SFD.Copied('placed objects (Lua)', table.concat(lines, '\n'))
end

function SFD.ObjectPlacer.openMenu()
    lib.registerContext({
        id = 'sfd_obj_main', title = 'Object / Prop Tools', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = 'Spawn by model name', icon = 'plus',
              onSelect = function()
                  local input = lib.inputDialog('Spawn prop', { { type = 'input', label = 'Model (e.g. prop_chair_01a)', required = true } })
                  if input and input[1] then spawnFlow(input[1]) end
              end },
            { title = 'Recent props', description = ('%d remembered'):format(#recent), icon = 'clock-rotate-left', arrow = true,
              onSelect = function() recentMenu() end },
            { title = 'Cleanup all dev props', description = ('%d tracked'):format(#(SFD.State.spawnedProps or {})), icon = 'broom',
              onSelect = function()
                  for _, e in ipairs(SFD.State.spawnedProps or {}) do
                      if DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true); DeleteEntity(e) end
                  end
                  SFD.State.spawnedProps = {}
                  SFD.Notify.success('All dev props removed.')
              end },
            { title = 'Export placed objects (Lua)', icon = 'file-export',
              onSelect = function() exportPlaced() end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_obj_main')
end

SFD.RegisterModule({
    id = 'object_placer', label = 'Object Placer',
    description = 'Spawn props · place with movement controls · export',
    icon = 'cube',
    open = function() SFD.ObjectPlacer.openMenu() end,
})
