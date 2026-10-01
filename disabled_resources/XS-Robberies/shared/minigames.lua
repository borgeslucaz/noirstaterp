Minigames = { list = {}, order = {} }

local function define(id, def)
    def.id = id
    Minigames.list[id] = def
    Minigames.order[#Minigames.order + 1] = id
end

define('none', {
    label = 'Nenhum',
    provider = 'xs',
    resource = nil,
    blurb = 'Só o tempo. Sem teste de habilidade.',
    difficulty = false,
})

define('xs:signal_lock', {
    label = 'Trava de Sinal',
    provider = 'xs',
    blurb = 'Mantenha a portadora que oscila dentro da faixa até travar.',
    difficulty = true,
})

define('xs:circuit', {
    label = 'Roteamento de Circuito',
    provider = 'xs',
    blurb = 'Leve a energia pela grade antes de o disjuntor cair.',
    difficulty = true,
})

define('xs:tumbler', {
    label = 'Pinos da Fechadura',
    provider = 'xs',
    blurb = 'Sinta cada pino e encaixe. Errou, todos caem.',
    difficulty = true,
})

define('xs:sequence', {
    label = 'Memória de Sequência',
    provider = 'xs',
    blurb = 'Observe o padrão e repita. Fica um passo maior a cada rodada.',
    difficulty = true,
})

define('xs:frequency', {
    label = 'Sintonia de Frequência',
    provider = 'xs',
    blurb = 'Ajuste duas ondas até ficarem sobrepostas.',
    difficulty = true,
})

define('xs:wire_trace', {
    label = 'Rastrear o Fio',
    provider = 'xs',
    blurb = 'Siga um fio no emaranhado e corte a ponta certa.',
    difficulty = true,
})

define('xs:thermite', {
    label = 'Termite',
    provider = 'xs',
    blurb = 'Um padrão acende na grade. Observe e depois reproduza.',
    difficulty = true,
})

define('xs:fingerprint', {
    label = 'Digital',
    provider = 'xs',
    blurb = 'Uma digital bate com a do registro. As outras são parecidas.',
    difficulty = true,
})

define('xs:drill', {
    label = 'Furadeira',
    provider = 'xs',
    blurb = 'Faça força e alivie. Forçou demais, a broca queima.',
    difficulty = true,
})

define('xs:pinpad', {
    label = 'Teclado de Senha',
    provider = 'xs',
    blurb = 'Descubra a combinação. Cada tentativa mostra quais dígitos estão certos e quais estão perto.',
    difficulty = true,
})

define('xs:bypass', {
    label = 'Desvio',
    provider = 'xs',
    blurb = 'Pare o cursor em movimento dentro de cada portão, na ordem.',
    difficulty = true,
})

define('xs:sweep', {
    label = 'Varredura',
    provider = 'xs',
    blurb = 'A varredura do radar gira. Aperte quando ela cruzar o contato.',
    difficulty = true,
})

define('ox_lib:skillcheck', {
    label = 'Teste de habilidade ox_lib',
    provider = 'ox_lib',
    resource = 'ox_lib',
    blurb = 'O aperto de tecla cronometrado padrão do ox_lib.',
    difficulty = true,
})

define('ps-ui:circle', {
    label = 'ps-ui Círculo',
    provider = 'ps-ui',
    resource = 'ps-ui',
    blurb = 'Clique no círculo no tempo certo.',
    difficulty = true,
})

define('ps-ui:maze', {
    label = 'ps-ui Labirinto',
    provider = 'ps-ui',
    resource = 'ps-ui',
    blurb = 'Guie um marcador por um labirinto.',
    difficulty = true,
})

define('ps-ui:thermite', {
    label = 'ps-ui Termite',
    provider = 'ps-ui',
    resource = 'ps-ui',
    blurb = 'Memorize uma grade e reproduza.',
    difficulty = true,
})

define('ps-ui:scrambler', {
    label = 'ps-ui Scrambler',
    provider = 'ps-ui',
    resource = 'ps-ui',
    blurb = 'Pare o embaralhador no alvo.',
    difficulty = true,
})

define('memorygame:start', {
    label = 'Jogo da Memória',
    provider = 'memorygame',
    resource = 'memorygame',
    blurb = 'Encontre os pares contra o relógio.',
    difficulty = true,
})

define('howdy:hack', {
    label = 'Howdy Hack',
    provider = 'howdy-hackminigame',
    resource = 'howdy-hackminigame',
    blurb = 'Hack de terminal no estilo caça-palavras.',
    difficulty = true,
})

-- Robberies built before the XyraLScripts rename store these ids with a
-- `cipher:` prefix, and that stage data lives in the database. Keep the old
-- ids resolvable so those robberies still run, but leave them out of `order`
-- so the builder only ever offers the new ones.
local legacy = {}
for id, def in pairs(Minigames.list) do
    local bare = id:match('^xs:(.+)$')
    if bare then legacy['cipher:' .. bare] = def end
end
for id, def in pairs(legacy) do
    Minigames.list[id] = def
end

function Minigames.Available(id)
    local def = Minigames.list[id]
    if not def then return false end
    if Config.Minigames and Config.Minigames[def.provider] == false then return false end
    if not def.resource then return true end
    return GetResourceState(def.resource) == 'started'
end

function Minigames.Catalogue()
    local out = {}
    for _, id in ipairs(Minigames.order) do
        local d = Minigames.list[id]
        out[#out + 1] = {
            id = id, label = d.label, provider = d.provider, blurb = d.blurb,
            resource = d.resource, difficulty = d.difficulty,
            available = Minigames.Available(id),
        }
    end
    return out
end
