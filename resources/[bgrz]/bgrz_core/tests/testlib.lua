local Test = {}

function Test.equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(
        label, tostring(expected), tostring(actual)))
end

function Test.truthy(value, label)
    assert(value, label or 'expected truthy value')
end

function Test.falsy(value, label)
    assert(not value, label or 'expected falsy value')
end

function Test.exports(providers)
    local registered = {}
    local value = providers or {}
    return setmetatable(value, {
        __call = function(_, name, callback)
            registered[name] = callback
        end,
    }), registered
end

function Test.events()
    local handlers = {}
    local function add(name, callback)
        handlers[name] = handlers[name] or {}
        handlers[name][#handlers[name] + 1] = callback
        return #handlers[name]
    end
    return handlers, add
end

function Test.fire(handlers, name, ...)
    for _, callback in ipairs(handlers[name] or {}) do
        callback(...)
    end
end

return Test
