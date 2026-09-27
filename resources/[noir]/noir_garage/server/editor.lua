---Editor de garagens no jogo (/garagem). As garagens moram na tabela noir_garage_locations; no primeiro
---start ela e preenchida com as garagens do config/server.lua, que dai em diante so serve de semente.
---Tudo que chega do cliente e validado aqui: a tela so monta o rascunho.

local logger = require '@qbx_core.modules.logger'

local MAX_ACCESS_POINTS = 10
local MAX_GROUPS = 20

GaragesReady = false

---@param source number
---@return boolean
local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.adminAce)
end

-- ── JSON <-> vetores ──────────────────────────────────────────────────────

local function round(value)
    return math.floor(value * 100 + 0.5) / 100
end

---@param v vector3|vector4
local function vecToTable(v)
    if not v then return nil end
    local t = { x = round(v.x), y = round(v.y), z = round(v.z) }
    if type(v) == 'vector4' or (type(v) == 'table' and v.w) then t.w = round(v.w) end
    return t
end

local function tableToVec(t)
    if type(t) ~= 'table' then return nil end
    if t.w then return vec4(t.x, t.y, t.z, t.w) end
    return vec3(t.x, t.y, t.z)
end

local POINT_NUMBERS = { 'useRadius', 'dropUseRadius', 'drawRadius', 'dropDrawRadius' }

-- Animacoes do atendente: so estas (cenarios do jogo base). Vazio = parado.
local PED_SCENARIOS = {
    WORLD_HUMAN_CLIPBOARD = true,
    WORLD_HUMAN_GUARD_STAND = true,
    WORLD_HUMAN_STAND_MOBILE = true,
    WORLD_HUMAN_SMOKING = true,
}
local INTERACTIONS = { key = true, target = true }

---Garagem -> tabela so com dados (o que vai para o JSON e para a tela do editor).
---@param garage GarageConfig
local function serialize(garage)
    local points = {}
    for i, point in ipairs(garage.accessPoints) do
        local p = {
            coords = vecToTable(point.coords),
            spawn = vecToTable(point.spawn),
            dropPoint = vecToTable(point.dropPoint),
            blip = point.blip and { name = point.blip.name, sprite = point.blip.sprite, color = point.blip.color } or nil,
            ped = point.ped and {
                model = point.ped.model,
                scenario = point.ped.scenario,
                rotation = point.ped.rotation,
                position = point.ped.position and vecToTable(point.ped.position) or nil,
            } or nil,
            interaction = point.interaction,
        }
        for _, key in ipairs(POINT_NUMBERS) do p[key] = point[key] end
        points[i] = p
    end

    local groups = garage.groups
    if type(groups) == 'string' then
        groups = { [groups] = 0 }
    elseif type(groups) == 'table' and groups[1] then
        local byName = {}
        for _, name in ipairs(groups) do byName[name] = 0 end
        groups = byName
    end

    return {
        label = garage.label,
        vehicleType = garage.vehicleType,
        depot = garage.type == GarageType.DEPOT,
        shared = garage.shared == true,
        groups = groups,
        accessPoints = points,
    }
end

---Tabela validada -> GarageConfig usado pelo resto do resource.
local function deserialize(data)
    local points = {}
    for i, p in ipairs(data.accessPoints) do
        local point = {
            coords = tableToVec(p.coords),
            spawn = tableToVec(p.spawn),
            dropPoint = p.dropPoint and vec3(p.dropPoint.x, p.dropPoint.y, p.dropPoint.z) or nil,
            blip = p.blip,
            ped = p.ped,
            interaction = p.interaction,
        }
        for _, key in ipairs(POINT_NUMBERS) do point[key] = p[key] end
        points[i] = point
    end

    local garage = {
        label = data.label,
        vehicleType = data.vehicleType,
        groups = data.groups and next(data.groups) and data.groups or nil,
        shared = (not data.depot and data.shared) or nil,
        accessPoints = points,
    }
    if data.depot then
        garage.type = GarageType.DEPOT
        garage.states = { VehicleState.OUT, VehicleState.IMPOUNDED }
        garage.skipGarageCheck = true
    end
    return garage
