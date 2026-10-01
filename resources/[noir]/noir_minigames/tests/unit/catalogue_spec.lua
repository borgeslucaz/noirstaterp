-- lua5.4 tests/unit/catalogue_spec.lua (na raiz do resource)

local function check(cond, msg) if not cond then error(msg, 2) end end

local Catalogue = dofile('shared/catalogue.lua')
local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local text = f:read('a')
    f:close()
    return text
end

local index = read('html/index.html')
local core = read('html/js/core.js')

local seen, count = {}, 0
for _, id in ipairs(Catalogue.order) do
    local def = Catalogue.byId[id]
    count = count + 1
    check(not seen[id], 'id repetido: ' .. id)
    seen[id] = true
    check(def.id == id, 'id divergente: ' .. id)
    check(Catalogue.providers[def.provider], 'fornecedor desconhecido em ' .. id)
    check(type(def.label) == 'string' and def.label ~= '', 'sem nome: ' .. id)

    if def.provider == 'noir' then
        -- Todo jogo noir tem arquivo próprio, registrado com o mesmo nome e carregado
        -- pelo index.html.
        local js = read('html/js/games/' .. def.kind .. '.js')
        check(js, 'jogo sem arquivo: ' .. def.kind)
        check(js:find("NoirMG.register('" .. def.kind .. "'", 1, true), 'jogo não registrado: ' .. def.kind)
        check(read('html/css/games/' .. def.kind .. '.css'), 'jogo sem css: ' .. def.kind)
        check(index:find('js/games/' .. def.kind .. '.js', 1, true), 'index.html não carrega: ' .. def.kind)
    end

    if def.params then
        for d = 1, 3 do
            check(type(def.params[d]) == 'table', ('%s sem params da dificuldade %d'):format(id, d))
        end
    end

    if def.provider == 'ps_lib' or def.provider == 'peuren' then
        check(type(def.export) == 'string', 'sem export: ' .. id)
    end
end

-- ultra-voltlab recusa tempo fora de 10..60 s.
for d = 1, 3 do
    local s = Catalogue.params('voltlab:voltage', d)[1]
    check(s >= 10 and s <= 60, 'voltlab fora de 10..60 s')
end

-- Dificuldade inválida cai na normal.
check(Catalogue.params('ps_lib:circle', 9) == Catalogue.byId['ps_lib:circle'].params[2], 'fallback da dificuldade')
check(Catalogue.params('noir:drill', 1) == nil, 'noir não usa params')

-- A NUI só obedece às mensagens do resource, e jogo desconhecido falha.
check(read('html/js/main.js'):find("'noir_minigames:play'", 1, true), 'handler play ausente')
check(core:find('if (!def || session) { resolve(false); return; }', 1, true), 'jogo desconhecido tem que falhar')

-- Nada do XS-Robberies dentro do resource (licença não permite redistribuir).
for _, path in ipairs({ 'html/index.html', 'html/js/core.js', 'html/js/main.js', 'html/css/base.css' }) do
    check(not read(path):find('XS', 1, true), 'referência ao XS em ' .. path)
end

-- Manifest: catálogo e config do cliente vão para o jogador; a do servidor não.
local manifest = io.open('fxmanifest.lua'):read('a')
check(manifest:find("'shared/catalogue.lua'", 1, true), 'catálogo fora de files')
check(manifest:find("'config/client.lua'", 1, true), 'config do cliente fora de files')
check(not manifest:find("'config/server.lua'", 1, true), 'config do servidor não pode ir para files')
check(not manifest:find('lua54', 1, true), 'lua54 é deprecated')

print(('ok: %d minigames'):format(count))
