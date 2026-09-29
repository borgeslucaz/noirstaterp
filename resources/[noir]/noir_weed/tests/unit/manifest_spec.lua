-- Contrato entre fxmanifest, módulos e locales: módulo de client fora de `files{}` só
-- quebra no jogador, config de servidor dentro de `files{}` vaza a recompensa, chave de
-- locale ausente aparece crua na tela.

local T = dofile('tests/testlib.lua')

local manifest = { files = {}, client_scripts = {}, dependencies = {} }
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

local function read(path)
    return assert(io.open(path)):read('a')
end

T.falsy(listed(manifest.files, 'config/server.lua'), 'config/server.lua não pode ir para o cliente')

-- Todo `require` do client aponta para arquivo em files{}.
for _, path in ipairs({ 'client/main.lua', 'client/placement.lua', 'client/integrations.lua' }) do
    for module in read(path):gmatch("require%s*'([%w%._]+)'") do
        local file = module:gsub('%.', '/') .. '.lua'
        T.truthy(listed(manifest.files, file) or listed(manifest.client_scripts, file),
            ('%s exige %s, que não está em files{}'):format(path, file))
    end
end

T.truthy(listed(manifest.dependencies, 'ox_target'), 'ox_target é chamado direto e precisa estar em dependencies (§2.5)')
T.truthy(listed(manifest.dependencies, 'bgrz_core'), 'bgrz_core em dependencies')
T.falsy(listed(manifest.dependencies, 'qbx_core'), 'qbx_core é provider do bgrz_core (§6.2)')
T.falsy(listed(manifest.dependencies, 'ox_inventory'), 'ox_inventory é provider do bgrz_core (§6.2)')

-- Chaves de locale: as literais do client e os códigos de erro do servidor.
local keys = {}
for _, path in ipairs({ 'client/main.lua', 'client/placement.lua' }) do
    for key in read(path):gmatch("locale%('([%w_]+)'") do keys[key] = true end
end
local server = read('server/main.lua')
for code in server:gmatch("code = '([%w_]+)'") do keys['error_' .. code] = true end
for code in server:gmatch("return false, '([%w_]+)'") do keys['error_' .. code] = true end
-- `'no_' .. action` e afins: o sufixo vem do laço de ações abaixo.
for key in pairs(keys) do
    if key:sub(-1) == '_' then keys[key] = nil end
end
for _, action in ipairs({ 'water', 'fertilizer', 'herbicide' }) do
    for _, prefix in ipairs({ 'error_max_', 'error_no_', 'success_', 'progress_', 'menu_', 'item_' }) do
        keys[prefix .. action] = true
    end
end
for _, action in ipairs({ 'plant', 'harvest', 'destroy' }) do keys['progress_' .. action] = true end

for _, file in ipairs({ 'locales/pt-br.json', 'locales/en.json' }) do
    local text = read(file)
    for key in pairs(keys) do
        T.truthy(text:find('"' .. key .. '"', 1, true), ('%s sem a chave %s'):format(file, key))
    end
end

print('manifest_spec ok')