end

-- ── Grupos (jobs e gangs) ─────────────────────────────────────────────────

---Jobs (Qbox) e gangs (noir_gangs), os dois pelo bgrz_core, com os cargos em lista ordenada.
---@return { jobs: table[], gangs: table[] }
local function groupOptions()
    local function withGrades(name, label, grades)
        local list = {}
        for level, gradeName in pairs(grades or {}) do
            list[#list + 1] = { level = level, name = type(gradeName) == 'table' and gradeName.name or gradeName }
        end
        table.sort(list, function(a, b) return a.level < b.level end)
        return { name = name, label = label, grades = list }
    end

    local jobs = {}
    for _, job in ipairs(exports.bgrz_core:GetJobList() or {}) do
        if job.name ~= 'unemployed' then
            jobs[#jobs + 1] = withGrades(job.name, job.label, job.grades)
        end
    end

    local gangs = {}
    for _, gang in ipairs(exports.bgrz_core:GetGangList() or {}) do
        local info = exports.bgrz_core:GetGangInfo(gang.name)
        gangs[#gangs + 1] = withGrades(gang.name, gang.label, info and info.grades)
    end
    return { jobs = jobs, gangs = gangs }
end

---@param groups table<string, integer>
---@return string? error
local function checkGroupsExist(groups)
    if not groups then return end
    local options = groupOptions()
    local known = {}
    for _, list in pairs(options) do
        for _, group in ipairs(list) do
            local levels = {}
            for _, grade in ipairs(group.grades) do levels[grade.level] = true end
            known[group.name] = levels
        end
    end
    for name, grade in pairs(groups) do
        if not known[name] then return ('O grupo %s não existe (nem job nem gang).'):format(name) end
        if next(known[name]) and not known[name][grade] then
            return ('O cargo %d não existe em %s.'):format(grade, name)
        end
    end
end

-- ── Validacao ─────────────────────────────────────────────────────────────

local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

---@return table? point, string? error
local function validPosition(t, withHeading)
    if type(t) ~= 'table' then return nil end
    if not (finite(t.x) and finite(t.y) and finite(t.z)) then return nil end
    if math.abs(t.x) > 20000 or math.abs(t.y) > 20000 or t.z < -500 or t.z > 3000 then return nil end
    local out = { x = round(t.x), y = round(t.y), z = round(t.z) }
    if withHeading then
        if not finite(t.w) then return nil end
        out.w = round(t.w % 360)
    end
    return out
end

local function validInteger(n, min, max)
    return finite(n) and n % 1 == 0 and n >= min and n <= max
end

local VEHICLE_TYPES = { [VehicleType.CAR] = true, [VehicleType.AIR] = true, [VehicleType.SEA] = true }

---@param input any
---@return table? data, string? error
local function validate(input)
    if type(input) ~= 'table' then return nil, 'Dados inválidos.' end

    local label = type(input.label) == 'string' and qbx.string.trim(input.label:gsub('[%c<>]', '')) or ''
    if label == '' or #label > 50 then return nil, 'O nome precisa ter entre 1 e 50 caracteres.' end

    if not VEHICLE_TYPES[input.vehicleType] then return nil, 'Tipo de veículo inválido.' end

    local groups
    if input.groups ~= nil then
        if type(input.groups) ~= 'table' then return nil, 'Grupos inválidos.' end
        groups = {}
        local count = 0
        for name, grade in pairs(input.groups) do
            count = count + 1
            if count > MAX_GROUPS then return nil, 'Grupos demais.' end
            if type(name) ~= 'string' or not name:match('^[%w_%-]+$') or #name > 40 then
                return nil, ('Grupo inválido: %s'):format(tostring(name))
            end
            if not validInteger(grade, 0, 50) then return nil, ('Cargo inválido para %s.'):format(name) end
            groups[name] = grade
        end
    end

    if type(input.accessPoints) ~= 'table' or #input.accessPoints == 0 then
        return nil, 'A garagem precisa de pelo menos um ponto de acesso.'
    end
    if #input.accessPoints > MAX_ACCESS_POINTS then return nil, 'Pontos de acesso demais.' end

    local points = {}
    for i, p in ipairs(input.accessPoints) do
        if type(p) ~= 'table' then return nil, ('Ponto %d inválido.'):format(i) end
        local coords = validPosition(p.coords, true)
        if not coords then return nil, ('Ponto %d: marque o balcão.'):format(i) end
        local point = { coords = coords }

        if p.spawn ~= nil then
            point.spawn = validPosition(p.spawn, true)
            if not point.spawn then return nil, ('Ponto %d: saída inválida.'):format(i) end
        end
        if p.dropPoint ~= nil then
            point.dropPoint = validPosition(p.dropPoint, false)
            if not point.dropPoint then return nil, ('Ponto %d: ponto de guardar inválido.'):format(i) end
        end
        if p.blip ~= nil then
            local b = p.blip
            if type(b) ~= 'table' then return nil, ('Ponto %d: blip inválido.'):format(i) end
            local name = type(b.name) == 'string' and qbx.string.trim(b.name:gsub('[%c<>]', '')) or nil
            if name == '' then name = nil end
            if name and #name > 40 then return nil, ('Ponto %d: nome do blip muito longo.'):format(i) end
            local sprite = b.sprite == nil and 357 or b.sprite
            local color = b.color == nil and 3 or b.color
            if not validInteger(sprite, 1, 999) then return nil, ('Ponto %d: ícone do blip inválido.'):format(i) end
            if not validInteger(color, 0, 85) then return nil, ('Ponto %d: cor do blip inválida.'):format(i) end
            point.blip = { name = name, sprite = sprite, color = color }
        end

        if p.ped ~= nil then
            local ped = p.ped
            if type(ped) ~= 'table' or type(ped.model) ~= 'string' or not ped.model:match('^[%w_]+$') or #ped.model > 40 then
                return nil, ('Ponto %d: modelo do atendente inválido.'):format(i)
            end
            if ped.scenario ~= nil and not PED_SCENARIOS[ped.scenario] then
                return nil, ('Ponto %d: animação do atendente inválida.'):format(i)
            end
            if ped.rotation ~= nil and not (validInteger(ped.rotation, 0, 315) and ped.rotation % 45 == 0) then
                return nil, ('Ponto %d: giro do atendente inválido.'):format(i)
            end
            local position
            if ped.position ~= nil then
                position = validPosition(ped.position, true)
                if not position then return nil, ('Ponto %d: posição do atendente inválida.'):format(i) end
            end
            point.ped = {
                model = ped.model:lower(),
                scenario = ped.scenario,
                rotation = ped.rotation ~= 0 and ped.rotation or nil,
                position = position,
            }
        end
        if p.interaction ~= nil then
            if not INTERACTIONS[p.interaction] then return nil, ('Ponto %d: interação inválida.'):format(i) end
            -- 'key' e o padrao: so grava o target.
            point.interaction = p.interaction == 'target' and 'target' or nil
        end

        -- Raios que a tela nao edita (o hangar usa maiores) passam adiante se forem validos.
        for _, key in ipairs(POINT_NUMBERS) do
            if p[key] ~= nil then
                if not finite(p[key]) or p[key] < 0.5 or p[key] > 500 then
                    return nil, ('Ponto %d: raio inválido.'):format(i)
                end
                point[key] = p[key]
            end
        end
        points[i] = point
    end

    return {
        label = label,
        vehicleType = input.vehicleType,
        depot = input.depot == true,
        shared = input.shared == true,
        groups = groups,
        accessPoints = points,
    }
end

---Identificador a partir do nome: minusculo, sem acento, so letras e numeros, unico.
local function slugFor(label)
    local map = { ['á']='a', ['à']='a', ['â']='a', ['ã']='a', ['é']='e', ['ê']='e', ['í']='i', ['ó']='o', ['ô']='o', ['õ']='o', ['ú']='u', ['ç']='c' }
    local slug = label:lower():gsub('[\195][\128-\191]', function(c) return map[c] or '' end):gsub('[^%w]', '')
    if slug == '' then slug = 'garagem' end
    slug = slug:sub(1, 40)
    local candidate, n = slug, 1
    while Garages[candidate] do
        n = n + 1
        candidate = ('%s%d'):format(slug, n)
    end
    return candidate
end

-- ── Carga ─────────────────────────────────────────────────────────────────

function LoadGarageLocations()
    Storage.ensureLocationsSchema()
    local rows = Storage.getLocations()

    if #rows == 0 then
        for name, garage in pairs(Config.garages) do
            Storage.saveLocation(name, json.encode(serialize(garage)))
        end
        rows = Storage.getLocations()
        lib.print.info(('noir_garage: %d garagens do config copiadas para noir_garage_locations'):format(#rows))
    end

    local loaded = {}
    for i = 1, #rows do
        local ok, data = pcall(json.decode, rows[i].data)
        local valid = ok and validate(data)
        if valid then
            loaded[rows[i].name] = deserialize(valid)
        else
            lib.print.error(('noir_garage: garagem %s com dados inválidos no banco, ignorada'):format(rows[i].name))
        end
    end

    -- Troca so as garagens do config; as que outros resources registraram em tempo de execucao ficam.
    for name in pairs(Config.garages) do
        if not loaded[name] then Garages[name] = nil end
    end
    for name, garage in pairs(loaded) do
        Garages[name] = garage
    end
    GaragesReady = true
end

-- ── Editor ────────────────────────────────────────────────────────────────

local function editorList()
    local counts = Storage.countGaragedByGarage()
    local list = {}
    for name, garage in pairs(Garages) do
        local data = serialize(garage)
        data.name = name
        data.stored = counts[name] or 0
        list[#list + 1] = data
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

lib.addCommand('garagem', {
    help = 'Editor de garagens',
    restricted = 'group.admin',
}, function(source)
    if not isAdmin(source) then return end
    TriggerClientEvent('noir_garage:client:openEditor', source, editorList(), groupOptions())
end)

lib.callback.register('noir_garage:admin:list', function(source)
    if not isAdmin(source) then return end
    return editorList()
end)

---@param name? string garagem existente; nil cria uma nova
lib.callback.register('noir_garage:admin:save', function(source, name, input)
    if not isAdmin(source) then return { ok = false, error = 'Sem permissão.' } end
    if name ~= nil and (type(name) ~= 'string' or not Garages[name]) then
        return { ok = false, error = 'Garagem não encontrada.' }
    end

    local data, err = validate(input)
    if not data then return { ok = false, error = err } end
    -- So ao salvar pelo editor: no carregamento do banco, uma gang que deixou de existir nao pode
    -- sumir com a garagem inteira.
    err = checkGroupsExist(data.groups)
    if err then return { ok = false, error = err } end

    local created = name == nil
    name = name or slugFor(data.label)
    Storage.saveLocation(name, json.encode(data))

    local garage = deserialize(data)
    Garages[name] = garage
    TriggerClientEvent('noir_garage:client:garageRegistered', -1, name, garage)
    TriggerEvent('noir_garage:server:garageRegistered', name, garage)

    logger.log({
        source = source,
        event = 'garage_editor',
        message = ('%s a garagem %s (%s)'):format(created and 'Criou' or 'Editou', name, data.label),
        webhook = Config.logging.webhook.default,
    })
    return { ok = true, name = name, list = editorList() }
end)

lib.callback.register('noir_garage:admin:delete', function(source, name)
    if not isAdmin(source) then return { ok = false, error = 'Sem permissão.' } end
    if type(name) ~= 'string' or not Garages[name] then return { ok = false, error = 'Garagem não encontrada.' } end

    local stored = Storage.countGaragedByGarage()[name] or 0
    if stored > 0 then
        return { ok = false, error = ('Há %d veículo(s) guardado(s) nesta garagem. Transfira-os antes de apagar.'):format(stored) }
    end

    local label = Garages[name].label
    Storage.deleteLocation(name)
    Garages[name] = nil
    TriggerClientEvent('noir_garage:client:garageRemoved', -1, name)

    logger.log({
        source = source,
        event = 'garage_editor',
        message = ('Apagou a garagem %s (%s)'):format(name, label),
        webhook = Config.logging.webhook.default,
    })
    return { ok = true, list = editorList() }
end)
