Config = {}

-- Ace dos comandos de admin (`/addskillxp`, `/setskilllevel`, `/resetskill`).
Config.AdminAce = 'noir.skills'

-- Comando e tecla do painel. A tecla é só o padrão: o jogador troca em Configurações →
-- Atalhos de Teclado, e a escolha dele manda.
Config.Command = 'skills'
Config.Hotkey = 'J'

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
-- `icon` é um nome do conjunto embutido na UI (car, gun, key, flask, wrench, box, chart,
-- leaf, fish, hammer); nome desconhecido cai num ícone padrão, sem quebrar nada.
---@class SkillConfig
---@field label string
---@field baseXp number   XP do nível 1 para o 2
---@field growth number   multiplicador do custo a cada nível
---@field maxLevel number
---@field icon string
---@field color string

---@type table<string, SkillConfig>
Config.Skills = {
    arrombamento = {
        label = 'Arrombamento',
        baseXp = 90,
        growth = 1.18,
        maxLevel = 15,
        icon = 'key',
        color = '#FFC96B',
    },
    mecanica = {
        label = 'Mecânica',
        baseXp = 110,
        growth = 1.12,
        maxLevel = 20,
        icon = 'wrench',
        color = '#9BE8FF',
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
    },
}
