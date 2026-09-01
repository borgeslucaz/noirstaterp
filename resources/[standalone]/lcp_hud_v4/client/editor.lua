-- ---------------------------------------------------------------------------
--  HUD editor
-- ---------------------------------------------------------------------------
--  Toggles a focused NUI overlay that lets the player:
--    * drag elements around (per-element position)
--    * change scale via slider
--    * toggle visibility per element
--    * switch between "circles" and "row" status layout
--    * reset an element or all elements to defaults
--  All changes are stored in KVP via HUD.saveLayout.
-- ---------------------------------------------------------------------------

local editorOpen = false

local function setEditor(open)
    editorOpen = open and true or false
    SetNuiFocus(editorOpen, editorOpen)
    SendNUIMessage({
        type   = 'editor',
        open   = editorOpen,
        layout = HUD.layout,
        styleConfig = {
            current  = Config.Layout,
            options  = { 'circles', 'row' },
        },
    })
end

RegisterCommand(Config.Editor.command or 'hudeditor', function()
    setEditor(not editorOpen)
end, false)

RegisterCommand(Config.Editor.resetCommand or 'hudreset', function()
    HUD.resetLayout()
    TriggerEvent('chat:addMessage', { args = { '^2[HUD]^7 Layout zurückgesetzt.' } })
end, false)

-- ---------------------------------------------------------------------------
--  NUI callbacks
-- ---------------------------------------------------------------------------

RegisterNUICallback('editor:close', function(_, cb)
    setEditor(false)
    cb({ ok = true })
end)

RegisterNUICallback('editor:saveLayout', function(data, cb)
    if type(data) ~= 'table' or type(data.layout) ~= 'table' then
        cb({ ok = false, error = 'invalid_payload' })
        return
    end
    for k, v in pairs(data.layout) do
        if HUD.layout[k] and type(v) == 'table' then
            HUD.layout[k].x       = tonumber(v.x)     or HUD.layout[k].x
            HUD.layout[k].y       = tonumber(v.y)     or HUD.layout[k].y
            HUD.layout[k].scale   = tonumber(v.scale) or HUD.layout[k].scale
            if v.visible ~= nil then HUD.layout[k].visible = v.visible and true or false end
        end
    end
    HUD.saveLayout()
    cb({ ok = true })
end)

RegisterNUICallback('editor:setStyle', function(data, cb)
    if type(data) ~= 'table' or type(data.style) ~= 'string' then
        cb({ ok = false }); return
    end
    if data.style ~= 'circles' and data.style ~= 'row' then
        cb({ ok = false }); return
    end
    Config.Layout = data.style
    -- Persist alongside the per-element layout: stuff into a __style key.
    HUD.layout.__style = data.style
    HUD.saveLayout()
    SendNUIMessage({ type = 'style', style = data.style })
    cb({ ok = true })
end)

RegisterNUICallback('editor:reset', function(_, cb)
    HUD.resetLayout()
    cb({ ok = true, layout = HUD.layout })
end)

RegisterNUICallback('editor:resetElement', function(data, cb)
    if type(data) ~= 'table' or type(data.key) ~= 'string' or not Config.Defaults[data.key] then
        cb({ ok = false }); return
    end
    local d = Config.Defaults[data.key]
    HUD.layout[data.key] = { x = d.x, y = d.y, scale = d.scale, visible = d.visible }
    HUD.saveLayout()
    SendNUIMessage({ type = 'layout', layout = HUD.layout })
    cb({ ok = true })
end)
