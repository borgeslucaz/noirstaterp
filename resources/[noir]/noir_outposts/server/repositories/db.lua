-- Ponto único de acesso ao oxmysql. Todas as queries são parametrizadas.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Db = {}
NoirOutposts.Db = Db

local Log = NoirOutposts.Log

local function guarded(kind, sql, parameters)
    local ok, result = pcall(function()
        return MySQL[kind].await(sql, parameters or {})
    end)
    if not ok then
        Log.error('sql_failed', { kind = kind, sql = sql:sub(1, 96), error = tostring(result) })
        return nil, 'database_error'
    end
    return result
end

---@return table[]? rows, string? err
function Db.rows(sql, parameters)
    local rows, err = guarded('query', sql, parameters)
    if rows == nil then return nil, err end
    return rows
end

---@return table? row, string? err
function Db.single(sql, parameters)
    local row, err = guarded('single', sql, parameters)
    if err then return nil, err end
    return row
end

---@return any value, string? err
function Db.scalar(sql, parameters)
    return guarded('scalar', sql, parameters)
end

---@return integer? affectedRows, string? err
function Db.update(sql, parameters)
    local affected, err = guarded('update', sql, parameters)
    if affected == nil then return nil, err end
    return affected
end

---@return integer? insertId, string? err
function Db.insert(sql, parameters)
    local id, err = guarded('insert', sql, parameters)
    if id == nil then return nil, err end
    return id
end

---Executa DDL (apenas migrations).
function Db.execute(sql)
    return guarded('query', sql, {})
end

function Db.now()
    return os.time()
end
