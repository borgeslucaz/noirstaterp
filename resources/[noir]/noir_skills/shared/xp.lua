-- Curva de XP. Módulo puro: só lê `Config.Skills` e faz conta, sem banco, sem native e
-- sem estado de jogador. Roda igual nos dois lados (por isso é shared) e é o que os
-- testes exercitam.
NoirSkills = NoirSkills or {}

local Xp = {}

-- [habilidade][nível] = XP total acumulado necessário para ESTAR naquele nível.
-- thresholds[1] é sempre 0: todo mundo começa no nível 1 com 0 de XP.
local thresholds = {}

-- [habilidade] = { { level, title }, ... } em ordem crescente de nível. Opcional.
local titles = {}

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

    if conf.titles ~= nil then
        check(type(conf.titles) == 'table', 'titles precisa ser uma lista')
        if type(conf.titles) == 'table' then
            local previous = 0
            for index, entry in ipairs(conf.titles) do
                local level = type(entry) == 'table' and entry.level or nil
                local ok = type(level) == 'number' and level % 1 == 0 and level > previous
                    and (type(conf.maxLevel) ~= 'number' or level <= conf.maxLevel)
                check(ok, ('titles[%d]: level precisa ser inteiro, crescente e até o maxLevel'):format(index))
                check(type(entry) == 'table' and type(entry.title) == 'string' and entry.title ~= '',
                    ('titles[%d]: title precisa ser um texto'):format(index))
                if ok then previous = level end
            end
        end
    end

    return errors
end

---@param skills table<string, table>
function Xp.build(skills)
    thresholds = {}
    titles = {}
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

            local list = {}
            for _, entry in ipairs(conf.titles or {}) do
                list[#list + 1] = { level = entry.level, title = entry.title }
            end
            titles[skill] = list
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

---Título do nível: o da última faixa alcançada, ou nil (sem títulos, ou abaixo do primeiro).
---@param skill string
---@param level number
---@return string?
function Xp.titleFor(skill, level)
    local found
    for _, entry in ipairs(titles[skill] or {}) do
        if level >= entry.level then found = entry.title else break end
    end
    return found
end

---Próximo título que o nível ainda não alcançou, com o nível em que ele chega.
---@param skill string
---@param level number
---@return { level: number, title: string }?
function Xp.nextTitle(skill, level)
    for _, entry in ipairs(titles[skill] or {}) do
        if entry.level > level then return { level = entry.level, title = entry.title } end
    end
    return nil
end

---O nível `level` é exatamente o que abre um título?
---@param skill string
---@param level number
---@return string?
function Xp.titleUnlockedAt(skill, level)
    for _, entry in ipairs(titles[skill] or {}) do
        if entry.level == level then return entry.title end
    end
    return nil
end

---Estado completo de uma habilidade a partir do XP bruto — é isto que a UI desenha.
---`xp`/`need` são dentro do nível atual (barra de progresso); `need` é nil no topo.
---@param skill string
---@param xp number
---`title` é o título do nível atual; `nextTitle`, o próximo e o nível em que ele chega.
---@return { level: number, maxLevel: number, xp: number, need: number|nil, totalXp: number, ratio: number, title: string|nil, nextTitle: table|nil }|nil
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
        title = Xp.titleFor(skill, level),
        nextTitle = Xp.nextTitle(skill, level),
    }
end

NoirSkills.xp = Xp

if Config and Config.Skills then
    Xp.build(Config.Skills)
end
