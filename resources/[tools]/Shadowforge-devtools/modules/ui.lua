-- modules/ui.lua
-- UI helpers: notifications, copy+notify, context menu helpers.

SFD = SFD or {}
SFD.Notify = {}

local TITLE = 'ShadowForge DevTools'

local function notify(opts)
    if not (lib and lib.notify) then return end
    lib.notify(opts)
end

function SFD.Notify.success(message, title)
    notify({ title = title or TITLE, description = message, type = 'success' })
end

function SFD.Notify.error(message, title)
    notify({ title = title or TITLE, description = message, type = 'error' })
end

function SFD.Notify.info(message, title)
    notify({ title = title or TITLE, description = message, type = 'inform' })
end

function SFD.Notify.warning(message, title)
    notify({ title = title or TITLE, description = message, type = 'warning' })
end

-- Copy a value to clipboard and notify the user.
function SFD.Copied(label, payload)
    SFD.SetClipboard(payload)
    SFD.Notify.success(('Copied %s to clipboard.'):format(label))
end

function SFD.OpenContext(id)
    if lib and lib.showContext then lib.showContext(id) end
end

-- Round helper used by formatters
function SFD.Round(n, decimals)
    decimals = decimals or 2
    local mult = 10 ^ decimals
    return math.floor(n * mult + 0.5) / mult
end

function SFD.FormatVec3(v, d)
    d = d or 2
    return ('vector3(%s, %s, %s)'):format(
        SFD.Round(v.x, d), SFD.Round(v.y, d), SFD.Round(v.z, d))
end

function SFD.FormatVec4(v, h, d)
    d = d or 2
    return ('vector4(%s, %s, %s, %s)'):format(
        SFD.Round(v.x, d), SFD.Round(v.y, d), SFD.Round(v.z, d), SFD.Round(h, d))
end

-- Server-side permission gate (cached for one menu lifetime).
SFD._permCache = {}
function SFD.HasPermission(level)
    level = level or 'base'
    if not Config.Permissions.require then return true end
    local cached = SFD._permCache[level]
    if cached ~= nil and (GetGameTimer() - cached.t) < 5000 then
        return cached.v
    end
    local result = lib.callback.await('sfd:permission', false, level)
    SFD._permCache[level] = { v = result and true or false, t = GetGameTimer() }
    return SFD._permCache[level].v
end

-- Server log helper
function SFD.LogServer(action, data)
    TriggerServerEvent('sfd:log', action, data or {})
end
