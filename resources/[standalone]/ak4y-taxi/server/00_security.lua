Security = {}

local _rl = {}
local _whThrottle = {}

local function _now()
    return GetGameTimer()
end

local function _isFiniteNumber(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Security.sanitizeInt(v, minV, maxV)
    local n = tonumber(v)
    if not _isFiniteNumber(n) then return nil end
    n = math.floor(n + 0.0)
    if minV ~= nil and n < minV then return nil end
    if maxV ~= nil and n > maxV then return nil end
    return n
end

function Security.sanitizeNumber(v, minV, maxV)
    local n = tonumber(v)
    if not _isFiniteNumber(n) then return nil end
    if minV ~= nil and n < minV then return nil end
    if maxV ~= nil and n > maxV then return nil end
    return n + 0.0
end

function Security.rateLimit(src, key, ms)
    if not src or src <= 0 then return false end
    local k = ("%s:%s"):format(tostring(src), tostring(key))
    local t = _rl[k]
    local n = _now()
    if t and (n - t) < ms then
        return false
    end
    _rl[k] = n
    return true
end

function Security.getCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c then return nil end
    return vec3(c.x, c.y, c.z)
end

function Security.isNearCoords(src, coords, maxDist)
    local c = Security.getCoords(src)
    if not c or not coords then return false end
    local d = #(c - vec3(coords.x, coords.y, coords.z))
    return d <= (maxDist or 5.0)
end

local function _truncate(s, maxLen)
    if type(s) ~= "string" then
        s = json.encode(s or {})
    end
    if #s <= maxLen then return s end
    return s:sub(1, maxLen)
end

local function _identifiersText(src)
    local ids = GetPlayerIdentifiers(src) or {}
    if #ids == 0 then return "none" end
    return table.concat(ids, "\n")
end

function Security.reportSuspect(src, action, reason, extra)
    local webhook = WEBHOOK
    if webhook == "" then return end
    local throttleKey = tostring(src or 0)
    local n = _now()
    local t = _whThrottle[throttleKey]
    if t and (n - t) < 5000 then return end
    _whThrottle[throttleKey] = n

    local name = GetPlayerName(src) or "unknown"
    local c = Security.getCoords(src)
    local coordsText = "unknown"
    if c then
        coordsText = ("x=%.2f y=%.2f z=%.2f"):format(c.x, c.y, c.z)
    end

    local embed = {
        {
            ["color"] = 16753920,
            ["title"] = (tostring(GetCurrentResourceName() or "ak4y-taxi") .. " - " .. tostring(((Config.locales[Config.Locale] or {}).server or {}).suspect_action_title or "Suspicious Action")),
            ["fields"] = {
                { ["name"] = "Resource", ["value"] = tostring(GetCurrentResourceName() or "ak4y-taxi"), ["inline"] = true },
                { ["name"] = "Player", ["value"] = ("%s (src: %s)"):format(name, tostring(src)), ["inline"] = false },
                { ["name"] = "Action", ["value"] = tostring(action or "unknown"), ["inline"] = true },
                { ["name"] = "Reason", ["value"] = tostring(reason or "unknown"), ["inline"] = true },
                { ["name"] = "Coords", ["value"] = coordsText, ["inline"] = false },
                { ["name"] = "Identifiers", ["value"] = _identifiersText(src), ["inline"] = false },
            },
            ["footer"] = { ["text"] = os.date("%Y-%m-%d %H:%M:%S (server time)") },
        }
    }

    local payload = {
        username = "AK4Y TAXI",
        embeds = embed
    }

    if extra ~= nil then
        local extraText = _truncate(extra, 900)
        table.insert(payload.embeds[1].fields, { ["name"] = "Extra", ["value"] = extraText, ["inline"] = false })
    end

    PerformHttpRequest(webhook, function() end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
end

function Security.deny(src, action, reason, extra)
    if reason == "level_denied" then
        return false
    end

    Security.reportSuspect(src, action, reason, extra)
    return false
end
