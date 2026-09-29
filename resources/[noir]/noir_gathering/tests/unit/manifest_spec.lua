-- Contrato entre fxmanifest, módulos e locales. Cada asserção pega uma falha que não
-- daria erro de script: módulo de client fora de `files{}` só quebra no jogador, config
-- de servidor dentro de `files{}` vaza recompensa em silêncio, chave de locale ausente
-- aparece crua na tela.

local T = dofile('tests/testlib.lua')

local manifest = { files = {}, client_scripts = {}, server_scripts = {}, dependencies = {} }
do
    local env = setmetatable({}, {
        __index = function(_, key)
            return function(value)
                if manifest[key] and type(value) == 'table' then
                    for index = 1, #value do manifest[key][#manifest[key] + 1] = value[index] end
                end
            end
        end,
    })
    assert(loadfile('fxmanifest.lua', 't', env))()
end

local function listed(list, path)
    for index = 1, #list do
        if list[index] == path then return true end
    end
    return false
end

local function lines(command)
    local handle = assert(io.popen(command))
    local result = {}
    for line in handle:lines() do result[#result + 1] = line end
    handle:close()
    return result
end

local function read(path)
    return assert(io.open(path)):read('a')
end

-- O que o cliente recebe ----------------------------------------------------------------

for _, path in ipairs(lines('find client shared config -name "*.lua" | sort')) do
    if path == 'config/server.lua' then
        T.falsy(listed(manifest.files, path), 'config/server.lua é do servidor e está indo para o cliente')
    elseif not listed(manifest.client_scripts, path) then
        T.truthy(listed(manifest.files, path), path .. ' é lido pelo client e não está em files{}')
    end
end
for _, path in ipairs(manifest.files) do
    T.falsy(path:match('^server/'), path .. ' manda lógica de servidor para o cliente')
end

-- Dependências (§6.2 e §2.5) ------------------------------------------------------------

local forbidden = { qbx_core = true, ox_inventory = true, qbx_vehiclekeys = true, ['qb-core'] = true }
for _, dependency in ipairs(manifest.dependencies) do
    T.falsy(forbidden[dependency], dependency .. ' é provider do bridge e não pode ser dependência daqui')
end
T.truthy(listed(manifest.dependencies, 'bgrz_core'), 'bgrz_core precisa estar declarado')
T.truthy(listed(manifest.dependencies, 'ox_target'), 'ox_target é chamado direto (§2.5) e precisa estar declarado')
for _, path in ipairs(lines('find client -name "*.lua" | sort')) do
    T.falsy(read(path):find('Add%w*Target') or read(path):find('Remove%w*Target%s*%('),
        path .. ' usa wrapper de target do bridge; código novo chama o ox_target direto (§2.5)')
end
T.truthy(listed(manifest.dependencies, 'noir_lib'), 'noir_lib é chamado e precisa estar declarado')

-- Contato com outros resources só em integrations.lua ------------------------------------

for _, path in ipairs(lines('find client server shared config -name "*.lua" | grep -v integrations | sort')) do
    local body = read(path)
    T.falsy(body:find('exports%s*%.') or body:find('exports%s*%['),
        path .. ' chama export de outro resource; isso pertence a integrations.lua')
    T.falsy(body:find('GetResourceState%s*%('), path .. ' consulta outro resource fora de integrations.lua')
    T.falsy(body:find('QBCore') or body:find('qbx_core'), path .. ' fala com o Qbox sem passar pelo bgrz_core')
end

-- Locales -------------------------------------------------------------------------------

local function keys(path)
    local result = {}
    for key in read(path):gmatch('"([%w_]+)"%s*:') do result[key] = true end
    return result
end

local pt, en = keys('locales/pt-br.json'), keys('locales/en.json')
for key in pairs(pt) do T.truthy(en[key], ('"%s" existe em pt-br e falta em en'):format(key)) end
for key in pairs(en) do T.truthy(pt[key], ('"%s" existe em en e falta em pt-br'):format(key)) end

for _, path in ipairs(lines('find client server -name "*.lua" | sort')) do
    local body = read(path)
    for key in body:gmatch("locale%('([%w_]+)'") do
        T.truthy(pt[key], ('%s usa a chave "%s", que não existe'):format(path, key))
    end
    for key in body:gmatch("'(error_[%w_]+)'") do
        T.truthy(pt[key], ('%s usa a chave "%s", que não existe'):format(path, key))
    end
end

print('manifest_spec: ok')
