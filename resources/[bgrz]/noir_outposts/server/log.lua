NoirOutposts = NoirOutposts or {}

local Log = {}
NoirOutposts.Log = Log

local function format(event, context)
    local parts = { ('[noir_outposts] %s'):format(tostring(event)) }
    if type(context) == 'table' then
        local keys = {}
        for key in pairs(context) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        for index = 1, #keys do
            local key = keys[index]
            local value = context[key]
            if type(value) == 'table' then value = json.encode(value) end
            parts[#parts + 1] = ('%s=%s'):format(key, tostring(value))
        end
    end
    return table.concat(parts, ' ')
end

function Log.debug(event, context)
    lib.print.debug(format(event, context))
end

function Log.info(event, context)
    lib.print.info(format(event, context))
end

function Log.warn(event, context)
    lib.print.warn(format(event, context))
end

function Log.error(event, context)
    lib.print.error(format(event, context))
end
