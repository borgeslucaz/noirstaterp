---Desenha a colisão do interior mrp_house (dados de data_mrp_house.lua) na casa mais
---próxima: faces em vermelho translúcido, arestas brancas e o número do triângulo nas
---faces maiores perto do personagem. Vermelho onde não há parede visível = colisão
---invisível; o número é o que se tira do .ybn.

local enabled = false
local selected = {}   -- { a, b, c, id, centro, área }
local labels = {}

local function rotation(qx, qy, qz, qw)
    return {
        { 1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw) },
        { 2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw) },
        { 2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy) },
    }
end

local function toWorld(h, R, x, y, z)
    return vec3(h[1] + R[1][1] * x + R[1][2] * y + R[1][3] * z,
        h[2] + R[2][1] * x + R[2][2] * y + R[2][3] * z,
        h[3] + R[3][1] * x + R[3][2] * y + R[3][3] * z)
end

local function refresh()
    local pos = GetEntityCoords(cache.ped)
    local house, best = nil, 30.0
    for _, h in ipairs(ColprobeData.houses) do
        local d = #(pos - vec3(h[1], h[2], h[3]))
        if d < best then house, best = h, d end
    end
    selected, labels = {}, {}
    if not house then return end
    local R = rotation(house[4], house[5], house[6], house[7])
    for _, t in ipairs(ColprobeData.tris) do
        local a = toWorld(house, R, t[2], t[3], t[4])
        local b = toWorld(house, R, t[5], t[6], t[7])
        local c = toWorld(house, R, t[8], t[9], t[10])
        local centre = (a + b + c) / 3
        if #(centre - pos) < 6.0 then
            local cross = (b - a)
            local other = (c - a)
            local area = #vec3(cross.y * other.z - cross.z * other.y, cross.z * other.x - cross.x * other.z,
                cross.x * other.y - cross.y * other.x) / 2
            selected[#selected + 1] = { a, b, c, t[1], centre, area }
        end
    end
    table.sort(selected, function(p, q) return #(p[5] - pos) < #(q[5] - pos) end)
    for _, s in ipairs(selected) do
        if s[6] >= 0.5 and #(s[5] - pos) < 4.0 then labels[#labels + 1] = s end
        if #labels >= 25 then break end
    end
end

local function text3d(at, str)
    SetDrawOrigin(at.x, at.y, at.z, 0)
    SetTextScale(0.0, 0.28)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 255, 0, 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNetEvent('noir_colprobe:colview', function()
    enabled = not enabled
    lib.notify({ title = 'colview', description = enabled and 'ligado' or 'desligado' })
    if not enabled then return end
    CreateThread(function()
        while enabled do
            refresh()
            Wait(500)
        end
    end)
    CreateThread(function()
        while enabled do
            for _, s in ipairs(selected) do
                local a, b, c = s[1], s[2], s[3]
                DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 0, 0, 70)
                DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z, 255, 0, 0, 70)
                DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 255, 255, 255, 120)
                DrawLine(b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 120)
                DrawLine(c.x, c.y, c.z, a.x, a.y, a.z, 255, 255, 255, 120)
            end
            for _, s in ipairs(labels) do text3d(s[5], tostring(s[4])) end
            Wait(0)
        end
    end)
end)
