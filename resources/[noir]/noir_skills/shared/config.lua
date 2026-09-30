Config = {}

-- Ace dos comandos de admin (`/addskillxp`, `/setskilllevel`, `/resetskill`).
Config.AdminAce = 'noir.skills'

-- Comando do painel. Sem tecla: o painel abre pelo radial (Cidadão → Habilidades).
Config.Command = 'skills'

-- Aviso de "subiu de nível" na tela do jogador.
Config.NotifyLevelUp = true

-- ---------------------------------------------------------------------------
-- Curva de XP
-- ---------------------------------------------------------------------------
-- Cada habilidade tem a sua. `baseXp` é o XP para sair do nível 1 para o 2; a cada nível
-- o custo do próximo é multiplicado por `growth`. O total para chegar ao nível máximo é a
-- soma disso tudo — com `growth` alto e `maxLevel` alto o número explode rápido
-- (1.4^99 é quatrilhão), então o upstream tinha níveis inalcançáveis por construção.
-- A regra prática: `growth` entre 1.05 e 1.25, e `maxLevel` no que o jogador consegue
-- alcançar jogando. `/skillcurve <habilidade>` imprime a tabela inteira no console do
-- servidor para conferir antes de publicar.
--
-- `titles` (opcional) dá um nome a cada faixa: o título vale do nível indicado até o próximo,
-- aparece no painel junto com o próximo a alcançar e entra no aviso de subida de nível. É o
-- marco visível entre um nível e outro (docs/Recompensa e progressão no roleplay).
--
-- `icon` é um nome do conjunto embutido na UI (car, gun, key, flask, wrench, box, chart,
-- leaf, fish, hammer); nome desconhecido cai num ícone padrão, sem quebrar nada.
---@class SkillConfig
---@field label string
---@field baseXp number   XP do nível 1 para o 2
---@field growth number   multiplicador do custo a cada nível
---@field maxLevel number
---@field icon string
---@field color string
---@field titles? { level: integer, title: string }[] título a partir de cada nível, em ordem

---@type table<string, SkillConfig>
Config.Skills = {
    arrombamento = {
        label = 'Arrombamento',
        baseXp = 90,
        growth = 1.18,
        maxLevel = 15,
        icon = 'key',
        color = '#FFC96B',
        titles = {
            { level = 1, title = 'Curioso' },
            { level = 5, title = 'Chaveiro' },
            { level = 10, title = 'Arrombador' },
            { level = 15, title = 'Mão Leve' },
        },
    },
    mecanica = {
        label = 'Mecânica',
        baseXp = 110,
        growth = 1.12,
        maxLevel = 20,
        icon = 'wrench',
        color = '#9BE8FF',
        titles = {
            { level = 1, title = 'Ajudante' },
            { level = 5, title = 'Mecânico' },
            { level = 10, title = 'Mecânico Sênior' },
            { level = 15, title = 'Chefe de Oficina' },
            { level = 20, title = 'Mestre Mecânico' },
        },
    },
    -- Venda de droga na rua. Quem dá o XP é o noir_drugselling, a cada venda fechada, no
    -- valor do `saleEXP` do tipo de ped (5 a 50). O nível aqui vira o bônus de preço de lá,
    -- pela tabela `Config.Leveling.LevelsList` daquele resource.
    trafico = {
        label = 'Tráfico',
        baseXp = 90,
        growth = 1.12,
        maxLevel = 15,
        icon = 'leaf',
        color = '#C48BFF',
        titles = {
            { level = 1, title = 'Aviãozinho' },
            { level = 5, title = 'Vapor' },
            { level = 10, title = 'Gerente' },
            { level = 15, title = 'Dono da Boca' },
        },
    },
    -- Plantio de maconha. Quem dá o XP é o noir_weed, na colheita, proporcional aos buds
    -- colhidos (cuidar bem sobe mais rápido). O nível abre as vantagens de lá (colheita, teto
    -- do grau, planta bebe menos, cresce mais rápido, devolve semente, vaso extra), por faixas
    -- em `skill` no config/server.lua daquele resource. Com ~30 XP por planta bem cuidada, o
    -- primeiro ciclo de 5 plantas já leva ao nível 2, e o nível 15 (~6.100 XP) fica em ~40
    -- ciclos.
    cultivo = {
        label = 'Cultivo',
        baseXp = 150,
        growth = 1.15,
        maxLevel = 15,
        icon = 'leaf',
        color = '#7BD88F',
        titles = {
            { level = 1, title = 'Curioso' },
            { level = 5, title = 'Jardineiro' },
            { level = 9, title = 'Cultivador' },
            { level = 11, title = 'Botânico' },
            { level = 15, title = 'Mestre do Cultivo' },
        },
    },
}
