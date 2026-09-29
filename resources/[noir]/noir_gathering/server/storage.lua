---Único ponto de SQL do resource. Só toca `noir_gathering_routes`.

local Storage = {}

local ready = false

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
    ready = true
end

---@return boolean
function Storage.isReady()
    return ready
end

---@return { id: integer, name: string, data: string }[]
function Storage.loadAll()
    return MySQL.query.await('SELECT id, name, data FROM noir_gathering_routes ORDER BY id') or {}
end

---@param name string
---@param data string json
---@return integer? id
---@return string? errorCode
function Storage.insert(name, data)
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO noir_gathering_routes (name, data) VALUES (?, ?)', { name, data })
    if not ok then
        return nil, tostring(id):find('Duplicate', 1, true) and 'duplicate_name' or 'storage_failed'
    end
    if type(id) ~= 'number' or id <= 0 then return nil, 'storage_failed' end
    return id
end

---`MySQL.update.await` devolve o número de linhas afetadas; `query.await` num UPDATE
---devolveria uma tabela, e compará-la com número estoura.
---@param id integer
---@param name string
---@param data string json
---@return boolean ok
---@return string? errorCode
function Storage.update(id, name, data)
    local ok, affected = pcall(MySQL.update.await,
        'UPDATE noir_gathering_routes SET name = ?, data = ? WHERE id = ?', { name, data, id })
    if not ok then
        return false, tostring(affected):find('Duplicate', 1, true) and 'duplicate_name' or 'storage_failed'
    end
    if type(affected) ~= 'number' then return false, 'storage_failed' end
    -- 0 linhas também acontece quando nada mudou; a existência é conferida por quem chama.
    return true
end

---@param id integer
---@return boolean
function Storage.delete(id)
    local ok, affected = pcall(MySQL.update.await, 'DELETE FROM noir_gathering_routes WHERE id = ?', { id })
    return ok and type(affected) == 'number' and affected > 0
end

return Storage
