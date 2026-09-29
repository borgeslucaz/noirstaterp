-- Persistência. O resto do resource não escreve SQL.
NoirSkills = NoirSkills or {}

local Store = {}

-- O arquivo de migração roda inteiro a cada start, então nada ali pode apagar dado:
-- só DDL idempotente e não destrutivo passa. `DROP`, `MODIFY` e `RENAME` são recusados
-- e abortam o start.
local ALLOWED_STATEMENTS = {
    '^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+',
    '^CREATE%s+INDEX%s+IF%s+NOT%s+EXISTS%s+',
    '^ALTER%s+TABLE%s+[%w_`]+%s+ADD%s+COLUMN%s+IF%s+NOT%s+EXISTS%s+',
}

local function isAllowedStatement(statement)
    local upper = statement:upper()
    for i = 1, #ALLOWED_STATEMENTS do
        if upper:match(ALLOWED_STATEMENTS[i]) then return true end
    end
    return false
end

---@return boolean ok
function Store.runSchema()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/noir_skills.sql')
    if not sql or sql == '' then
        lib.print.error('[noir_skills] migrations/noir_skills.sql não encontrado')
        return false
    end

    -- Tira comentários antes de separar por `;`, senão um ponto e vírgula dentro de
    -- comentário vira o começo de um statement falso.
    sql = sql:gsub('%-%-[^\r\n]*', '')

    local executed = 0
    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = rawStatement:gsub('^%s*(.-)%s*$', '%1')
        if statement ~= '' then
            if not isAllowedStatement(statement) then
                lib.print.error(('[noir_skills] statement recusado: %s'):format(statement:sub(1, 80)))
                return false
            end
            MySQL.query.await(statement)
            executed = executed + 1
        end
    end

    if executed == 0 then
        lib.print.error('[noir_skills] migrations/noir_skills.sql não tem statements')
        return false
    end
    return true
end

---XP bruto de um personagem, por habilidade. Habilidade que saiu do config continua no
---banco e é ignorada aqui: tirar uma habilidade do config não apaga o progresso de
---ninguém, e devolvê-la ao config devolve o XP junto.
---@param citizenid string
---@return table<string, number>
function Store.load(citizenid)
    local rows = MySQL.query.await('SELECT skill, xp FROM noir_skills WHERE citizenid = ?', { citizenid })
    local xp = {}

    for i = 1, #(rows or {}) do
        local row = rows[i]
        if NoirSkills.xp.exists(row.skill) then
            xp[row.skill] = tonumber(row.xp) or 0
        end
    end

    return xp
end

---Grava o XP absoluto. Upsert em vez de INSERT no login: linha só existe para quem
---realmente ganhou XP, e não há escrita nenhuma quando o jogador entra.
---
---Sem `await` de propósito. O cache em memória é a fonte de verdade enquanto o jogador
---está online, então nada precisa esperar o banco — e quem chama `AddXp` é outro resource,
---de um contexto que pode não ser corrotina.
---@param citizenid string
---@param skill string
---@param xp number
function Store.save(citizenid, skill, xp)
    MySQL.prepare([[
        INSERT INTO noir_skills (citizenid, skill, xp) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = VALUES(xp)
    ]], { citizenid, skill, xp })
end

---Ranking de uma habilidade, para placar ou consulta de admin.
---@param skill string
---@param limit? number
---@return { citizenid: string, xp: number }[]
function Store.top(skill, limit)
    return MySQL.query.await(
        'SELECT citizenid, xp FROM noir_skills WHERE skill = ? ORDER BY xp DESC LIMIT ?',
        { skill, limit or 10 }) or {}
end

NoirSkills.store = Store
