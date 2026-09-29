NoirIllegal.Logger = {}

local function encode(value)
    local ok, result = pcall(json.encode, value)
    return ok and result or '{"encodeError":true}'
end

function NoirIllegal.Logger.write(level, event, context)
    if level == 'debug' and not NoirIllegal.Config.Debug then return end
    context = context or {}
    context.level = level
    context.event = event
    context.resource = 'noir_illegal_core'
    print(('[noir_illegal_core] %s'):format(encode(context)))
end

function NoirIllegal.Logger.debug(event, context)
    NoirIllegal.Logger.write('debug', event, context)
end

function NoirIllegal.Logger.info(event, context)
    NoirIllegal.Logger.write('info', event, context)
end

function NoirIllegal.Logger.warn(event, context)
    NoirIllegal.Logger.write('warn', event, context)
end

function NoirIllegal.Logger.error(event, context)
    NoirIllegal.Logger.write('error', event, context)
end
