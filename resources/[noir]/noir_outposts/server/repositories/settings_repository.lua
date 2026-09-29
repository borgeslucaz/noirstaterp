NoirOutposts = NoirOutposts or {}
NoirOutposts.Repositories = NoirOutposts.Repositories or {}

local Repo = {}
NoirOutposts.Repositories.Settings = Repo

local Db = NoirOutposts.Db

---@param citizenId string
---@return table? row { citizenid, feed_cleared_at, alerts }
function Repo.get(citizenId)
    local row = Db.single(
        'SELECT citizenid, feed_cleared_at, alerts FROM noir_outpost_player_settings WHERE citizenid = ?',
        { citizenId })
    if row and type(row.alerts) == 'string' then
        local ok, decoded = pcall(json.decode, row.alerts)
        row.alerts = ok and type(decoded) == 'table' and decoded or nil
    end
    return row
end

---@param citizenId string
---@param alerts table
---@return boolean ok
function Repo.setAlerts(citizenId, alerts)
    local id = Db.insert([[
        INSERT INTO noir_outpost_player_settings (citizenid, alerts)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE alerts = VALUES(alerts)
    ]], { citizenId, json.encode(alerts) })
    return id ~= nil
end

---@param citizenId string
---@param clearedAt integer
---@return boolean ok
function Repo.setClearedAt(citizenId, clearedAt)
    local id = Db.insert([[
        INSERT INTO noir_outpost_player_settings (citizenid, feed_cleared_at)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE feed_cleared_at = VALUES(feed_cleared_at)
    ]], { citizenId, clearedAt })
    return id ~= nil
end
