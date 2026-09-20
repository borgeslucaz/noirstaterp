BGRZ = BGRZ or {}

local entityOwnership = {}
local zoneOwnership = {}
local modelOwnership = {}

-- Declarada aqui porque o cleanup e a re-hidratação, que vêm antes da API de
-- model neste arquivo, precisam chamá-la.
local removeOwnedModel

local function invokingResource()
    local caller = type(GetInvokingResource) == 'function' and GetInvokingResource() or nil
    if type(caller) ~= 'string' or caller == '' then return nil end
    return caller
end

local function finite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function resolveEntity(value)
    if type(value) ~= 'number' or value <= 0 or value % 1 ~= 0 then return nil end
    if type(NetworkDoesNetworkIdExist) == 'function' and NetworkDoesNetworkIdExist(value) then
        return 'network', value
    end
    if type(DoesEntityExist) == 'function' and DoesEntityExist(value) then
        return 'local', value
    end
    return nil
end

local function normalizeOptions(options, caller)
    if type(options) ~= 'table' then return nil end
    if options.name ~= nil then options = { options } end
    if #options == 0 then return nil end

    local normalized, names = {}, {}
    local seen = {}
    for index = 1, #options do
        local option = options[index]
        if type(option) ~= 'table' or type(option.name) ~= 'string'
            or option.name == '' or #option.name > 64 or seen[option.name] then
            return nil
        end
        seen[option.name] = true
        local copy = {}
        for key, value in pairs(option) do copy[key] = value end
        copy.name = ('%s:%s'):format(caller, option.name)
        normalized[index] = copy
        names[option.name] = copy
    end
    return normalized, names
end

local function providerMethod(kind, operation)
    if kind == 'network' then
        return operation == 'add' and 'addEntity' or 'removeEntity'
    end
    return operation == 'add' and 'addLocalEntity' or 'removeLocalEntity'
end

local function entityKey(kind, entity)
    return ('%s:%d'):format(kind, entity)
end

