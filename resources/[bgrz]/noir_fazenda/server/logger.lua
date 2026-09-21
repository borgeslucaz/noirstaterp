NoirFazenda = NoirFazenda or {}
NoirFazenda.Logger = {}

local function encode(value)
    local ok, result = pcall(json.encode, value)
    return ok and result or '{"encodeError":true}'
end

function NoirFazenda.Logger.write(level, event, context)
    if level == 'debug' and not NoirFazenda.Config.Debug then return end
    context = context or {}
    context.level = level
    context.event = event
    context.resource = NoirFazenda.Constants.resource
    print(('[noir_fazenda] %s'):format(encode(context)))
end

function NoirFazenda.Logger.debug(event, context)
    NoirFazenda.Logger.write('debug', event, context)
end

function NoirFazenda.Logger.info(event, context)
    NoirFazenda.Logger.write('info', event, context)
end

function NoirFazenda.Logger.warn(event, context)
    NoirFazenda.Logger.write('warn', event, context)
end

function NoirFazenda.Logger.error(event, context)
    NoirFazenda.Logger.write('error', event, context)
end
