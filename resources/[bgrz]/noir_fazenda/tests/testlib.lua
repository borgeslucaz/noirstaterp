---Harness mínimo para rodar os módulos puros deste resource em Lua puro.
---
---    cd resources/[bgrz]/noir_prettycrimes
---    lua tests/unit/parkingmeter_rules_spec.lua
---
---O que ele resolve, e é a única coisa que precisava resolver: o `require` do
---ox_lib não existe fora do jogo. `Test.require()` devolve um substituto que lê
---`config.shared` como `config/shared.lua` e guarda o resultado em cache — o
---mesmo contrato do de verdade, o suficiente para o módulo carregar sem alterar
---uma linha dele.

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

---`require 'config.shared'` -> `dofile 'config/shared.lua'`, com cache.
---@return fun(path: string): any
function Test.require()
    local cache = {}
    return function(path)
        if cache[path] ~= nil then return cache[path] end
        local chunk = assert(loadfile((path:gsub('%.', '/')) .. '.lua'))
        local result = chunk()
        cache[path] = result
        return result
    end
end

---Relógio controlável no lugar de `os.time`.
---
---O cooldown de poste e o teto por hora são o coração do módulo de servidor, e
---testá-los esperando de verdade seria meia hora por asserção. `clock.advance`
---move o tempo; `clock.restore` devolve o `os.time` original.
---@param startAt? integer
function Test.clock(startAt)
    local original = os.time
    local current = startAt or 1700000000

    os.time = function(...)
        if ... then return original(...) end
        return current
    end

    return {
        advance = function(seconds) current = current + seconds end,
        now = function() return current end,
        restore = function() os.time = original end,
    }
end

---`GetGameTimer` controlável, em milissegundos.
---@param startAt? integer
function Test.gameTimer(startAt)
    local current = startAt or 0
    GetGameTimer = function() return current end
    return {
        advance = function(ms) current = current + ms end,
        now = function() return current end,
    }
end

---Os globais que o runtime do FiveM dá de graça e o Lua puro não tem.
---
---`joaat` é o de verdade, e não um mapa de mentira: a allowlist de models do
---parquímetro é construída com ele, e um hash diferente do que o jogo calcula
---transformaria o teste em teatro.
function Test.natives()
    function vec3(x, y, z) return { x = x, y = y, z = z } end

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

    lib = lib or {
        print = {
            info = function() end,
            warn = function() end,
            error = function() end,
        },
    }
end

return Test