---Normaliza models para uma lista de hashes uint32, sem repetição.
---
---Tudo vira hash, inclusive o que chegou como nome: é o que o próprio ox_target
---guarda internamente, e passar sempre a mesma forma é o que garante que o
---`removeModel` encontre o que o `addModel` registrou. Nome e hash do MESMO model
---também deixam de ser duas entradas na nossa contabilidade de posse.
---@param models any string|number|(string|number)[]
---@return number[]? hashes
local function normalizeModels(models)
    if type(models) == 'string' or type(models) == 'number' then models = { models } end
    if type(models) ~= 'table' or #models == 0 or #models > 128 then return nil end

    local hashes, seen = {}, {}
    for index = 1, #models do
        local model = models[index]
        local hash
        if type(model) == 'string' and model ~= '' and #model <= 64 then
            hash = joaat(model)
        elseif type(model) == 'number' and model == model and model % 1 == 0 then
            hash = model
        end
        if not hash then return nil end
        -- joaat devolve uint32; um hash que chegou como inteiro com sinal aponta
        -- para o mesmo model e não pode virar uma segunda chave de posse.
        hash = hash % 0x100000000
        if not seen[hash] then
            seen[hash] = true
            hashes[#hashes + 1] = hash
        end
    end
    return hashes
end

local function callProvider(provider, method, ...)
    local args = { ... }
    local called, result = pcall(function()
        return exports[provider][method](exports[provider], table.unpack(args))
    end)
    if not called then return false, 'provider_unavailable' end
    if result == false then return false, 'operation_failed' end
    return true, result
end

---@param entityOrNetId number
---@param options table
---@return boolean ok
---@return string? errorCode
function BGRZ.AddEntityTarget(entityOrNetId, options)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    local kind, entity = resolveEntity(entityOrNetId)
    if not kind then return false, 'invalid_entity' end
    local normalized, names = normalizeOptions(options, caller)
    if not normalized then return false, 'invalid_options' end

    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then return false, 'provider_unavailable' end
    local ok, err = callProvider(provider, providerMethod(kind, 'add'), entity, normalized)
    if not ok then return false, err end

    entityOwnership[caller] = entityOwnership[caller] or {}
    local key = entityKey(kind, entity)
    local entry = entityOwnership[caller][key]
    if not entry then
        entry = { kind = kind, entity = entity, options = {} }
        entityOwnership[caller][key] = entry
    end
    for name, option in pairs(names) do entry.options[name] = option end
    return true
end

local function requestedNames(optionNames, entry)
    if optionNames == nil then
        local all = {}
        for name in pairs(entry.options) do all[#all + 1] = name end
        table.sort(all)
        return all
    end
    if type(optionNames) == 'string' then optionNames = { optionNames } end
    if type(optionNames) ~= 'table' or #optionNames == 0 then return nil, 'invalid_options' end
    local result, seen = {}, {}
    for index = 1, #optionNames do
        local name = optionNames[index]
        if type(name) ~= 'string' or name == '' or seen[name] then
            return nil, 'invalid_options'
        end
        if not entry.options[name] then return nil, 'not_owner' end
        seen[name] = true
        result[index] = name
    end
    return result
end

local function removeOwnedEntity(caller, kind, entity, optionNames, cleanup)
    local byCaller = entityOwnership[caller]
    local key = entityKey(kind, entity)
    local entry = byCaller and byCaller[key]
    if not entry then return false, 'not_owner' end
    local names, namesError = requestedNames(optionNames, entry)
    if not names then return false, namesError end

    local providerNames = {}
    for index = 1, #names do providerNames[index] = entry.options[names[index]].name end
    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then
        if cleanup then entityOwnership[caller][key] = nil end
        return false, 'provider_unavailable'
    end
    local ok, err = callProvider(provider, providerMethod(kind, 'remove'), entity, providerNames)
    if not ok and not cleanup then return false, err end

    for index = 1, #names do entry.options[names[index]] = nil end
    if next(entry.options) == nil then byCaller[key] = nil end
    if next(byCaller) == nil then entityOwnership[caller] = nil end
    return ok, err
end

---@param entityOrNetId number
---@param optionNames? string|string[]
---@return boolean ok
---@return string? errorCode
function BGRZ.RemoveEntityTarget(entityOrNetId, optionNames)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    local kind, entity = resolveEntity(entityOrNetId)
    if not kind then
        local byCaller = entityOwnership[caller]
        local networkKey = entityKey('network', entityOrNetId)
        local localKey = entityKey('local', entityOrNetId)
        if byCaller and byCaller[networkKey] then
            kind, entity = 'network', entityOrNetId
        elseif byCaller and byCaller[localKey] then
            kind, entity = 'local', entityOrNetId
        else
            return false, 'invalid_entity'
        end
    end
    return removeOwnedEntity(caller, kind, entity, optionNames, false)
end

---Validação comum a toda zona: nome, coords, flags de debug e options.
local function normalizeZone(definition, caller)
    if type(definition) ~= 'table' or type(definition.name) ~= 'string'
        or definition.name == '' or #definition.name > 64
        or not definition.name:match('^[%w_:%-%.]+$') then
        return nil, 'invalid_zone'
    end
    local coords = definition.coords
    if (type(coords) ~= 'table' and type(coords) ~= 'vector3')
        or not finite(coords.x) or not finite(coords.y) or not finite(coords.z) then
        return nil, 'invalid_coords'
    end
    if definition.debug ~= nil and type(definition.debug) ~= 'boolean' then
        return nil, 'invalid_zone'
    end
    if definition.drawSprite ~= nil and type(definition.drawSprite) ~= 'boolean' then
        return nil, 'invalid_zone'
    end
    local options = normalizeOptions(definition.options, caller)
    if not options then return nil, 'invalid_options' end

    local normalized = {}
    for key, value in pairs(definition) do normalized[key] = value end
    normalized.name = ('%s:%s'):format(caller, definition.name)
    normalized.options = options
    normalized.resource = nil
    return normalized
end

local function normalizeSphereZone(definition, caller)
    local normalized, err = normalizeZone(definition, caller)
    if not normalized then return nil, err end
    if not finite(definition.radius) or definition.radius < 0.1 or definition.radius > 50.0 then
        return nil, 'invalid_radius'
    end
    return normalized
end

local function normalizeBoxZone(definition, caller)
    local normalized, err = normalizeZone(definition, caller)
    if not normalized then return nil, err end

    local size = definition.size
    if (type(size) ~= 'table' and type(size) ~= 'vector3')
        or not finite(size.x) or not finite(size.y) or not finite(size.z)
        or size.x <= 0 or size.y <= 0 or size.z <= 0
        or size.x > 100.0 or size.y > 100.0 or size.z > 100.0 then
        return nil, 'invalid_size'
    end
    if definition.rotation ~= nil and not finite(definition.rotation) then
        return nil, 'invalid_rotation'
    end
    return normalized
end

---Registra a zona no provider e passa a responder por ela. `method` fica guardado
---porque a re-hidratação precisa saber se recria a zona como esfera ou caixa.
local function addOwnedZone(caller, definition, normalized, method)
    zoneOwnership[caller] = zoneOwnership[caller] or {}
    if zoneOwnership[caller][definition.name] then return false, 'already_exists' end

    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then return false, 'provider_unavailable' end
    local ok, providerId = callProvider(provider, method, normalized)
    if not ok then return false, providerId end

    zoneOwnership[caller][definition.name] = {
        name = definition.name,
        definition = normalized,
        method = method,
        providerId = providerId or normalized.name,
    }
    return true
end

---@param definition table
---@return boolean ok
---@return string? errorCode
function BGRZ.AddSphereZoneTarget(definition)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    local normalized, normalizeError = normalizeSphereZone(definition, caller)
    if not normalized then return false, normalizeError end
    return addOwnedZone(caller, definition, normalized, 'addSphereZone')
end

---@param definition table { name, coords, size, rotation?, options, debug?, drawSprite? }
---@return boolean ok
---@return string? errorCode
function BGRZ.AddBoxZoneTarget(definition)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    local normalized, normalizeError = normalizeBoxZone(definition, caller)
    if not normalized then return false, normalizeError end
    return addOwnedZone(caller, definition, normalized, 'addBoxZone')
end

local function removeOwnedZone(caller, name, cleanup)
    local byCaller = zoneOwnership[caller]
    local entry = byCaller and byCaller[name]
    if not entry then return false, 'not_owner' end
    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then
        if cleanup then byCaller[name] = nil end
        return false, 'provider_unavailable'
    end
    local ok, err = callProvider(provider, 'removeZone', entry.providerId, true)
    if not ok and not cleanup then return false, err end
    byCaller[name] = nil
    if next(byCaller) == nil then zoneOwnership[caller] = nil end
    return ok, err
end

---@param name string
---@return boolean ok
---@return string? errorCode
function BGRZ.RemoveZoneTarget(name)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    if type(name) ~= 'string' or name == '' then return false, 'invalid_zone' end
    return removeOwnedZone(caller, name, false)
end

local function cleanupCaller(caller)
    local entities = entityOwnership[caller]
    if entities then
        local entries = {}
        for _, entry in pairs(entities) do entries[#entries + 1] = entry end
        for index = 1, #entries do
            local entry = entries[index]
            removeOwnedEntity(caller, entry.kind, entry.entity, nil, true)
        end
        entityOwnership[caller] = nil
    end

    local zones = zoneOwnership[caller]
    if zones then
        local names = {}
        for name in pairs(zones) do names[#names + 1] = name end
        table.sort(names)
        for index = 1, #names do removeOwnedZone(caller, names[index], true) end
        zoneOwnership[caller] = nil
    end

    local models = modelOwnership[caller]
    if models then
        local hashes = {}
        for hash in pairs(models) do hashes[#hashes + 1] = hash end
        table.sort(hashes)
        for index = 1, #hashes do removeOwnedModel(caller, hashes[index], nil, true) end
        modelOwnership[caller] = nil
    end
end

local function rehydrateProvider(resource)
    local provider = BGRZ.Provider.name('target')
    if resource ~= provider or not BGRZ.Provider.isAvailable('target') then return end

    for _, entities in pairs(entityOwnership) do
        for _, entry in pairs(entities) do
            local options = {}
            for _, option in pairs(entry.options) do options[#options + 1] = option end
            table.sort(options, function(a, b) return a.name < b.name end)
            callProvider(provider, providerMethod(entry.kind, 'add'), entry.entity, options)
        end
    end
    for _, zones in pairs(zoneOwnership) do
        for _, entry in pairs(zones) do
            local ok, providerId = callProvider(provider, entry.method or 'addSphereZone', entry.definition)
            if ok then entry.providerId = providerId or entry.definition.name end
        end
    end
    for _, models in pairs(modelOwnership) do
        for _, entry in pairs(models) do
            local options = {}
            for _, option in pairs(entry.options) do options[#options + 1] = option end
            table.sort(options, function(a, b) return a.name < b.name end)
            callProvider(provider, 'addModel', entry.model, options)
        end
    end
end

---Target em uma entidade explicitamente LOCAL (prop que o próprio client criou).
---
---Existe separado de `AddEntityTarget` por um motivo concreto: aquela resolve o
---handle testando `NetworkDoesNetworkIdExist` primeiro, e o handle de um objeto
---local pode coincidir com um netId válido de OUTRA entidade — o target iria parar
---no lugar errado. Quando quem chama sabe que a entidade é local, dizer isso ao
---provider elimina o palpite.
---@param entity number handle local
---@param options table
---@return boolean ok
---@return string? errorCode
function BGRZ.AddLocalEntityTarget(entity, options)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    if type(entity) ~= 'number' or entity <= 0 or entity % 1 ~= 0
        or not DoesEntityExist(entity) then
        return false, 'invalid_entity'
    end
    local normalized, names = normalizeOptions(options, caller)
    if not normalized then return false, 'invalid_options' end

    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then return false, 'provider_unavailable' end
    local ok, err = callProvider(provider, 'addLocalEntity', entity, normalized)
    if not ok then return false, err end

    entityOwnership[caller] = entityOwnership[caller] or {}
    local key = entityKey('local', entity)
    local entry = entityOwnership[caller][key]
    if not entry then
        entry = { kind = 'local', entity = entity, options = {} }
        entityOwnership[caller][key] = entry
    end
    for name, option in pairs(names) do entry.options[name] = option end
    return true
end

---@param entity number handle local
---@param optionNames? string|string[]
---@return boolean ok
---@return string? errorCode
function BGRZ.RemoveLocalEntityTarget(entity, optionNames)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    if type(entity) ~= 'number' or entity <= 0 or entity % 1 ~= 0 then
        return false, 'invalid_entity'
    end
    -- Sem checar DoesEntityExist: o caso normal é remover o target de um prop que
    -- acabou de ser deletado, e recusar aí deixaria a posse pendurada para sempre.
    return removeOwnedEntity(caller, 'local', entity, optionNames, true)
end

---Target em todo objeto de um MODEL, incluindo os que vêm do mapa.
---
---Existe porque prop de mapa — parquímetro, lixeira, caixa de correio — não é uma
---entidade que alguém criou: ela não tem netId, não existe no servidor e o handle
---local muda conforme o streaming carrega e descarrega a região. Não há o que
---passar para `AddEntityTarget` nem para `AddLocalEntityTarget`, e varrer o pool de
---objetos num loop para registrar um a um seria caro e ainda perderia os que
---entram depois. O provider já resolve isso por model; o que faltava era a porta.
---@param models string|number|(string|number)[]
---@param options table
---@return boolean ok
---@return string? errorCode
function BGRZ.AddModelTarget(models, options)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    local hashes = normalizeModels(models)
    if not hashes then return false, 'invalid_model' end
    local normalized, names = normalizeOptions(options, caller)
    if not normalized then return false, 'invalid_options' end

    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then return false, 'provider_unavailable' end
    local ok, err = callProvider(provider, 'addModel', hashes, normalized)
    if not ok then return false, err end

    modelOwnership[caller] = modelOwnership[caller] or {}
    for index = 1, #hashes do
        local hash = hashes[index]
        local entry = modelOwnership[caller][hash]
        if not entry then
            entry = { model = hash, options = {} }
            modelOwnership[caller][hash] = entry
        end
        for name, option in pairs(names) do entry.options[name] = option end
    end
    return true
end

function removeOwnedModel(caller, hash, optionNames, cleanup)
    local byCaller = modelOwnership[caller]
    local entry = byCaller and byCaller[hash]
    if not entry then return false, 'not_owner' end
    local names, namesError = requestedNames(optionNames, entry)
    if not names then return false, namesError end

    local providerNames = {}
    for index = 1, #names do providerNames[index] = entry.options[names[index]].name end
    local provider = BGRZ.Provider.name('target')
    if not BGRZ.Provider.isAvailable('target') then
        if cleanup then byCaller[hash] = nil end
        return false, 'provider_unavailable'
    end
    local ok, err = callProvider(provider, 'removeModel', hash, providerNames)
    if not ok and not cleanup then return false, err end

    for index = 1, #names do entry.options[names[index]] = nil end
    if next(entry.options) == nil then byCaller[hash] = nil end
    if next(byCaller) == nil then modelOwnership[caller] = nil end
    return ok, err
end

---@param models string|number|(string|number)[]
---@param optionNames? string|string[]
---@return boolean ok
---@return string? errorCode
function BGRZ.RemoveModelTarget(models, optionNames)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    local hashes = normalizeModels(models)
    if not hashes then return false, 'invalid_model' end

    -- Um model da lista pode já ter sido removido antes; isso não pode impedir a
    -- remoção dos outros. O primeiro erro é o que volta, e o laço segue.
    local ok, err = true, nil
    for index = 1, #hashes do
        local removed, removeError = removeOwnedModel(caller, hashes[index], optionNames, false)
        if not removed then
            ok = false
            err = err or removeError
        end
    end
    return ok, err
end

exports('AddModelTarget', BGRZ.AddModelTarget)
exports('RemoveModelTarget', BGRZ.RemoveModelTarget)
exports('AddLocalEntityTarget', BGRZ.AddLocalEntityTarget)
exports('RemoveLocalEntityTarget', BGRZ.RemoveLocalEntityTarget)
exports('AddEntityTarget', BGRZ.AddEntityTarget)
exports('RemoveEntityTarget', BGRZ.RemoveEntityTarget)
exports('AddSphereZoneTarget', BGRZ.AddSphereZoneTarget)
exports('AddBoxZoneTarget', BGRZ.AddBoxZoneTarget)
exports('RemoveZoneTarget', BGRZ.RemoveZoneTarget)

AddEventHandler('onClientResourceStart', rehydrateProvider)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        local callers = {}
        for caller in pairs(entityOwnership) do callers[caller] = true end
        for caller in pairs(zoneOwnership) do callers[caller] = true end
        for caller in pairs(modelOwnership) do callers[caller] = true end
        for caller in pairs(callers) do cleanupCaller(caller) end
        entityOwnership = {}
        zoneOwnership = {}
        modelOwnership = {}
        return
    end
    cleanupCaller(resource)
end)
