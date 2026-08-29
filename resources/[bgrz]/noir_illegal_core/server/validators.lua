NoirIllegal.Validators = {}

local V = NoirIllegal.Validators

function V.string(value, minLength, maxLength)
    if type(value) ~= 'string' then return false end
    local length = #value
    return length >= (minLength or 1) and length <= (maxLength or 255)
end

function V.uuid(value)
    if type(value) ~= 'string' then return false end
    return value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-[1-5]%x%x%x%-[89aAbB]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

function V.category(category)
    return V.string(category, 1, 64) and NoirIllegal.Config.Categories[category] == true
end

function V.number(value, minimum, maximum)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and (minimum == nil or value >= minimum)
        and (maximum == nil or value <= maximum)
end

function V.clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function V.round(value, decimals)
    local scale = 10 ^ (decimals or 4)
    return math.floor(value * scale + 0.5) / scale
end

function V.copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        if type(key) == 'string' or type(key) == 'number' then
            result[key] = V.copy(item, seen)
        end
    end
    seen[value] = nil
    return result
end

function V.metadata(metadata, allowedKeys)
    if metadata == nil then return {} end
    if type(metadata) ~= 'table' then return nil end

    local allowed = {}
    for i = 1, #(allowedKeys or {}) do allowed[allowedKeys[i]] = true end

    local sanitized, count = {}, 0
    for key, value in pairs(metadata) do
        if allowed[key] then
            count = count + 1
            if count > NoirIllegal.Config.Limits.maxMetadataKeys then return nil end
            local kind = type(value)
            if kind == 'string' then
                if #value > NoirIllegal.Config.Limits.maxMetadataStringLength then return nil end
                sanitized[key] = value
            elseif kind == 'number' then
                if not V.number(value) then return nil end
                sanitized[key] = value
            elseif kind == 'boolean' then
                sanitized[key] = value
            else
                return nil
            end
        end
    end
    return sanitized
end

function V.auditMetadata(metadata)
    if metadata == nil then return {} end
    if type(metadata) ~= 'table' then return nil end
    local allowed = {}
    for key in pairs(metadata) do
        if type(key) ~= 'string' or not V.string(key, 1, 64) then return nil end
        allowed[#allowed + 1] = key
    end
    return V.metadata(metadata, allowed)
end

function V.subject(subject)
    if type(subject) ~= 'table' then return nil end
    if subject.type == NoirIllegal.SubjectTypes.PLAYER
        and V.string(subject.citizenId, 1, 64) then
        return { type = subject.type, id = subject.citizenId }
    end
    if subject.type == NoirIllegal.SubjectTypes.ORGANIZATION
        and V.string(subject.id, 1, 64) then
        return { type = subject.type, id = subject.id }
    end
    return nil
end

function V.occurredAt(value)
    local now = os.time()
    if value == nil then return now end
    if not V.number(value) or value % 1 ~= 0 then return nil end
    if value < now - NoirIllegal.Config.Limits.maxOccurredAtPastSeconds then return nil end
    if value > now + NoirIllegal.Config.Limits.maxOccurredAtFutureSeconds then return nil end
    return value
end

function V.randomUuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return template:gsub('[xy]', function(character)
        local value = character == 'x' and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(value)
    end)
end
