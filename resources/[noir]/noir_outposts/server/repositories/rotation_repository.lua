NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Repo = {}
NoirOutposts.Repositories.Rotation = Repo

local Db = NoirOutposts.Db

---@param cycleKey string
---@return table? row { id, cycle_key, starts_at, ends_at, state (decoded) }
function Repo.getByCycle(cycleKey)
    local row = Db.single('SELECT id, cycle_key, starts_at, ends_at, state FROM noir_outpost_rotations WHERE cycle_key = ?',
        { cycleKey })
    if not row then return nil end
    if type(row.state) == 'string' then
        local ok, decoded = pcall(json.decode, row.state)
        row.state = ok and decoded or {}
    end
    return row
end

---@param cycleKey string
---@param startsAt integer
---@param endsAt integer
---@param state table
---@return integer? id
function Repo.insert(cycleKey, startsAt, endsAt, state)
    return Db.insert([[
        INSERT IGNORE INTO noir_outpost_rotations (cycle_key, starts_at, ends_at, state, created_at)
        VALUES (?, ?, ?, ?, ?)
    ]], { cycleKey, startsAt, endsAt, json.encode(state), os.time() })
end

---@return table? row
function Repo.latest()
    local row = Db.single('SELECT id, cycle_key, starts_at, ends_at, state FROM noir_outpost_rotations ORDER BY id DESC LIMIT 1')
    if row and type(row.state) == 'string' then
        local ok, decoded = pcall(json.decode, row.state)
        row.state = ok and decoded or {}
    end
    return row
end
