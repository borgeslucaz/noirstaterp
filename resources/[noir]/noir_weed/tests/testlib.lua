---Harness mínimo para rodar os módulos deste resource em Lua puro.
---
---    cd resources/[noir]/noir_weed
---    for f in tests/unit/*_spec.lua; do lua5.4 "$f" || break; done

local Test = {}

function Test.equal(actual, expected, label)
    assert(actual == expected, ('%s: expected %s, got %s'):format(label, tostring(expected), tostring(actual)))
end

function Test.truthy(value, label)
    assert(value, label or 'expected truthy value')
end

function Test.falsy(value, label)
    assert(not value, label or 'expected falsy value')
end

return Test
