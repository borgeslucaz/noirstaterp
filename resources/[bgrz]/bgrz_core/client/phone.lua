BGRZ = BGRZ or {}

local registrations = {}


local function invokingResource()
    local caller = type(GetInvokingResource) == 'function' and GetInvokingResource() or nil
    if type(caller) ~= 'string' or caller == '' then return nil end
    return caller
end

local function copyTable(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, item in pairs(value) do
        if type(item) == 'table' then
            local nested = {}
            for nestedKey, nestedValue in pairs(item) do nested[nestedKey] = nestedValue end
            copy[key] = nested
        else
            copy[key] = item
        end
    end
    return copy
end

local function validDefinition(definition)
    if type(definition) ~= 'table' then return false end
    local identifier = definition.identifier
    if type(identifier) ~= 'string' or #identifier == 0 or #identifier > 64
        or not identifier:match('^[%w_-]+$') then
        return false
    end
    if type(definition.name) ~= 'string' or #definition.name == 0
        or #definition.name > 96 then
        return false
    end
    if definition.ui ~= nil and (type(definition.ui) ~= 'string'
        or #definition.ui == 0 or #definition.ui > 2048) then
        return false
    end
    if definition.icon ~= nil and (type(definition.icon) ~= 'string'
        or #definition.icon == 0 or #definition.icon > 2048) then
        return false
    end
    if definition.requires ~= nil and type(definition.requires) ~= 'table' then
        return false
    end
    return true
end

local function addToProvider(definition)
    local provider = BGRZ.Provider.name('phone')
    if not BGRZ.Provider.isAvailable('phone') then return false, 'provider_unavailable' end
    local called, ok, providerError = pcall(function()
        return exports[provider]:addCustomApp(copyTable(definition))
    end)
    if not called then return false, 'provider_unavailable' end
    if ok ~= true then
        if type(providerError) == 'string'
            and (providerError:find('registered', 1, true)
                or providerError:find('reserved', 1, true)) then
            return false, 'identifier_collision'
        end
        return false, 'registration_failed'
    end
    return true
end

---@param definition table
---@return boolean ok
---@return string? errorCode
function BGRZ.RegisterPhoneApp(definition)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    if not validDefinition(definition) then return false, 'invalid_definition' end

    local identifier = definition.identifier
    local existing = registrations[identifier]
    if existing and existing.owner ~= caller then
        return false, 'identifier_collision'
    end

    local normalized = copyTable(definition)
    local ok, err = addToProvider(normalized)
    if not ok then return false, err end
    registrations[identifier] = { owner = caller, definition = normalized }
    return true
end

local function removeRegistration(identifier)
    local registration = registrations[identifier]
    if not registration then return end
    local provider = BGRZ.Provider.name('phone')
    if BGRZ.Provider.isAvailable('phone') then
        pcall(function() exports[provider]:removeCustomApp(identifier) end)
    end
    registrations[identifier] = nil
end

local function cleanupCaller(caller)
    local identifiers = {}
    for identifier, registration in pairs(registrations) do
        if registration.owner == caller then identifiers[#identifiers + 1] = identifier end
    end
    table.sort(identifiers)
    for index = 1, #identifiers do removeRegistration(identifiers[index]) end
end

local function rehydrateProvider(resource)
    local provider = BGRZ.Provider.name('phone')
    if resource ~= provider or not BGRZ.Provider.isAvailable('phone') then return end
    local identifiers = {}
    for identifier in pairs(registrations) do identifiers[#identifiers + 1] = identifier end
    table.sort(identifiers)
    for index = 1, #identifiers do
        local registration = registrations[identifiers[index]]
        addToProvider(registration.definition)
    end
end

---@param identifier string
---@param message table
---@return boolean ok
---@return string? errorCode
function BGRZ.SendPhoneAppMessage(identifier, message)
    local caller = invokingResource()
    if not caller then return false, 'invalid_caller' end
    if type(identifier) ~= 'string' or #identifier == 0 or #identifier > 64
        or not identifier:match('^[%w_-]+$') then
        return false, 'invalid_identifier'
    end
    if type(message) ~= 'table' then return false, 'invalid_message' end
    local registration = registrations[identifier]
    if not registration then return false, 'not_registered' end
    if registration.owner ~= caller then return false, 'not_owner' end

    local provider = BGRZ.Provider.name('phone')
    if not BGRZ.Provider.isAvailable('phone') then return false, 'provider_unavailable' end
    local called, ok = pcall(function()
        return exports[provider]:sendCustomAppMessage(identifier, message)
    end)
    if not called then return false, 'provider_unavailable' end
    if ok ~= true then return false, 'operation_failed' end
    return true
end

exports('RegisterPhoneApp', BGRZ.RegisterPhoneApp)
exports('SendPhoneAppMessage', BGRZ.SendPhoneAppMessage)

AddEventHandler('onClientResourceStart', rehydrateProvider)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        registrations = {}
        return
    end
    cleanupCaller(resource)
end)
