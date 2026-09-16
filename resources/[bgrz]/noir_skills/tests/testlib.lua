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

---Tabela de exports chamável, como a do runtime: `exports.res:Fn()` resolve o stub e
---`exports('Nome', fn)` registra.
function Test.exports(providers)
    local registered = {}
    local value = providers or {}
    return setmetatable(value, {
        __call = function(_, name, callback) registered[name] = callback end,
    }), registered
end

function Test.handlers()
    local stored = {}
    return stored, function(name, callback) stored[name] = callback end
end

function Test.loadConfig(path)
    local chunk = assert(loadfile(path))
    return chunk()
end

return Test
