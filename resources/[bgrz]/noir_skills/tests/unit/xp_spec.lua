-- A curva é o coração do resource: nível, progresso e teto saem toda vez daqui, e é a
-- parte em que o upstream errava (níveis que ninguém alcança porque o custo acumulado
-- era multiplicado, não somado).
local T = dofile('tests/testlib.lua')

dofile('shared/config.lua')
dofile('shared/xp.lua')

local Xp = NoirSkills.xp

-- Config do servidor ---------------------------------------------------------------------
T.equal(#Xp.configErrors, 0, 'shared/config.lua não pode ter habilidade inválida')
T.truthy(#Xp.list() > 0, 'o config precisa declarar alguma habilidade')

for _, skill in ipairs(Xp.list()) do
    local conf = Config.Skills[skill]
    T.equal(Xp.maxLevel(skill), conf.maxLevel, skill .. ': maxLevel do config é o topo da tabela')
    T.equal(Xp.totalForLevel(skill, 1), 0, skill .. ': nível 1 começa em 0 de XP')

    -- Custo acumulado, não multiplicado: cada nível custa mais que o anterior, e o total
    -- cresce de forma alcançável. O teto de todas as habilidades do servidor cabe em uma
    -- vida de jogo — se alguma passar disso, é erro de config, não de teste.
    local previousCost
    for level = 2, conf.maxLevel do
        local cost = Xp.totalForLevel(skill, level) - Xp.totalForLevel(skill, level - 1)
        T.truthy(cost > 0, skill .. ': nível ' .. level .. ' precisa custar XP')
        if previousCost then
            T.truthy(cost >= previousCost, skill .. ': o custo nunca cai de um nível para o outro')
        end
        previousCost = cost
    end

    T.truthy(Xp.maxXp(skill) < 1000000, skill .. ': o total até o topo não pode ser inalcançável')
end

-- Contas de nível ------------------------------------------------------------------------
Xp.build({
    teste = { label = 'Teste', icon = 'box', color = '#FFFFFF', baseXp = 100, growth = 2, maxLevel = 4 },
})
-- thresholds: 0, 100, 300, 700
T.equal(#Xp.configErrors, 0, 'config de teste é válido')
T.equal(Xp.totalForLevel('teste', 2), 100, 'nível 2 pede 100')
T.equal(Xp.totalForLevel('teste', 3), 300, 'nível 3 pede 100 + 200')
T.equal(Xp.totalForLevel('teste', 4), 700, 'nível 4 pede 100 + 200 + 400')
T.equal(Xp.maxXp('teste'), 700, 'o teto é o XP do último nível')

T.equal(Xp.levelFor('teste', 0), 1, 'zero de XP é nível 1')
T.equal(Xp.levelFor('teste', 99), 1, 'um XP abaixo do corte ainda é nível 1')
T.equal(Xp.levelFor('teste', 100), 2, 'no corte exato já subiu')
T.equal(Xp.levelFor('teste', 699), 3, 'um abaixo do topo ainda não é topo')
T.equal(Xp.levelFor('teste', 700), 4, 'no corte do topo é topo')
T.equal(Xp.levelFor('teste', 99999), 4, 'XP acima do teto não inventa nível')

-- Progresso ------------------------------------------------------------------------------
local progress = Xp.progress('teste', 150)
T.equal(progress.level, 2, 'progresso: nível certo')
T.equal(progress.xp, 50, 'progresso: XP é contado dentro do nível')
T.equal(progress.need, 200, 'progresso: o que falta é o custo do nível atual')
T.equal(progress.totalXp, 150, 'progresso: o XP bruto continua disponível')
T.equal(progress.ratio, 0.25, 'progresso: a barra é XP no nível / custo do nível')

local topo = Xp.progress('teste', 700)
T.equal(topo.level, 4, 'no topo o nível é o máximo')
T.equal(topo.need, nil, 'no topo não existe próximo nível')
T.equal(topo.ratio, 1, 'no topo a barra está cheia')

-- XP acima do teto é grampeado, não acumulado: quem passou do máximo não guarda crédito
-- para um nível que não existe.
T.equal(Xp.progress('teste', 5000).totalXp, 700, 'o progresso grampeia o XP no teto')
T.equal(Xp.progress('teste', -50).totalXp, 0, 'XP negativo vira zero')

-- Habilidade desconhecida ------------------------------------------------------------------
T.falsy(Xp.exists('inexistente'), 'habilidade fora do config não existe')
T.equal(Xp.progress('inexistente', 10), nil, 'progresso de habilidade desconhecida é nil')
T.equal(Xp.levelFor('inexistente', 10), 1, 'nível de habilidade desconhecida é 1, não erro')

-- Validação de config ----------------------------------------------------------------------
Xp.build({
    semLabel = { icon = 'box', color = '#FFFFFF', baseXp = 100, growth = 1.1, maxLevel = 5 },
    corRuim = { label = 'X', icon = 'box', color = 'vermelho', baseXp = 100, growth = 1.1, maxLevel = 5 },
    nivelRuim = { label = 'X', icon = 'box', color = '#FFFFFF', baseXp = 100, growth = 1.1, maxLevel = 1 },
    encolhendo = { label = 'X', icon = 'box', color = '#FFFFFF', baseXp = 100, growth = 0.5, maxLevel = 5 },
})
T.equal(#Xp.configErrors, 4, 'cada habilidade quebrada reporta o seu erro')
T.falsy(Xp.exists('corRuim'), 'habilidade inválida não entra na tabela')

-- Devolve o config real para quem rodar outro spec no mesmo processo.
Xp.build(Config.Skills)

print('xp_spec: ok')
