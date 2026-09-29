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

---Carrega os módulos shared com os stubs mínimos do runtime FiveM.
function Test.loadShared()
    NoirOutposts = nil
    dofile('shared/constants.lua')
    dofile('shared/validators.lua')
    return NoirOutposts
end

---Lê um arquivo de configuração que retorna uma tabela.
---@param path string
function Test.loadConfig(path)
    local chunk = assert(loadfile(path))
    return chunk()
end

return Test
