BGRZ = BGRZ or {}


local function isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function limitedString(value, maximum, required)
    if value == nil and not required then return nil end
    if type(value) ~= 'string' or (required and #value == 0) or #value > maximum then
        return nil, false
    end
    return value, true
end

local function normalizeCoords(value)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x, y, z = value.x, value.y, value.z
    if kind == 'table' and (x == nil or y == nil or z == nil) then
        x, y, z = value[1], value[2], value[3]
    end
    if not isFinite(x) or not isFinite(y) or not isFinite(z) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 20000 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local function normalizeJobs(value)
    if value == nil then return { 'police' } end
    if type(value) ~= 'table' or #value == 0 or #value > 16 then return nil end
    local jobs, seen = {}, {}
    for index = 1, #value do
        local job = value[index]
        if type(job) ~= 'string' or #job == 0 or #job > 32
            or not job:match('^[%w_-]+$') or seen[job] then
            return nil
        end
        seen[job] = true
        jobs[index] = job
    end
    return jobs
end

local function normalizeRequest(request)
    if type(request) ~= 'table' then return nil, 'invalid_request' end
    local coords = normalizeCoords(request.coords)
    if not coords then return nil, 'invalid_coords' end
    local title, validTitle = limitedString(request.title, 96, true)
    if validTitle ~= true then return nil, 'invalid_title' end
    local message, validMessage = limitedString(request.message or title, 512, true)
    if validMessage ~= true then return nil, 'invalid_message' end
    local code, validCode = limitedString(request.code or '10-00', 12, true)
    if validCode ~= true then return nil, 'invalid_code' end
    local jobs = normalizeJobs(request.jobs)
    if not jobs then return nil, 'invalid_jobs' end

    local duration = request.duration or 150
    if not isFinite(duration) or duration % 1 ~= 0 or duration < 30 or duration > 21600 then
        return nil, 'invalid_duration'
    end
    local priority = request.priority or 3
    if not isFinite(priority) or priority % 1 ~= 0 or priority < 1 or priority > 4 then
        return nil, 'invalid_priority'
    end
    if request.radius ~= nil and (not isFinite(request.radius)
        or request.radius <= 0 or request.radius > 1000) then
        return nil, 'invalid_radius'
    end

    return {
        code = code,
        title = title,
        message = message,
        coords = coords,
        jobs = jobs,
        duration = duration,
        priority = priority,
        radius = request.radius,
    }
end

local function sendPrimary(request)
    local provider = BGRZ.Provider.name('dispatch')
    if not BGRZ.Provider.isAvailable('dispatch') then return nil end
    local called, callId = pcall(function()
        return exports[provider]:mdtCreateCall({
            code = request.code,
            type = request.title,
            priority = request.priority,
            location = request.message,
            coords = request.coords,
            ttl = request.duration,
            domain = 'leo',
            jobs = request.jobs,
        })
    end)
    if not called or not callId then return nil end
    return { provider = provider, id = callId }
end

local function jobsMap(jobs)
    local result = {}
    for index = 1, #jobs do result[jobs[index]] = true end
    return result
end

local function sendPoliceFallback(request)
    local fallback = BGRZ.Provider.name('dispatchFallback')
    if not BGRZ.Provider.isStarted(fallback) or not BGRZ.Provider.isStarted('qbx_core')
        or not exports or not exports.qbx_core then
        return nil
    end
    local called, players = pcall(function()
        return exports.qbx_core:GetQBPlayers()
    end)
    if not called or type(players) ~= 'table' then return nil end

    local acceptedJobs = jobsMap(request.jobs)
    -- O aviso na tela leva o código e o título; o MDT guarda a prioridade.
    local text = request.message ~= request.title
        and ('[%s] %s: %s'):format(request.code, request.title, request.message)
        or ('[%s] %s'):format(request.code, request.title)
    local recipients = 0
    for playerKey, player in pairs(players) do
        local data = type(player) == 'table' and player.PlayerData or nil
        local job = data and data.job or nil
        local target = data and data.source or playerKey
        if type(target) == 'number' and job and job.onduty == true
            and acceptedJobs[job.name] then
            local emitted = pcall(
                TriggerClientEvent,
                'police:client:policeAlert',
                target,
                request.coords,
                text
            )
            if emitted then recipients = recipients + 1 end
        end
    end
    return { provider = fallback, recipients = recipients }
end

---@param request table
---@return boolean ok
---@return table|string resultOrError
function BGRZ.SendDispatch(request)
    local normalized, validationError = normalizeRequest(request)
    if not normalized then return false, validationError end
    -- O MDT registra o chamado e o fallback avisa quem está na rua; um não substitui o outro.
    local primary = sendPrimary(normalized)
    local field = sendPoliceFallback(normalized)
    if not primary and not field then return false, 'provider_unavailable' end
    return true, {
        provider = primary and primary.provider or field.provider,
        id = primary and primary.id or nil,
        recipients = field and field.recipients or 0,
    }
end

exports('SendDispatch', BGRZ.SendDispatch)
