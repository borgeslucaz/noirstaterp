---Único ponto de SQL do resource. Só toca `noir_weed_plants` e `noir_weed_tables`.
---
---O nome não é `weed_plants` de propósito: essa tabela existe no banco com o schema do
---qbx_weed.

local Storage = {}

---Migrations em ordem. Só comando que não destrói nada roda sozinho no boot: criar tabela
---que não existe e acrescentar coluna que não existe.
local MIGRATIONS = { '001_initial.sql', '002_care_grade.sql' }
local ALLOWED = {
    '^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+',
    '^ALTER%s+TABLE%s+[%w_]+%s+ADD%s+COLUMN%s+IF%s+NOT%s+EXISTS%s+',
}

---@param statement string
---@return boolean
local function allowed(statement)
    local upper = statement:upper()
    for index = 1, #ALLOWED do
        if upper:match(ALLOWED[index]) then return true end
    end
    return false
end

function Storage.migrate()
    for _, file in ipairs(MIGRATIONS) do
        local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/' .. file)
        if not sql or sql == '' then error(('migrations/%s não encontrada'):format(file)) end

        for raw in sql:gmatch('([^;]+);') do
            local statement = raw:match('^%s*(.-)%s*$')
            if statement ~= '' then
                if not allowed(statement) then
                    error(('comando não permitido na migration: %s'):format(statement:sub(1, 80)))
                end
                MySQL.query.await(statement)
            end
        end
    end
end

---@return table[]
function Storage.loadAll()
    return MySQL.query.await([[
        SELECT id, owner, seed, x, y, z, heading, growth, health, water, fertilizer,
            care_sum AS careSum, care_ticks AS careTicks, skill_level AS level
        FROM noir_weed_plants
    ]]) or {}
end

---@param plant table
---@return integer? id
function Storage.insert(plant)
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO noir_weed_plants
            (owner, seed, x, y, z, heading, growth, health, water, fertilizer, care_sum, care_ticks, skill_level)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        plant.owner, plant.seed, plant.x, plant.y, plant.z, plant.heading,
        plant.growth, plant.health, plant.water, plant.fertilizer, plant.careSum, plant.careTicks, plant.level,
    })
    if not ok then
        lib.print.error(('insert falhou: %s'):format(tostring(id)))
        return nil
    end
    return id
end

---@param id integer
function Storage.delete(id)
    MySQL.query('DELETE FROM noir_weed_plants WHERE id = ?', { id })
end

---@param plant table
function Storage.move(plant)
    MySQL.query('UPDATE noir_weed_plants SET x = ?, y = ?, z = ?, heading = ? WHERE id = ?',
        { plant.x, plant.y, plant.z, plant.heading, plant.id })
end

---Status de várias plantas numa transação. `await` porque no stop do resource a
---gravação precisa terminar antes de o processo sair.
---@param plants table[]
function Storage.saveStatus(plants)
    if #plants == 0 then return end
    local queries = {}
    for index = 1, #plants do
        local plant = plants[index]
        queries[index] = {
            query = [[
                UPDATE noir_weed_plants
                SET growth = ?, health = ?, water = ?, fertilizer = ?, care_sum = ?, care_ticks = ?
                WHERE id = ?
            ]],
            values = { plant.growth, plant.health, plant.water, plant.fertilizer, plant.careSum, plant.careTicks, plant.id },
        }
    end
    local ok, err = pcall(MySQL.transaction.await, queries)
    if not ok then lib.print.error(('gravação do status falhou: %s'):format(tostring(err))) end
end

-- Mesas -----------------------------------------------------------------------------

---@return table[]
function Storage.loadTables()
    return MySQL.query.await('SELECT id, owner, type, x, y, z, heading FROM noir_weed_tables') or {}
end

---@param bench table
---@return integer? id
function Storage.insertTable(bench)
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO noir_weed_tables (owner, type, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?)',
        { bench.owner, bench.type, bench.x, bench.y, bench.z, bench.heading })
    if not ok then
        lib.print.error(('insert de mesa falhou: %s'):format(tostring(id)))
        return nil
    end
    return id
end

---@param id integer
function Storage.deleteTable(id)
    MySQL.query('DELETE FROM noir_weed_tables WHERE id = ?', { id })
end

return Storage
