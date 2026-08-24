local POSITION_METADATA_KEY = 'elementHudPosition'
local LAYOUT_METADATA_KEY = 'elementHudLayoutV2'
local lastPositionSave = {}
local validIconIds = {
    voice = true,
    health = true,
    armor = true,
    hunger = true,
    thirst = true,
    stamina = true,
    stress = true,
}

local function sanitizePosition(position)
    if type(position) ~= 'table' then return false end

    local x = tonumber(position.x)
    local y = tonumber(position.y)
    if not x or not y or x ~= x or y ~= y then return false end

    return {
        x = math.floor(math.max(0, math.min(x, 100)) * 100 + 0.5) / 100,
        y = math.floor(math.max(0, math.min(y, 100)) * 100 + 0.5) / 100,
    }
end

local function sanitizeScale(value)
    value = tonumber(value)
    if not value or value ~= value then return 1 end
    return math.floor(math.max(0.5, math.min(value, 2)) * 100 + 0.5) / 100
end

local function sanitizeOffset(item)
    if type(item) ~= 'table' then return false end
    local x = tonumber(item.x)
    local y = tonumber(item.y)
    if not x or not y or x ~= x or y ~= y then return false end
    return {
        x = math.floor(math.max(-50, math.min(x, 50)) * 100 + 0.5) / 100,
        y = math.floor(math.max(-50, math.min(y, 50)) * 100 + 0.5) / 100,
    }
end

local function sanitizeLayout(layout)
    if type(layout) ~= 'table' then return false end

    local sanitized = {
        position = sanitizePosition(layout.position),
        scale = sanitizeScale(layout.scale),
        icons = {},
    }

    if type(layout.icons) == 'table' then
        for id, item in pairs(layout.icons) do
            if validIconIds[id] and type(item) == 'table' then
                local offset = sanitizeOffset(item)
                if offset then
                    sanitized.icons[id] = {
                        x = offset.x,
                        y = offset.y,
                        scale = sanitizeScale(item.scale),
                    }
                end
            end
        end
    end

    return sanitized
end

lib.callback.register('element_hud:getPlayerHudPosition', function(source)
    return sanitizePosition(exports.qbx_core:GetMetadata(source, POSITION_METADATA_KEY))
end)

lib.callback.register('element_hud:savePlayerHudPosition', function(source, position)
    local now = GetGameTimer()
    if lastPositionSave[source] and now - lastPositionSave[source] < 250 then
        return false
    end

    local sanitized = sanitizePosition(position)
    if not sanitized then return false end

    lastPositionSave[source] = now
    exports.qbx_core:SetMetadata(source, POSITION_METADATA_KEY, sanitized)
    return sanitized
end)

lib.callback.register('element_hud:resetPlayerHudPosition', function(source)
    local layout = sanitizeLayout(exports.qbx_core:GetMetadata(source, LAYOUT_METADATA_KEY))
    if layout then
        layout.position = false
        exports.qbx_core:SetMetadata(source, LAYOUT_METADATA_KEY, layout)
    end
    exports.qbx_core:SetMetadata(source, POSITION_METADATA_KEY, false)
    return true
end)

lib.callback.register('element_hud:getPlayerHudLayout', function(source)
    return sanitizeLayout(exports.qbx_core:GetMetadata(source, LAYOUT_METADATA_KEY))
end)

lib.callback.register('element_hud:savePlayerHudLayout', function(source, layout)
    local now = GetGameTimer()
    if lastPositionSave[source] and now - lastPositionSave[source] < 250 then
        return false
    end

    local sanitized = sanitizeLayout(layout)
    if not sanitized then return false end

    lastPositionSave[source] = now
    exports.qbx_core:SetMetadata(source, LAYOUT_METADATA_KEY, sanitized)
    exports.qbx_core:SetMetadata(source, POSITION_METADATA_KEY, sanitized.position)
    return sanitized
end)

AddEventHandler('playerDropped', function()
    lastPositionSave[source] = nil
end)
