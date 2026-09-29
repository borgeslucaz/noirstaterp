---Único ponto de SQL do resource. Só toca `noir_weed_plants`.
---
---O nome não é `weed_plants` de propósito: essa tabela existe no banco com o schema do
---qbx_weed.

local Storage = {}

---Roda as migrations. Só `CREATE TABLE IF NOT EXISTS` é aceito: migration destrutiva
---não roda sozinha no boot.
function Storage.migrate()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_initial.sql')
    if not sql or sql == '' then error('migrations/001_initial.sql não encontrada') end

    for raw in sql:gmatch('([^;]+);') do
        local statement = raw:match('^%s*(.-)%s*$')
        if statement ~= '' then
            if not statement:upper():match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') then
                error(('comando não permitido na migration: %s'):format(statement:sub(1, 80)))
            end
            MySQL.query.await(statement)
        end
    end
end

---@return table[]
function Storage.loadAll()
    return MySQL.query.await([[
        SELECT id, owner, seed, x, y, z, heading, growth, health, water, fertilizer
        FROM noir_weed_plants
    ]]) or {}
end

---@param plant table
---@return integer? id
function Storage.insert(plant)
    local ok, id = pcall(MySQL.insert.await, [[
        INSERT INTO noir_weed_plants (owner, seed, x, y, z, heading, growth, health, water, fertilizer)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        plant.owner, plant.seed, plant.x, plant.y, plant.z, plant.heading,
        plant.growth, plant.health, plant.water, plant.fertilizer,
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
            query = 'UPDATE noir_weed_plants SET growth = ?, health = ?, water = ?, fertilizer = ? WHERE id = ?',
            values = { plant.growth, plant.health, plant.water, plant.fertilizer, plant.id },
        }
    end
    local ok, err = pcall(MySQL.transaction.await, queries)
    if not ok then lib.print.error(('gravação do status falhou: %s'):format(tostring(err))) end
end

return Storage
