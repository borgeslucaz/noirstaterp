-- Utilitários de validação e rate limit usados por todos os eventos client → server.
Security = {}

local rateTable = {}
local webhookThrottle = {}

local function isFiniteNumber(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

function Security.sanitizeInt(v, minV, maxV)
    local n = tonumber(v)
    if not isFiniteNumber(n) then return nil end
    n = math.floor(n + 0.0)
    if minV ~= nil and n < minV then return nil end
    if maxV ~= nil and n > maxV then return nil end
    return n
end

function Security.sanitizeNumber(v, minV, maxV)
    local n = tonumber(v)
    if not isFiniteNumber(n) then return nil end
    if minV ~= nil and n < minV then return nil end
    if maxV ~= nil and n > maxV then return nil end
    return n + 0.0
end

---@return boolean allowed
function Security.rateLimit(src, key, ms)
    if not src or src <= 0 then return false end
    local k = ('%s:%s'):format(src, key)
    local now = GetGameTimer()
    local last = rateTable[k]
    if last and (now - last) < ms then return false end
    rateTable[k] = now
    return true
end

function Security.clearPlayer(src)
    local prefix = ('%s:'):format(src)
    for k in pairs(rateTable) do
        if k:sub(1, #prefix) == prefix then rateTable[k] = nil end
    end
    webhookThrottle[src] = nil
end

function Security.getCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Security.isNearCoords(src, coords, maxDist)
    local c = Security.getCoords(src)
    if not c or not coords then return false end
    return #(c - vec3(coords.x, coords.y, coords.z)) <= (maxDist or 5.0)
end

---Registra uma inconsistência. Não pune: apenas loga (e envia webhook se configurado).
function Security.report(src, action, reason, extra)
    if Config.Debug then
        print(('[ak4y-taxi] %s: src=%s reason=%s %s'):format(action, src, reason, extra and json.encode(extra) or ''))
    end

    local webhook = ServerConfig.Webhook
    if not webhook or webhook == '' then return end

    local now = GetGameTimer()
    if webhookThrottle[src] and (now - webhookThrottle[src]) < 5000 then return end
    webhookThrottle[src] = now

    local coords = Security.getCoords(src)
    local payload = {
        username = 'Noir Taxi',
        embeds = {{
            color = 16753920,
            title = 'ak4y-taxi · validação rejeitada',
            fields = {
                { name = 'Player', value = ('%s (src: %s)'):format(GetPlayerName(src) or 'unknown', src) },
                { name = 'Action', value = tostring(action), inline = true },
                { name = 'Reason', value = tostring(reason), inline = true },
                { name = 'Coords', value = coords and ('%.1f %.1f %.1f'):format(coords.x, coords.y, coords.z) or 'unknown' },
                { name = 'Identifiers', value = table.concat(GetPlayerIdentifiers(src) or {}, '\n') },
                { name = 'Extra', value = extra and json.encode(extra):sub(1, 900) or '-' },
            },
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        }},
    }
    PerformHttpRequest(webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

---@return false
function Security.deny(src, action, reason, extra)
    Security.report(src, action, reason, extra)
    return false
end
