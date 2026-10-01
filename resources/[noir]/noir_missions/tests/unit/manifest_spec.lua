-- Contrato entre fxmanifest, arquivos e regras do SCRIPT_GOOD_PRACTICES.
--
-- Nada aqui daria erro de script se quebrasse:
--   * módulo de cliente fora de files{} só quebra no `require` do jogador;
--   * config de servidor ou definição de missão dentro de files{} manda recompensa e regra
--     anti-exploit para o cliente, em silêncio (§19.1);
--   * chamada a outro resource fora dos arquivos de integração espalha provider pelo
--     resource (§2.1, §2.5).
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

local function covered(list, path)
    for index = 1, #list do
        local pattern = list[index]
        if pattern == path then return true end
        if pattern:find('*', 1, true) then
            local lua = '^' .. pattern:gsub('([%.%-])', '%%%1'):gsub('%*%*/', '\0'):gsub('%*', '[^/]*'):gsub('%z', '.-/?') .. '$'
            if path:match(lua) then return true end
        end
    end
    return false
end

local function find(pattern)
    local handle = assert(io.popen(('find %s -type f | sort'):format(pattern)))
    local list = {}
    for line in handle:lines() do list[#list + 1] = line:gsub('^%./', '') end
    handle:close()
    return list
end

-- Tudo que o cliente faz `require` precisa ir para o cliente.
for _, path in ipairs(find('client shared -name "*.lua"')) do
    T.truthy(covered(manifest.files, path) or covered(manifest.client_scripts, path),
        path .. ' é lido pelo cliente e não está em files{}')
end
T.truthy(covered(manifest.files, 'config/shared.lua'), 'config/shared.lua vai para o cliente')
T.truthy(covered(manifest.files, 'config/client.lua'), 'config/client.lua vai para o cliente')

-- E o que é do servidor não vai.
T.falsy(covered(manifest.files, 'config/server.lua'), 'config/server.lua não pode ir para o cliente')
for _, path in ipairs(find('server missions dev')) do
    T.falsy(covered(manifest.files, path), path .. ' é do servidor/dev e está em files{}')
end

-- Dependências: o bridge, e o ox_target porque é chamado direto (§2.5). Providers do bridge, não.
local declared = {}
for _, name in ipairs(manifest.dependencies) do declared[name] = true end
T.truthy(declared.bgrz_core, 'bgrz_core declarado')
T.truthy(declared.ox_target, 'ox_target declarado (exceção do §2.5)')
for _, forbidden in ipairs({ 'qbx_core', 'ox_inventory', 'qbx_vehiclekeys', 'mri_Qcarkeys', 'ox_fuel' }) do
    T.falsy(declared[forbidden], forbidden .. ' é provider do bridge e não pode ser dependência')
end

-- Ninguém fora dos arquivos de integração cita outro resource.
local allowed = { ['client/integrations.lua'] = true, ['server/integrations.lua'] = true }
for _, path in ipairs(find('client server shared -name "*.lua"')) do
    if not allowed[path] then
        local source = assert(io.open(path)):read('a')
        for _, provider in ipairs({ 'bgrz_core', 'ox_target', 'qbx_core', 'ox_inventory', 'noir_lib', 'noir_minigames' }) do
            local direct = source:find('exports%.' .. provider) or source:find("exports%[%s*'" .. provider)
            T.falsy(direct, ('%s chama %s fora do arquivo de integrações'):format(path, provider))
        end
        T.falsy(source:find('GetResourceState%('), path .. ' usa GetResourceState fora das integrações')
    end
end

-- Objeto local preso é apagado com DeleteObject (memória: DeleteEntity derruba o cliente).
local carry = assert(io.open('client/cargo/carry.lua')):read('a')
T.falsy(carry:find('DeleteEntity%('), 'carry.lua usa DeleteEntity em objeto local')
T.truthy(carry:find('DetachEntity'), 'carry.lua desanexa antes de apagar')

print('manifest_spec: ok')
