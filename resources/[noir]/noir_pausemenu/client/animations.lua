PauseAnim = {}
PauseAnim.playing = false
PauseAnim.currentDict = nil
PauseAnim.currentAnim = nil
PauseAnim.currentProp = nil
PauseAnim.lastKeys = {}

local FEMALE_MODEL = joaat('mp_f_freemode_01')
local MALE_MODEL = joaat('mp_m_freemode_01')

local function getGenderKey(ped)
    if Framework and Framework.name == 'qbx' then
        local ok, data = pcall(function()
            return exports.qbx_core:GetPlayerData()
        end)
        if ok and data and data.charinfo and data.charinfo.gender ~= nil then
            return data.charinfo.gender == 1 and 'female' or 'male'
        end
    end

    if Framework and Framework.name == 'qbcore' and Framework.object then
        local data = Framework.object.Functions.GetPlayerData()
        if data and data.charinfo and data.charinfo.gender ~= nil then
            return data.charinfo.gender == 1 and 'female' or 'male'
        end
    end

    local model = GetEntityModel(ped)
    if model == FEMALE_MODEL then
        return 'female'
    end
    if model == MALE_MODEL then
        return 'male'
    end

    if IsPedMale(ped) then
        return 'male'
    end

    return 'female'
end

local function loadAnimDict(dict)
    if not dict then return false end

    if lib and lib.requestAnimDict then
        local ok, result = pcall(function()
            return lib.requestAnimDict(dict, 5000)
        end)
        if ok and result then
            return HasAnimDictLoaded(dict)
        end
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            return false
        end
        Wait(10)
    end

    return true
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then
        return false
    end

    if lib and lib.requestModel then
        local ok, result = pcall(function()
            return lib.requestModel(hash, 5000)
        end)
        if ok and result then
            return HasModelLoaded(hash)
        end
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            return false
        end
        Wait(10)
    end

    return true
end

local function resolvePropConfig(entry)
    if not entry or not entry.prop then
        return nil
    end

    if type(entry.prop) == 'string' then
        return Config.AnimationPropPresets and Config.AnimationPropPresets[entry.prop]
    end

    return entry.prop
end

local function removeProp()
    if PauseAnim.currentProp and DoesEntityExist(PauseAnim.currentProp) then
        DeleteEntity(PauseAnim.currentProp)
    end

    PauseAnim.currentProp = nil
end

local function attachProp(ped, propConfig)
    removeProp()

    if not propConfig or not propConfig.model then
        return
    end

    if not loadModel(propConfig.model) then
        return
    end

    local pedCoords = GetEntityCoords(ped)
    local hash = joaat(propConfig.model)
    local prop = CreateObject(hash, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false)

    if not prop or prop == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityCollision(prop, false, false)
    SetEntityCompletelyDisableCollision(prop, true, true)

    local bone = propConfig.bone or 28422
    local pos = propConfig.pos or { x = 0.0, y = 0.0, z = 0.0 }
    local rot = propConfig.rot or { x = 0.0, y = 0.0, z = 0.0 }

    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, bone),
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    SetEntityAsMissionEntity(prop, true, true)

    SetModelAsNoLongerNeeded(hash)
    PauseAnim.currentProp = prop
end

local function animationExists(dict, anim)
    if not dict or not anim then return false end
    if not DoesAnimDictExist(dict) then return false end
    if not loadAnimDict(dict) then return false end

    return GetAnimDuration(dict, anim) > 0.0
end

local function isAnimationRunning(ped, dict, anim)
    return dict and anim and IsEntityPlayingAnim(ped, dict, anim, 3)
end

local function waitForAnimation(ped, dict, anim)
    local timeout = GetGameTimer() + 2000
    while GetGameTimer() < timeout do
        if isAnimationRunning(ped, dict, anim) then
            return true
        end
        Wait(0)
    end

    return isAnimationRunning(ped, dict, anim)
end

local function shuffleIndices(count)
    local indices = {}
    for i = 1, count do
        indices[i] = i
    end

    for i = count, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    return indices
end

local function getAnimationKey(entry)
    return entry.dict .. '|' .. entry.anim
end

local function buildAttemptOrder(pool, gender)
    local order = {}
    local lastKey = PauseAnim.lastKeys[gender]

    for i = 1, #pool do
        if getAnimationKey(pool[i]) ~= lastKey then
            order[#order + 1] = i
        end
    end

    if #order == 0 then
        return shuffleIndices(#pool)
    end

    for i = #order, 2, -1 do
        local j = math.random(1, i)
        order[i], order[j] = order[j], order[i]
    end

    return order
end

local function tryPlayAnimation(ped, entry)
    if not entry or not entry.dict or not entry.anim then
        return false
    end

    if not animationExists(entry.dict, entry.anim) then
        return false
    end

    ClearPedTasks(ped)
    removeProp()

    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanPlayAmbientBaseAnims(ped, true)

    TaskPlayAnim(ped, entry.dict, entry.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)

    if not waitForAnimation(ped, entry.dict, entry.anim) then
        RemoveAnimDict(entry.dict)
        return false
    end

    local propConfig = resolvePropConfig(entry)
    if propConfig then
        Wait(propConfig.delay or 500)
        attachProp(ped, propConfig)
    end

    return true
end

local function getAnimationPool(ped)
    local gender = getGenderKey(ped)

    if Config.AnimationMode == 'single' then
        local single = Config.SingleAnimation[gender]
        if single then
            return { single }
        end
    end

    return Config.Animations[gender] or {}
end

function PauseAnim.Start()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    if IsPedDeadOrDying(ped, true) then return end

    if PauseAnim.playing then
        if isAnimationRunning(ped, PauseAnim.currentDict, PauseAnim.currentAnim) then
            return
        end

        PauseAnim.playing = false
        removeProp()
        PauseAnim.currentDict = nil
        PauseAnim.currentAnim = nil
    end

    local pool = getAnimationPool(ped)
    if #pool == 0 then return end

    local gender = getGenderKey(ped)
    local order = buildAttemptOrder(pool, gender)

    for i = 1, #order do
        local entry = pool[order[i]]
        if entry and tryPlayAnimation(ped, entry) then
            PauseAnim.playing = true
            PauseAnim.currentDict = entry.dict
            PauseAnim.currentAnim = entry.anim
            PauseAnim.lastKeys[gender] = getAnimationKey(entry)
            return
        end
    end
end

function PauseAnim.Stop()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    removeProp()

    if PauseAnim.currentDict then
        RemoveAnimDict(PauseAnim.currentDict)
        PauseAnim.currentDict = nil
    end

    PauseAnim.currentAnim = nil
    PauseAnim.playing = false
end
