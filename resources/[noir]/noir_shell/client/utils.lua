local idCounter = 0

local function debugPrint(...)
    if not Config.Debug then return end

    print('[noir_shell]', ...)
end

local function generateId()
    idCounter += 1

    return ('shell_%s_%d_%d'):format(GetCurrentResourceName(), GetGameTimer(), idCounter)
end

local function toModelHash(model)
    if type(model) == 'number' then
        return model
    end

    if type(model) == 'string' then
        return joaat(model)
    end

    return nil
end

local function isValidModel(hash)
    return hash ~= nil and IsModelInCdimage(hash) and IsModelValid(hash)
end

-- Returns hash, nil on success or nil, errorReason on failure.
local function loadModel(model, timeout)
    timeout = timeout or Config.ModelLoadTimeout

    local hash = toModelHash(model)

    if not isValidModel(hash) then
        return nil, 'invalid_model'
    end

    RequestModel(hash)

    local start = GetGameTimer()

    while not HasModelLoaded(hash) do
        if GetGameTimer() - start > timeout then
            SetModelAsNoLongerNeeded(hash)
            return nil, 'model_load_timeout'
        end

        Wait(0)
    end

    return hash
end

local function isValidOrigin(origin)
    return type(origin) == 'vector4'
        or (type(origin) == 'table' and origin.x and origin.y and origin.z)
end

Utils = {
    debugPrint = debugPrint,
    generateId = generateId,
    toModelHash = toModelHash,
    isValidModel = isValidModel,
    loadModel = loadModel,
    isValidOrigin = isValidOrigin,
}
