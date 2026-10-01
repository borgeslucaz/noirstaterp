-- Contrato entre manifest, módulos e locales.
--
--   * módulo de cliente fora de `files{}` só quebra no `require` do jogador;
--   * config de servidor dentro de `files{}` não quebra nada, só entrega tetos e
--     limites anti-exploit ao cliente (§19.1);
--   * `exports.<outro>` fora de integrations.lua espalha provider pelo resource;
--   * chave de locale num idioma e não no outro aparece crua na tela.

local T = dofile('tests/testlib.lua')

local manifest = { files = {}, client_scripts = {}, server_scripts = {}, dependencies = {} }
do
    local env = setmetatable({}, {
        __index = function(_, key)
            -- Diretiva encadeada (`data_file 'TIPO' 'arquivo'`) chama o retorno de novo.
            local function directive(value)
                if manifest[key] and type(value) == 'table' then
                    for index = 1, #value do manifest[key][#manifest[key] + 1] = value[index] end
                end
                return directive
            end
            return directive
        end,
    })
    assert(loadfile('fxmanifest.lua', 't', env))()
end

local function listed(list, path)
    for index = 1, #list do if list[index] == path then return true end end
    return false
end

local function covered(list, path)
    if listed(list, path) then return true end
    for index = 1, #list do
        local pattern = list[index]
        if pattern:find('*', 1, true) then
            local lua = '^' .. pattern:gsub('([%.%-])', '%%%1'):gsub('%*', '[^/]*') .. '$'
            if path:match(lua) then return true end
        end
    end
    return false
end

local function lines(command)
    local handle = assert(io.popen(command))
    local out = {}
    for line in handle:lines() do out[#out + 1] = line end
    handle:close()
    return out
end

-- O que o cliente recebe ---------------------------------------------------------------

for _, path in ipairs(lines('find client shared config -name "*.lua" | sort')) do
    if path == 'config/server.lua' then
        T.falsy(covered(manifest.files, path), 'config/server.lua está sendo enviado ao cliente')
    elseif not listed(manifest.client_scripts, path) then
        T.truthy(covered(manifest.files, path), ('%s é lido pelo cliente e não está em files{}'):format(path))
    end
end

for _, file in ipairs(manifest.files) do
    T.falsy(file:match('^server/'), ('%s manda lógica de servidor para o cliente'):format(file))
end

-- Todo módulo carregado pelo boot existe.
for _, side in ipairs({ 'client', 'server' }) do
    local boot = assert(io.open(side .. '/main.lua')):read('a')
    for module in boot:gmatch("'(" .. side .. "%.modules%.[%w_]+)'") do
        T.truthy(io.open((module:gsub('%.', '/')) .. '.lua'), ('%s não existe'):format(module))
    end
end

-- Dependências -------------------------------------------------------------------------

local deps = {}
for _, dependency in ipairs(manifest.dependencies) do deps[dependency] = true end
T.truthy(deps.bgrz_core, 'bgrz_core precisa ser dependência')
T.truthy(deps.ox_target, 'ox_target é chamado direto e precisa ser dependência')
T.truthy(deps.ox_inventory, 'hooks e stash do ox_inventory são chamados direto')
T.falsy(deps.qbx_core, 'qbx_core é provider do bridge')

-- Ponto único de contato ----------------------------------------------------------------

for _, path in ipairs(lines('find client server shared config -name "*.lua" | grep -v integrations | sort')) do
    local body = assert(io.open(path)):read('a')
    T.falsy(body:find('exports%s*%.') or body:find('exports%s*%['),
        ('%s chama export de outro resource; isso pertence a integrations.lua'):format(path))
    T.falsy(body:find('qbx_core') and not body:find('%-%-.*qbx_core'),
        ('%s cita qbx_core'):format(path))
end

-- Locales ------------------------------------------------------------------------------

local function localeKeys(path)
    local text = assert(io.open(path)):read('a')
    local keys = {}
    for key in text:gmatch('"([%w_%.]+)"%s*:') do keys[key] = true end
    return keys
end

local pt, en = localeKeys('locales/pt-br.json'), localeKeys('locales/en.json')
for key in pairs(pt) do T.truthy(en[key], ('"%s" existe em pt-br e falta em en'):format(key)) end
for key in pairs(en) do T.truthy(pt[key], ('"%s" existe em en e falta em pt-br'):format(key)) end

-- Toda chave usada no código existe em pt-br.
for _, path in ipairs(lines('find client server -name "*.lua" | sort')) do
    local body = assert(io.open(path)):read('a')
    for key in body:gmatch("locale%('([%w_%.]+)'%s*[,)]") do
        T.truthy(pt[key], ('%s usa a chave "%s", que não existe'):format(path, key))
    end
    for code in body:gmatch("fail%('([%w_]+)'%)") do
        T.truthy(pt['error.' .. code], ('%s devolve o código "%s" sem texto'):format(path, code))
    end
end

print('manifest_spec: ok')
