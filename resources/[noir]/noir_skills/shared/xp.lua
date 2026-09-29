-- Curva de XP. Módulo puro: só lê `Config.Skills` e faz conta, sem banco, sem native e
-- sem estado de jogador. Roda igual nos dois lados (por isso é shared) e é o que os
-- testes exercitam.
NoirSkills = NoirSkills or {}

local Xp = {}

-- [habilidade][nível] = XP total acumulado necessário para ESTAR naquele nível.
-- thresholds[1] é sempre 0: todo mundo começa no nível 1 com 0 de XP.
local thresholds = {}

---Erros de config encontrados no build. O servidor derruba o start se houver algum —
---habilidade mal configurada não estoura sozinha, ela só entrega número errado para
---sempre.
---@type string[]
Xp.configErrors = {}

---@param skill string
---@param conf table
---@return string[] errors
local function validateSkill(skill, conf)
    local errors = {}

    local function check(condition, message)
        if not condition then errors[#errors + 1] = ('%s: %s'):format(skill, message) end
    end

    check(type(conf) == 'table', 'config precisa ser uma tabela')
    if type(conf) ~= 'table' then return errors end

    check(type(conf.label) == 'string' and conf.label ~= '', 'label precisa ser um texto')
    check(type(conf.icon) == 'string' and conf.icon ~= '', 'icon precisa ser um texto')
    check(type(conf.color) == 'string' and conf.color:match('^#%x%x%x%x%x%x$') ~= nil,
        'color precisa ser hex no formato #RRGGBB')
    check(type(conf.baseXp) == 'number' and conf.baseXp >= 1, 'baseXp precisa ser um número >= 1')
    check(type(conf.growth) == 'number' and conf.growth >= 1, 'growth precisa ser um número >= 1')
    check(type(conf.maxLevel) == 'number' and conf.maxLevel >= 2 and conf.maxLevel % 1 == 0,
        'maxLevel precisa ser um inteiro >= 2')

    return errors
end

---@param skills table<string, table>
function Xp.build(skills)
    thresholds = {}
    Xp.configErrors = {}

    for skill, conf in pairs(skills or {}) do
        local errors = validateSkill(skill, conf)
        if #errors > 0 then
            for i = 1, #errors do
                Xp.configErrors[#Xp.configErrors + 1] = errors[i]
            end
        else
            local table_ = { 0 }
            local cost = conf.baseXp
            for level = 2, conf.maxLevel do
                table_[level] = table_[level - 1] + math.ceil(cost)
                cost = cost * conf.growth
            end
            thresholds[skill] = table_
        end
    end
end

---@param skill string
---@return boolean
function Xp.exists(skill)
    return thresholds[skill] ~= nil
end

---@return string[] habilidades configuradas, em ordem estável
function Xp.list()
    local names = {}
    for skill in pairs(thresholds) do names[#names + 1] = skill end
    table.sort(names)
    return names
end

---@param skill string
---@return number
function Xp.maxLevel(skill)
    local table_ = thresholds[skill]
    return table_ and #table_ or 0
end

---XP total acumulado para estar em `level`. Nível fora da faixa é grampeado na borda,
---porque quem chama isso normalmente já validou e o resto do código prefere um número a
---um nil.
---@param skill string
---@param level number
---@return number
function Xp.totalForLevel(skill, level)
    local table_ = thresholds[skill]
    if not table_ then return 0 end
    if level < 1 then level = 1 end
    if level > #table_ then level = #table_ end
    return table_[level]
end

---Teto de XP da habilidade: passar disso não muda mais nada, então o XP é grampeado aqui
---na gravação em vez de crescer para sempre no banco.
---@param skill string
---@return number
function Xp.maxXp(skill)
    return Xp.totalForLevel(skill, Xp.maxLevel(skill))
end

---@param skill string
---@param xp number
---@return number level
function Xp.levelFor(skill, xp)
    local table_ = thresholds[skill]
    if not table_ then return 1 end

    local level = 1
    for candidate = 2, #table_ do
        if xp >= table_[candidate] then level = candidate else break end
    end
    return level
end

---Estado completo de uma habilidade a partir do XP bruto — é isto que a UI desenha.
---`xp`/`need` são dentro do nível atual (barra de progresso); `need` é nil no topo.
---@param skill string
---@param xp number
---@return { level: number, maxLevel: number, xp: number, need: number|nil, totalXp: number, ratio: number }|nil
function Xp.progress(skill, xp)
    local table_ = thresholds[skill]
    if not table_ then return nil end

    xp = math.max(0, math.min(xp or 0, table_[#table_]))

    local level = Xp.levelFor(skill, xp)
    local floor = table_[level]
    local ceiling = table_[level + 1]
    local need = ceiling and (ceiling - floor) or nil

    return {
        level = level,
        maxLevel = #table_,
        xp = xp - floor,
        need = need,
        totalXp = xp,
        ratio = need and ((xp - floor) / need) or 1,
    }
end

NoirSkills.xp = Xp

if Config and Config.Skills then
    Xp.build(Config.Skills)
end
