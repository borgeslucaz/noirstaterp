-- Confere o contrato entre config, constants e fxmanifest.
--
-- Cada asserção aqui existe por causa de uma falha que NÃO daria erro de script:
--
--   * um crime ligado em `Config.crimes` sem estar em `Constants.crimes` só
--     aparece como uma linha no boot que ninguém lê;
--   * um módulo de client fora de `files{}` só quebra no `require` do jogador,
--     não no do servidor — quem testa no próprio servidor nunca vê;
--   * um config de SERVIDOR dentro de `files{}` não quebra nada. Ele só envia a
--     loot table e os limites anti-exploit para o cliente, em silêncio. É o §19.1
--     do SCRIPT_GOOD_PRACTICES, e é o erro mais caro dos três.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Config = require 'config.shared'
local Constants = require 'shared.constants'

-- Leitura do manifest ------------------------------------------------------------------
-- Um interpretador mínimo: as diretivas que interessam viram tabelas, o resto é
-- engolido por um __index que devolve função para qualquer nome.

local manifest = { files = {}, client_scripts = {}, server_scripts = {}, dependencies = {} }

do
    local env = {}
    setmetatable(env, {
        __index = function(_, key)
            return function(value)
                if manifest[key] and type(value) == 'table' then
                    for index = 1, #value do
                        manifest[key][#manifest[key] + 1] = value[index]
                    end
                end
            end
        end,
    })
    local chunk = assert(loadfile('fxmanifest.lua', 't', env))
    chunk()
end

local function listed(list, path)
    for index = 1, #list do
        if list[index] == path then return true end
    end
    return false
end

---`client/crimes/parkingmeter/*.lua` cobre `client/crimes/parkingmeter/init.lua`.
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

-- Crimes -------------------------------------------------------------------------------

for id, enabled in pairs(Config.crimes) do
    T.truthy(Constants.crimes[id] or Constants.plannedCrimes[id],
        ('"%s" está em Config.crimes mas não é um id conhecido'):format(id))
    if enabled then
        T.truthy(Constants.crimes[id],
            ('"%s" está ligado mas não tem módulo'):format(id))
    end
end

for id in pairs(Constants.crimes) do
    T.truthy(Config.crimes[id] ~= nil,
        ('o crime "%s" existe mas não aparece em Config.crimes'):format(id))
    T.falsy(Constants.plannedCrimes[id],
        ('"%s" tem módulo e ainda está listado como planejado'):format(id))

    -- Todo crime carregado precisa dos dois lados.
    T.truthy(loadfile(('client/crimes/%s/init.lua'):format(id))
        or loadfile(('client/crimes/%s.lua'):format(id)),
        ('falta o módulo de client de "%s"'):format(id))
    T.truthy(loadfile(('server/crimes/%s/init.lua'):format(id))
        or loadfile(('server/crimes/%s.lua'):format(id)),
        ('falta o módulo de servidor de "%s"'):format(id))
end

-- O que o cliente recebe ---------------------------------------------------------------

local handle = assert(io.popen('find client shared config -name "*.lua" | sort'))
local clientVisible = {}
for line in handle:lines() do clientVisible[#clientVisible + 1] = line end
handle:close()

for index = 1, #clientVisible do
    local path = clientVisible[index]
    local isServerConfig = path:match('^config/.*_server%.lua$') or path == 'config/server.lua'

    if isServerConfig then
        -- A asserção que mais importa deste arquivo.
        T.falsy(covered(manifest.files, path),
            ('%s é config de SERVIDOR e está sendo enviado ao cliente'):format(path))
    elseif path:match('^client/') or path:match('^shared/') or path:match('^config/') then
        -- `client/main.lua` entra como script, não como file.
        if not listed(manifest.client_scripts, path) then
            T.truthy(covered(manifest.files, path),
                ('%s é lido pelo client e não está em files{}'):format(path))
        end
    end
end

-- Nada de `server/` pode atravessar para o cliente.
for index = 1, #manifest.files do
    T.falsy(manifest.files[index]:match('^server/'),
        ('%s está em files{} e manda lógica de servidor para o cliente'):format(manifest.files[index]))
end

-- Dependências -------------------------------------------------------------------------
-- O §6.2 é explícito: o consumidor declara o bridge, nunca os providers dele.
--
-- `ox_target` saiu desta lista por decisão do dono do servidor: o alvo por model
-- do parquímetro chama `exports.ox_target:addModel` direto, então ele é
-- dependência de verdade e precisa estar declarado. A exceção está registrada
-- aqui, e não apagada, para que a próxima pessoa saiba que foi escolha e não
-- descuido — e para que os OUTROS providers continuem barrados.

local forbidden = { qbx_core = true, ox_inventory = true, qbx_vehiclekeys = true }
local hasCore = false
for index = 1, #manifest.dependencies do
    local dependency = manifest.dependencies[index]
    T.falsy(forbidden[dependency],
        ('%s é provider do bridge e não pode ser dependência daqui'):format(dependency))
    if dependency == 'bgrz_core' then hasCore = true end
end
T.truthy(hasCore, 'bgrz_core precisa ser dependência declarada')

-- O contrapeso da exceção: se o alvo por model fala com o ox_target direto,
-- então o ox_target TEM que estar declarado. Sem isto, a exceção viraria uma
-- dependência oculta e o resource poderia subir antes do provider.
local usesTargetDirectly = assert(io.open('client/integrations.lua')):read('a')
    :find('exports%[TARGET%]')
if usesTargetDirectly then
    local hasTarget = false
    for index = 1, #manifest.dependencies do
        if manifest.dependencies[index] == 'ox_target' then hasTarget = true end
    end
    T.truthy(hasTarget,
        'client/integrations.lua chama o ox_target direto, então ele precisa estar em dependencies{}')
end

-- Locales ------------------------------------------------------------------------------
-- Uma chave que existe num idioma e não no outro não quebra nada: ela só aparece
-- crua na tela do jogador que usa o idioma incompleto.

local function localeKeys(path)
    local text = assert(io.open(path)):read('a')
    local keys = {}
    for key in text:gmatch('"([%w_]+)"%s*:') do keys[key] = true end
    return keys
end

local pt, en = localeKeys('locales/pt-br.json'), localeKeys('locales/en.json')
for key in pairs(pt) do
    T.truthy(en[key], ('a chave "%s" existe em pt-br e falta em en'):format(key))
end
for key in pairs(en) do
    T.truthy(pt[key], ('a chave "%s" existe em en e falta em pt-br'):format(key))
end

print('manifest_spec: ok')
