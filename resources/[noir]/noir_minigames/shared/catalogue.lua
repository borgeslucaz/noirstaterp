---Catálogo de minigames do servidor. Dado puro, igual nos dois lados: o cliente usa para
---rodar e montar o menu, os testes leem sem runtime.
---
---`provider` diz quem desenha o jogo:
---  noir     → a NUI deste resource (html/js/games/<kind>.js)
---  ox_lib   → lib.skillCheck
---  ps_lib   → minigames do ps-ui embutidos no ps_lib
---  peuren   → peuren_minigames
---  enginewire, mhacking, safecracker, voltlab → resources de um minigame só
---
---`params[d]` são os argumentos para a dificuldade d (1 fácil, 2 normal, 3 difícil).
---Quem não tem `params` recebe só a dificuldade.

local Catalogue = { order = {}, byId = {} }

Catalogue.difficulties = {
    { value = 1, label = 'Fácil' },
    { value = 2, label = 'Normal' },
    { value = 3, label = 'Difícil' },
}

Catalogue.providers = {
    noir = { label = 'Noir', resource = nil },
    ox_lib = { label = 'ox_lib', resource = 'ox_lib' },
    ps_lib = { label = 'ps_lib (ps-ui)', resource = 'ps_lib' },
    peuren = { label = 'peuren_minigames', resource = 'peuren_minigames' },
    enginewire = { label = 'rep-enginewire', resource = 'rep-enginewire' },
    mhacking = { label = 'mhacking', resource = 'mhacking' },
    safecracker = { label = 'safecracker', resource = 'safecracker' },
    voltlab = { label = 'ultra-voltlab', resource = 'ultra-voltlab' },
}

