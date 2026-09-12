-- Garante que o manifest e o disco concordam. Um arquivo novo que existe mas não é
-- carregado não quebra a sintaxe nem os outros testes: só falha em runtime, a cada tick.
local T = dofile('tests/testlib.lua')

local function read(path)
    local file = assert(io.open(path, 'r'))
    local content = file:read('*a')
    file:close()
    return content
end

local function exists(path)
    local file = io.open(path, 'r')
    if not file then return false end
    file:close()
    return true
end

---@param block string conteúdo entre as chaves da lista
---@return string[] caminhos declarados, sem os de outros resources
local function declared(block)
    local paths = {}
    for path in block:gmatch("'([^']+)'") do
        if not path:match('^@') then paths[#paths + 1] = path end
    end
    return paths
end

local function blockOf(manifest, name)
    local block = manifest:match(name .. '%s*{(.-)\n}')
    assert(block, ('manifest block %s not found'):format(name))
    return block
end

---@return string[] arquivos .lua sob o diretório
local function luaFilesIn(directory)
    local found = {}
    local pipe = io.popen(('find %s -name "*.lua" 2>/dev/null'):format(directory))
    if not pipe then return found end
    for line in pipe:lines() do found[#found + 1] = line end
    pipe:close()
    table.sort(found)
    return found
end

local manifest = read('fxmanifest.lua')

local scriptBlocks = { 'shared_scripts', 'client_scripts', 'server_scripts' }
local listed = {}
local total = 0

for index = 1, #scriptBlocks do
    local block = blockOf(manifest, scriptBlocks[index])
    local paths = declared(block)
    assert(#paths > 0, scriptBlocks[index] .. ' declares no local script')
    for pathIndex = 1, #paths do
        local path = paths[pathIndex]
        -- Curingas ficam de fora: quem os usa aceita qualquer arquivo do diretório.
        if not path:find('*', 1, true) then
            assert(exists(path), ('manifest lists a missing file: %s'):format(path))
            listed[path] = true
            total = total + 1
        end
    end
end

assert(total >= 20, 'the manifest should list every module explicitly')

-- Todo arquivo de código precisa estar declarado, ou nunca será carregado.
-- `config/` fica de fora: é lido por require, e só os dois públicos vão em `files`.
for _, directory in ipairs({ 'shared', 'client', 'server' }) do
    local files = luaFilesIn(directory)
    for index = 1, #files do
        assert(listed[files[index]],
            ('%s exists but is not loaded by the manifest'):format(files[index]))
    end
end

local filesBlock = blockOf(manifest, 'files')
for _, path in ipairs({ 'config/shared.lua', 'config/client.lua' }) do
    assert(filesBlock:find(path, 1, true),
        ('%s must be downloadable for the client require'):format(path))
end
assert(not filesBlock:find('config/server.lua', 1, true),
    'config/server.lua must never reach the client')

-- Regressão: a abordagem existe e é carregada antes de quem depende dela.
local serverBlock = blockOf(manifest, 'server_scripts')
local order = {}
for index, path in ipairs(declared(serverBlock)) do order[path] = index end

T.truthy(order['server/services/holdup_service.lua'], 'holdup service is loaded')
T.truthy(order['server/services/dealer_service.lua'] < order['server/services/holdup_service.lua'],
    'holdup loads after the dealer service it binds at load')
T.truthy(order['server/services/holdup_service.lua'] < order['server/scheduler.lua'],
    'holdup loads before the scheduler that ticks it')
T.truthy(order['server/services/holdup_service.lua'] < order['server/api.lua'],
    'holdup loads before the api that exposes it')
T.truthy(order['server/state.lua'] < order['server/services/notification_service.lua'],
    'state loads before the services that read it')

print('manifest_spec: ok')
