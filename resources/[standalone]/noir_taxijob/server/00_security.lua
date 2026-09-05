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

---Sanitiza uma string curta vinda do client (sem controle, tamanho limitado).
---@param v any
---@param maxLen number
---@return string|nil
function Security.sanitizeString(v, maxLen)
    if type(v) ~= 'string' then return nil end
    if #v == 0 or #v > (maxLen or 32) then return nil end
    if v:find('[%c]') then return nil end
    return v
end

---Nome de exibição para o ranking: sem controle, sem excesso de espaço, tamanho limitado.
---@param name any
---@return string
function Security.sanitizeName(name)
    if type(name) ~= 'string' then return 'Motorista' end
    name = name:gsub('[%c]', ''):gsub('%s+', ' ')
    name = name:match('^%s*(.-)%s*$') or ''
    if name == '' then return 'Motorista' end
    if #name > 48 then name = name:sub(1, 48) end
    return name
end

---Token opaco, não previsível, para sessões curtas.
---@return string
function Security.token()
    local parts = {}
    for i = 1, 4 do
        parts[i] = ('%08x'):format(math.random(0, 0x7fffffff))
    end
    return table.concat(parts) .. ('%x'):format(GetGameTimer())
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

---@return boolean
function Security.isOnFoot(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return GetVehiclePedIsIn(ped, false) == 0
end

function Security.isNearCoords(src, coords, maxDist)
    local c = Security.getCoords(src)
    if not c or not coords then return false end
    return #(c - vec3(coords.x, coords.y, coords.z)) <= (maxDist or 5.0)
end

---Registra uma inconsistência. Não pune: apenas loga (e envia webhook se configurado).
function Security.report(src, action, reason, extra)
    if Config.Debug then
        print(('[noir_taxijob] %s: src=%s reason=%s %s'):format(action, src, reason, extra and json.encode(extra) or ''))
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
            title = 'noir_taxijob · validação rejeitada',
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