local function define(id, def)
    def.id = id
    Catalogue.byId[id] = def
    Catalogue.order[#Catalogue.order + 1] = id
end

-- Noir: a NUI própria. `kind` é o nome registrado em html/js/games/<kind>.js.
define('noir:signal_lock', { provider = 'noir', kind = 'signal_lock', label = 'Trava de Sinal',
    blurb = 'Mantenha a portadora que oscila dentro da faixa até travar.' })
define('noir:circuit', { provider = 'noir', kind = 'circuit', label = 'Circuito',
    blurb = 'Leve a energia pela grade antes de o disjuntor cair.' })
define('noir:tumbler', { provider = 'noir', kind = 'tumbler', label = 'Tambor',
    blurb = 'Sinta cada pino e encaixe. Errou, todos caem.' })
define('noir:sequence', { provider = 'noir', kind = 'sequence', label = 'Sequência',
    blurb = 'Observe o padrão e repita. Fica um passo maior a cada rodada.' })
define('noir:frequency', { provider = 'noir', kind = 'frequency', label = 'Sintonia de Frequência',
    blurb = 'Ajuste duas ondas até ficarem sobrepostas.' })
define('noir:wire_trace', { provider = 'noir', kind = 'wire_trace', label = 'Corte de Fio',
    blurb = 'Siga um fio no emaranhado e corte a ponta certa.' })
define('noir:thermite', { provider = 'noir', kind = 'thermite', label = 'Carga de Termita',
    blurb = 'Um padrão acende na grade. Observe e depois reproduza.' })
define('noir:fingerprint', { provider = 'noir', kind = 'fingerprint', label = 'Leitura de Digital',
    blurb = 'Uma digital bate com a do registro. As outras são parecidas.' })
define('noir:drill', { provider = 'noir', kind = 'drill', label = 'Furadeira',
    blurb = 'Faça força e alivie. Forçou demais, a broca queima.' })
define('noir:pinpad', { provider = 'noir', kind = 'pinpad', label = 'Teclado numérico',
    blurb = 'Descubra a combinação pelas dicas de certo e perto.' })
define('noir:bypass', { provider = 'noir', kind = 'bypass', label = 'Bypass',
    blurb = 'Pare o cursor em movimento dentro de cada portão, na ordem.' })
define('noir:sweep', { provider = 'noir', kind = 'sweep', label = 'Radar',
    blurb = 'A varredura do radar gira. Aperte quando ela cruzar o contato.' })

-- ox_lib: lib.skillCheck(dificuldades, teclas)
define('ox_lib:skillcheck', { provider = 'ox_lib', label = 'Teste de habilidade',
    blurb = 'Aperte a tecla quando o ponteiro passar pela marca.',
    params = {
        { { 'easy', 'easy' } },
        { { 'easy', 'medium', 'medium' } },
        { { 'medium', 'hard', 'hard' } },
    } })

-- ps_lib (exports do ps-ui): primeiro argumento é o callback, sempre false aqui.
define('ps_lib:circle', { provider = 'ps_lib', export = 'Circle', label = 'Círculo',
    blurb = 'Aperte a tecla quando o arco cruzar a área.',
    params = { { 2, 12 }, { 3, 10 }, { 4, 8 } } })              -- círculos, segundos
define('ps_lib:maze', { provider = 'ps_lib', export = 'Maze', label = 'Labirinto de números',
    blurb = 'Ache o caminho pelos números antes do tempo.',
    params = { { 20 }, { 15 }, { 10 } } })                      -- segundos
define('ps_lib:scrambler', { provider = 'ps_lib', export = 'Scrambler', label = 'Scrambler',
    blurb = 'Ache o código certo no meio dos símbolos embaralhados.',
    params = { { 'numeric', 25, 0 }, { 'alphabet', 20, 0 }, { 'alphanumeric', 15, 0 } } })
define('ps_lib:thermite', { provider = 'ps_lib', export = 'Thermite', label = 'Termite (ps-ui)',
    blurb = 'Memorize os quadrados acesos e repita.',
    params = { { 15, 6, 3 }, { 12, 7, 2 }, { 10, 8, 1 } } })    -- segundos, grade, erros
define('ps_lib:varhack', { provider = 'ps_lib', export = 'VarHack', label = 'VarHack',
    blurb = 'Clique nos blocos em ordem crescente depois que os números somem.',
    params = { { 4, 5 }, { 6, 4 }, { 8, 3 } } })                -- blocos, segundos

-- peuren_minigames
define('peuren:lockpick', { provider = 'peuren', export = 'StartLockpick', label = 'Lockpick',
    blurb = 'Gire o pino até achar o ponto e force sem quebrar a gazua.',
    params = { { 5, 3, 3 }, { 3, 5, 5 }, { 2, 7, 10 } } })      -- gazuas, passo, chance de quebrar
define('peuren:hacking', { provider = 'peuren', export = 'StartHacking', label = 'Hacking',
    blurb = 'Memorize as posições e repita antes do tempo.',
    params = { { 4, 6000, 8000 }, { 5, 5000, 6000 }, { 7, 4000, 5000 } } }) -- quantidade, memorizar ms, completar ms
define('peuren:typewriter', { provider = 'peuren', export = 'StartTypewriter', label = 'Digitação',
    blurb = 'Digite as letras que aparecem antes de sumirem.',
    params = { { 4, 3000 }, { 5, 2000 }, { 7, 1500 } } })       -- quantidade, ms por letra
define('peuren:pressure', { provider = 'peuren', export = 'StartPressureBar', label = 'Barra de pressão',
    blurb = 'Segure até a marca sem passar do limite.',
    params = { { 60, 10 }, { 40, 20 }, { 25, 30 } } })          -- linha de quebra, velocidade
define('peuren:looting', { provider = 'peuren', export = 'StartLooting', label = 'Saque',
    blurb = 'Revire a grade e pegue os itens. Teste só visual: nada vai para o inventário.',
    params = { { 5000, 3 }, { 3000, 3 }, { 2000, 4 } } })       -- ms para pegar, tamanho da grade

-- Resources de um minigame só
define('enginewire:wires', { provider = 'enginewire', label = 'Fios do motor',
    blurb = 'Ligue os fios da mesma cor.' })
define('mhacking:hack', { provider = 'mhacking', label = 'Hack (mhacking)',
    blurb = 'Ache a sequência no meio do código antes do tempo.',
    params = { { 3, 40 }, { 4, 30 }, { 5, 20 } } })            -- tamanho da solução, segundos
define('safecracker:dial', { provider = 'safecracker', label = 'Cofre de disco',
    blurb = 'Gire o disco e pare em cada número da combinação.',
    params = { { 2 }, { 3 }, { 4 } } })                         -- números na combinação
define('voltlab:voltage', { provider = 'voltlab', label = 'Laboratório de voltagem',
    blurb = 'Ligue os números aos símbolos até bater a voltagem alvo.',
    params = { { 50 }, { 35 }, { 20 } } })                      -- segundos (10 a 60)

---@param id string
---@param difficulty integer
---@return table? params
function Catalogue.params(id, difficulty)
    local def = Catalogue.byId[id]
    if not def or not def.params then return nil end
    return def.params[difficulty] or def.params[2]
end

return Catalogue
