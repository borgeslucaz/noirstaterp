-- A allowlist de model precisa funcionar com `joaat` devolvendo COM SINAL.
--
-- Este arquivo existe por causa de um bug que passou por todos os outros testes.
-- A allowlist guardava a chave crua do `joaat` e normalizava só a consulta:
--
--     Rules.modelHashes[joaat(nome)] = true              -- cru
--     return Rules.modelHashes[hash % 0x100000000]       -- normalizado
--
-- Com `joaat` devolvendo uint32 isso é idêntico e passa. Com `joaat` devolvendo
-- int32 com sinal, a chave fica negativa, a consulta procura a positiva e nunca
-- acha. E só para models acima de 2^31: `prop_parknmeter_02` (2108567945)
-- continuava funcionando enquanto `prop_parknmeter_01` (2354728673) era
-- recusado, o que parece erro de configuração e não de código.
--
-- O `parkingmeter_rules_spec` não pegou porque o stub de `joaat` do testlib
-- devolve uint32 — ele validava a minha suposição, não o contrato. Aqui o
-- módulo é carregado com as DUAS convenções e tem que se comportar igual.

local T = dofile('tests/testlib.lua')
T.natives()

local unsignedJoaat = joaat

---Recarrega `shared/parkingmeter_rules.lua` do zero com o `joaat` informado.
---Precisa ser do zero: a allowlist é construída no load do módulo, então um
---`require` em cache devolveria a tabela montada com o joaat anterior.
---@param joaatImpl fun(name: string): number
local function loadRules(joaatImpl)
    joaat = joaatImpl
    local cache = {}
    require = function(path)
        if cache[path] ~= nil then return cache[path] end
        local result = assert(loadfile((path:gsub('%.', '/')) .. '.lua'))()
        cache[path] = result
        return result
    end
    return require 'shared.parkingmeter_rules'
end

local MODELS = { 'prop_parknmeter_01', 'prop_parknmeter_02' }

---Como o jogo entregaria o hash ao `GetEntityModel`, nas duas convenções.
local function unsigned(name) return unsignedJoaat(name) end
local function signed(name)
    local hash = unsignedJoaat(name)
    return hash >= 0x80000000 and hash - 0x100000000 or hash
end

-- Sanidade do próprio teste: os dois models precisam cair em lados opostos de
-- 2^31, senão este arquivo não estaria exercitando nada.
T.truthy(unsigned('prop_parknmeter_01') >= 0x80000000,
    'prop_parknmeter_01 tem que estar ACIMA de 2^31 para o teste valer')
T.truthy(unsigned('prop_parknmeter_02') < 0x80000000,
    'prop_parknmeter_02 tem que estar ABAIXO de 2^31 para o teste valer')

-- Quatro combinações: a allowlist montada com cada convenção, consultada com
-- cada convenção. Todas têm que aceitar.
for _, build in ipairs({
    { label = 'joaat unsigned', impl = unsigned },
    { label = 'joaat com sinal', impl = signed },
}) do
    local Rules = loadRules(build.impl)

    for _, incoming in ipairs({
        { label = 'hash unsigned', impl = unsigned },
        { label = 'hash com sinal', impl = signed },
    }) do
        for _, model in ipairs(MODELS) do
            T.truthy(Rules.isAllowedModel(incoming.impl(model)),
                ('%s + %s: %s tem que ser aceito'):format(build.label, incoming.label, model))
        end
    end

    -- E continuar recusando o que não é parquímetro, nas duas convenções.
    T.falsy(Rules.isAllowedModel(unsigned('prop_atm_01')),
        build.label .. ': prop alheio continua recusado')
    T.falsy(Rules.isAllowedModel(signed('prop_atm_01')),
        build.label .. ': prop alheio com sinal continua recusado')

    -- Lixo continua sendo lixo.
    T.falsy(Rules.isAllowedModel(nil), build.label .. ': nil recusado')
    T.falsy(Rules.isAllowedModel(0 / 0), build.label .. ': NaN recusado')
    T.falsy(Rules.isAllowedModel('prop_parknmeter_01'), build.label .. ': string recusada')

    -- O hash pode chegar como float pelo msgpack do callback; `2354728673.0` é
    -- o mesmo model que `2354728673`.
    T.truthy(Rules.isAllowedModel(unsigned('prop_parknmeter_01') + 0.0),
        build.label .. ': hash em float é o mesmo model')
end

print('parkingmeter_hash_spec: ok')
