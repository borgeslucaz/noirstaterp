NoirStore = { active = {}, ready = false }

local schema = [[
CREATE TABLE IF NOT EXISTS noir_graffiti (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    graffiti_type VARCHAR(16) NOT NULL DEFAULT 'text',
    text_value VARCHAR(64) NOT NULL,
    font VARCHAR(64) NOT NULL,
    color VARCHAR(16) NOT NULL,
    gang_name VARCHAR(64) NULL,
    x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
    normal_x FLOAT NOT NULL, normal_y FLOAT NOT NULL, normal_z FLOAT NOT NULL,
    rotation FLOAT NOT NULL DEFAULT 0, scale FLOAT NOT NULL DEFAULT 1,
    territory_id VARCHAR(64) NULL,
    placed_by VARCHAR(64) NOT NULL,
    placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_by VARCHAR(64) NULL, removed_at TIMESTAMP NULL,
    PRIMARY KEY (id),
    INDEX idx_noir_graffiti_gang (gang_name),
    INDEX idx_noir_graffiti_territory (territory_id),
    INDEX idx_noir_graffiti_active (removed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]]

local function serialize(row)
    return {
        id = tonumber(row.id), type = row.graffiti_type, text = row.text_value, font = row.font, color = row.color,
        gang = row.gang_name, territory = row.territory_id, placedBy = row.placed_by, placedAt = row.placed_at,
        coords = vector3(row.x + 0.0, row.y + 0.0, row.z + 0.0),
        normal = vector3(row.normal_x + 0.0, row.normal_y + 0.0, row.normal_z + 0.0),
        rotation = row.rotation, scale = row.scale,
    }
end

function NoirStore.load()
    NoirStore.active = {}
    local rows = MySQL.query.await('SELECT * FROM noir_graffiti WHERE removed_at IS NULL') or {}
    for _, row in ipairs(rows) do local graffiti = serialize(row); NoirStore.active[graffiti.id] = graffiti end
    NoirStore.ready = true
end

function NoirStore.insert(data)
    local id = MySQL.insert.await([[
        INSERT INTO noir_graffiti
        (graffiti_type,text_value,font,color,gang_name,x,y,z,normal_x,normal_y,normal_z,rotation,scale,territory_id,placed_by)
        VALUES ('text',?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ]], {
        data.text, data.font, data.color, data.gang, data.coords.x, data.coords.y, data.coords.z,
        data.normal.x, data.normal.y, data.normal.z, data.rotation, data.scale, data.territory, data.placedBy,
    })
    if not id then return end
    data.id, data.type, data.placedAt = id, 'text', os.date('%Y-%m-%d %H:%M:%S')
    NoirStore.active[id] = data
    return data
end

function NoirStore.softDelete(id, citizenId)
    id = tonumber(id)
    local graffiti = id and NoirStore.active[id]
    if not graffiti then return end
    local changed = MySQL.update.await('UPDATE noir_graffiti SET removed_at=NOW(), removed_by=? WHERE id=? AND removed_at IS NULL', { citizenId, id })
    if not changed or changed < 1 then return end
    NoirStore.active[id] = nil
    return graffiti
end

function NoirStore.list()
    local result = {}
    for _, graffiti in pairs(NoirStore.active) do result[#result + 1] = graffiti end
    table.sort(result, function(a, b) return a.id > b.id end)
    return result
end

MySQL.ready(function()
    MySQL.query.await(schema)
    NoirStore.load()
end)
