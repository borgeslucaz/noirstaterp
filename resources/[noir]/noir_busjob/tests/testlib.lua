---Harness mínimo para rodar os módulos deste resource em Lua puro.
---
---    cd resources/[noir]/noir_busjob
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

---`require 'config.shared'` -> `config/shared.lua`, com cache e com a possibilidade de
---injetar um módulo falso por nome.
---@param fakes? table<string, any>
function Test.require(fakes)
    local cache = {}
    for name, module in pairs(fakes or {}) do cache[name] = module end
    return function(path)
        if cache[path] ~= nil then return cache[path] end
        local chunk = assert(loadfile((path:gsub('%.', '/')) .. '.lua'))
        cache[path] = chunk()
        return cache[path]
    end
end

---Vetor com subtração e comprimento (`#`), o suficiente para as contas de distância.
local vectorMeta = {}
vectorMeta.__index = vectorMeta
vectorMeta.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, vectorMeta) end
vectorMeta.__len = function(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end

function Test.natives()
    function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vectorMeta) end
    vec3 = vector3

    function joaat(text)
        local hash = 0
        for index = 1, #text do
            hash = (hash + text:lower():byte(index)) % 0x100000000
            hash = (hash + (hash << 10)) % 0x100000000
            hash = hash ~ (hash >> 6)
        end
        hash = (hash + (hash << 3)) % 0x100000000
        hash = hash ~ (hash >> 11)
        hash = (hash + (hash << 15)) % 0x100000000
        return hash
    end

    lib = lib or {}
    lib.print = { info = function() end, warn = function() end, error = function() end }
end

return Test
