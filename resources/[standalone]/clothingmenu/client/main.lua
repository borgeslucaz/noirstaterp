local isOpen = false
local clothingState = {}
local savedOutfits = {}
local cam = nil
local targetPlayer = nil
local isTargetMenu = false
local positionLoopActive = false
local cursorEnabled = false

local function Notify(message, notifyType)
    lib.notify({
        type = notifyType or 'info',
        description = message
    })
end

local function SetCursorEnabled(enabled, shouldNotify)
    cursorEnabled = enabled == true

    if isOpen then
        SetNuiFocus(cursorEnabled, cursorEnabled)
        SetNuiFocusKeepInput(not cursorEnabled)

        if shouldNotify and (not Config.Cursor or Config.Cursor.notify ~= false) then
            Notify(cursorEnabled and 'Cursor do menu de roupas ativado.' or 'Cursor do menu de roupas desativado. Você pode se mover livremente.', 'info')
        end
    end
end

local function GetGenderKey(ped)
    return GetEntityModel(ped) == joaat('mp_m_freemode_01') and 'male' or 'female'
end

local function GetOffVariation(item, ped)
    local gender = GetGenderKey(ped)
    return item.off_drawable[gender], item.off_texture[gender]
end

local function IsWearingItem(ped, item, drawable)
    local offDrawable = GetOffVariation(item, ped)

    if drawable == nil then
        drawable = item.type == 'prop' and GetPedPropIndex(ped, item.component) or GetPedDrawableVariation(ped, item.component)
    end

    if item.type == 'prop' then
        if drawable == -1 or drawable == offDrawable then
            return false
        end
    elseif drawable == offDrawable then
        return false
    end

    local emptyByType = Config.EmptyDrawables and Config.EmptyDrawables[item.type]
    local emptyByLabel = emptyByType and emptyByType[item.label]
    if emptyByLabel and emptyByLabel[drawable] then
        return false
    end

    return true
end

local function FindClothingIndex(clothingType, component)
    for i, clothing in ipairs(Config.Clothing) do
        if clothing.type == clothingType and clothing.component == component then
            return i
        end
    end
end

local function FindItemConfigByName(itemName)
    for _, clothing in ipairs(Config.Clothing) do
        if clothing.itemName == itemName then
            return clothing
        end
    end
    return nil
end

local function GetPlayerServerIdFromPed(ped)
    local playerId = NetworkGetPlayerIndexFromPed(ped)
    if playerId == -1 then return nil end
    return GetPlayerServerId(playerId)
end

local function SaveAppearance(ped)
    ped = ped or PlayerPedId()
    if Config.Sync and Config.Sync.saveAppearance then
        local appearance = Config.Sync.getAppearance(ped)
        if appearance then
            Config.Sync.saveAppearance(appearance)
        end
    end
end

local function IsPlayerDead(ped)
    if ped == PlayerPedId() then
        local src = GetPlayerServerId(PlayerId())
        return Bridge.IsPlayerDead(src)
    end
    return IsEntityDead(ped) or GetEntityHealth(ped) <= 100
end

local function IsPlayerHandcuffed(ped)
    if ped == PlayerPedId() then
        local src = GetPlayerServerId(PlayerId())
        return Bridge.IsPlayerHandcuffed(src)
    end
    return IsPedCuffed(ped)
end

local function CanTargetPlayer(ped)
    if not Config.EnableTargetPlayer then return false end
    if not DoesEntityExist(ped) or not IsEntityAPed(ped) then return false end
    if ped == PlayerPedId() then return false end

    if Config.TestingMode then return true end
    if not IsPedAPlayer(ped) and not IsPlayerDead(ped) then return false end

    return (Config.AllowDead and IsPlayerDead(ped)) or (Config.AllowHandcuffed and IsPlayerHandcuffed(ped))
end

local function RefreshClothingState(ped)
    ped = ped or PlayerPedId()

    for i, item in ipairs(Config.Clothing) do
        clothingState[i] = IsWearingItem(ped, item)
    end
end

local function GetActivePed()
    if isTargetMenu then return targetPlayer end
    return PlayerPedId()
end

local function IsTargetStillValid()
    if not isTargetMenu then return true end
    local selfPed = PlayerPedId()
    local targetPed = targetPlayer

    if not DoesEntityExist(targetPed) then
        return false, 'O jogador selecionado não está mais disponível.'
    end

    local distance = #(GetEntityCoords(selfPed) - GetEntityCoords(targetPed))
    if distance > (Config.MaxTargetDistance or 5.0) then
        return false, 'O jogador selecionado se afastou demais.'
    end

    if not CanTargetPlayer(targetPed) then
        return false, 'Não é possível selecionar este jogador.'
    end

    return true
end

local function SetupCamera(ped)
    if cam then return end

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local coords = GetEntityCoords(ped)
    local camPos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(cam, coords.x, coords.y, coords.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
    FreezeEntityPosition(ped, true)
end

local function CleanupCamera()
    if cam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end

    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
    end

    ClearFocus()
end

local function BuildPositionUpdates(ped, lastUpdates)
    local updates = {}
    local hasChanged = false

    for i, item in ipairs(Config.Clothing) do
        local nextPosition = { x = item.x or 50, y = item.y or 50, visible = true }

        if item.bone and DoesEntityExist(ped) then
            local boneCoords = GetPedBoneCoords(ped, item.bone.id, item.bone.offset.x, item.bone.offset.y, item.bone.offset.z)
            local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(boneCoords.x, boneCoords.y, boneCoords.z)

            if onScreen then
                nextPosition.x = screenX * 100
                nextPosition.y = screenY * 100
            else
                nextPosition.visible = false
            end
        end

        updates[i] = nextPosition
        local previous = lastUpdates[i]
        if not previous
            or previous.visible ~= nextPosition.visible
            or math.abs(previous.x - nextPosition.x) > ((Config.Performance and Config.Performance.positionThreshold) or 0.03)
            or math.abs(previous.y - nextPosition.y) > ((Config.Performance and Config.Performance.positionThreshold) or 0.03) then
            hasChanged = true
            lastUpdates[i] = nextPosition
        end
    end

    return hasChanged, updates
end

local function StartPositionLoop()
    if positionLoopActive then return end
    positionLoopActive = true

    CreateThread(function()
        local lastUpdates = {}

        while isOpen do
            local ped = GetActivePed()
            local valid, reason = IsTargetStillValid()

            if not valid then
                Notify(reason, 'error')
                CloseMenu()
                break
            end

            if DoesEntityExist(ped) then
                local hasChanged, updates = BuildPositionUpdates(ped, lastUpdates)
                if hasChanged then
                    SendNUIMessage({ type = 'updatePositions', items = updates })
                end
            end

            Wait((Config.Performance and Config.Performance.positionWait) or 0)
        end

        positionLoopActive = false
    end)
end

function OpenMenu(targetPed)
    if isOpen then return end

    isTargetMenu = targetPed ~= nil
    targetPlayer = targetPed

    local ped = GetActivePed()
    if not DoesEntityExist(ped) then
        isTargetMenu = false
        targetPlayer = nil
        return
    end

    RefreshClothingState(ped)

    if isTargetMenu then
        local valid, reason = IsTargetStillValid()
        if not valid then
            Notify(reason, 'error')
            isTargetMenu = false
            targetPlayer = nil
            return
        end
    else
        SetupCamera(ped)
    end

    isOpen = true
    SetCursorEnabled(true, false)

    SendNUIMessage({
        type = 'open',
        items = Config.Clothing,
        colors = Config.Colors,
        states = clothingState,
        isTarget = isTargetMenu,
        targetName = isTargetMenu and GetPlayerName(NetworkGetPlayerIndexFromPed(targetPlayer)) or nil,
        itemSystem = Config.ItemSystem
    })

    StartPositionLoop()
end

function CloseMenu()
    if not isOpen then return end

    isOpen = false
    cursorEnabled = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'close' })

    if not isTargetMenu then
        CleanupCamera()
    end

    isTargetMenu = false
    targetPlayer = nil
end

function ToggleMenu()
    if isOpen then CloseMenu() else OpenMenu() end
end

function OpenTargetMenu(targetPed)
    if not DoesEntityExist(targetPed) then return end
    OpenMenu(targetPed)
end

local function SetupTarget()
    if not Config.EnableTargetPlayer then return end

    CreateThread(function()
        for _ = 1, 50 do
            if GetResourceState('ox_target') == 'started' then break end
            Wait(200)
        end

        if GetResourceState('ox_target') ~= 'started' then return end

        exports.ox_target:addGlobalPlayer({
            {
                name = 'sp_clothingmenu_remove',
                icon = Config.TargetIcon or 'fa-solid fa-shirt',
                label = Config.TargetLabel or 'Remover roupa',
                distance = Config.TargetDistance or 2.5,
                canInteract = CanTargetPlayer,
                onSelect = function(data)
                    OpenTargetMenu(data.entity)
                end
            }
        })
    end)
end

local function RunClothingProgress(label, duration, anim)
    local progress = Config.Progress or {}
    local options = {
        duration = duration or progress.removeDuration or 1500,
        label = label or progress.removeLabel or 'Removendo roupa...',
        useWhileDead = true,
        canCancel = progress.canCancel ~= false,
        disable = progress.disable or { car = true, combat = true }
    }

    if anim and anim.dict then
        options.anim = {
            dict = anim.dict,
            clip = anim.clip or anim.name,
            flag = anim.flag or 49
        }
    end

    return lib.progressBar(options)
end

local function GetCurrentVariation(ped, item)
    if item.type == 'prop' then
        return GetPedPropIndex(ped, item.component), GetPedPropTextureIndex(ped, item.component)
    end

    return GetPedDrawableVariation(ped, item.component), GetPedTextureVariation(ped, item.component)
end

local function ApplyOffVariation(ped, item, offDrawable, offTexture)
    if item.type == 'prop' then
        if offDrawable == -1 then
            ClearPedProp(ped, item.component)
        else
            SetPedPropIndex(ped, item.component, offDrawable, offTexture, true)
        end
        return
    end

    SetPedComponentVariation(ped, item.component, offDrawable, offTexture, 0)
end

local function ApplyClothingMetadata(ped, metadata)
    if type(metadata) ~= 'table' then return false end

    local drawable = tonumber(metadata.drawable)
    local texture = tonumber(metadata.texture) or 0
    local component = tonumber(metadata.component)
    local prop = tonumber(metadata.prop)

    if not drawable then return false end

    if prop then
        if drawable == -1 then
            ClearPedProp(ped, prop)
        else
            SetPedPropIndex(ped, prop, drawable, texture, true)
        end

        return true
    end

    if component then
        SetPedComponentVariation(ped, component, drawable, texture, 0)
        return true
    end

    return false
end

local function BuildMetadata(item, drawable, texture, targetServerId)
    return {
        label = tostring(item.label),
        description = ('%s | drawable %s / texture %s'):format(item.label, drawable, texture),
        texture = tonumber(texture) or 0,
        source = 'clothingmenu',
        itemName = tostring(item.itemName),
        targetServerId = targetServerId,
        component = item.type == 'component' and tonumber(item.component) or nil,
        prop = item.type == 'prop' and tonumber(item.component) or nil,
        drawable = tonumber(drawable) or 0
    }
end

function UseClothingItem(itemData, slotData)
    slotData = type(slotData) == 'table' and slotData or type(itemData) == 'table' and itemData or nil

    if not slotData then
        Notify('Item de roupa inválido.', 'error')
        return
    end

    local metadata = slotData.metadata

    if type(metadata) ~= 'table' then
        Notify('This clothing item has no saved outfit data.', 'error')
        return
    end

    local ped = PlayerPedId()
    local progress = Config.Progress or {}

    local itemConfig = FindItemConfigByName(metadata.itemName)
    if not itemConfig then
        Notify('Não foi possível encontrar a configuração do item.', 'error')
        return
    end

    if metadata.component then
        local currentDrawable = GetPedDrawableVariation(ped, metadata.component)
        local currentTexture = GetPedTextureVariation(ped, metadata.component)
        local offDrawable, offTexture = GetOffVariation(itemConfig, ped)

        if currentDrawable ~= offDrawable then
            Notify('Você já está usando algo neste espaço. Remova-o primeiro.', 'error')
            return
        end
    elseif metadata.prop then
        local currentDrawable = GetPedPropIndex(ped, metadata.prop)
        local currentTexture = GetPedPropTextureIndex(ped, metadata.prop)
        local offDrawable, offTexture = GetOffVariation(itemConfig, ped)

        if currentDrawable ~= -1 and currentDrawable ~= offDrawable then
            Notify('Você já está usando algo neste espaço. Remova-o primeiro.', 'error')
            return
        end
    end

    if not RunClothingProgress(metadata.label or progress.wearLabel or 'Vestindo roupa...', progress.wearDuration or 1200, progress.wearAnim) then
        Notify('Cancelado.', 'error')
        return
    end

    if not ApplyClothingMetadata(ped, metadata) then
        Notify('Não foi possível vestir este item de roupa.', 'error')
        return
    end

    TriggerServerEvent('clothingmenu:server:removeUsedClothingItem', slotData.name, slotData.slot, metadata)
    TriggerEvent('clothingmenu:client:clothingItemApplied', metadata)
    Notify(('%s equipado.'):format(metadata.label or 'Roupa'), 'success')
end

function ToggleClothingItem(index, item)
    local ped = GetActivePed()
    if not DoesEntityExist(ped) then
        Notify('O jogador selecionado não está mais disponível.', 'error')
        return
    end

    local valid, reason = IsTargetStillValid()
    if not valid then
        Notify(reason, 'error')
        CloseMenu()
        return
    end

    if Config.ItemSystem then
        if not clothingState[index] then
            Notify('Use o item de roupa no inventário para vesti-lo novamente.', 'error')
            return
        end
    end

    local offDrawable, offTexture = GetOffVariation(item, ped)
    local currentDrawable, currentTexture = GetCurrentVariation(ped, item)

    local progress = Config.Progress or {}
    local progressLabel = isTargetMenu and (progress.targetRemoveLabel or 'Removendo roupa do jogador...') or (progress.removeLabel or 'Removendo roupa...')
    local progressAnim = isTargetMenu and (item.removeAnim or progress.targetRemoveAnim or item.anim) or item.anim

    if clothingState[index] then
        if not RunClothingProgress(progressLabel, progress.removeDuration or 1500, progressAnim) then
            Notify('Cancelado.', 'error')
            return
        end

        if not Config.ItemSystem then
            savedOutfits[index] = { drawable = currentDrawable, texture = currentTexture }
        end

        ApplyOffVariation(ped, item, offDrawable, offTexture)
        clothingState[index] = false

        SendNUIMessage({ type = 'updateState', states = clothingState })

        if Config.ItemSystem then
            local targetServerId = isTargetMenu and GetPlayerServerIdFromPed(ped) or nil
            local metadata = BuildMetadata(item, currentDrawable, currentTexture, targetServerId)
            TriggerServerEvent('clothingmenu:server:addClothingItem', metadata)

            if isTargetMenu and targetServerId then
                local itemData = {
                    component = item.type == 'component' and item.component or nil,
                    prop = item.type == 'prop' and item.component or nil,
                    type = item.type,
                    offDrawable = offDrawable,
                    offTexture = offTexture
                }
                TriggerServerEvent('clothingmenu:server:syncClothingState', targetServerId, index, false, itemData)
            end
        else
            if isTargetMenu then
                local targetServerId = GetPlayerServerIdFromPed(ped)
                if targetServerId then
                    local itemData = {
                        component = item.type == 'component' and item.component or nil,
                        prop = item.type == 'prop' and item.component or nil,
                        type = item.type,
                        offDrawable = offDrawable,
                        offTexture = offTexture
                    }
                    TriggerServerEvent('clothingmenu:server:syncClothingState', targetServerId, index, false, itemData)
                end
            end
        end

        if not isTargetMenu then
            SaveAppearance(ped)
        end
    else
        if Config.ItemSystem then
            Notify('Use o item de roupa no inventário para vesti-lo novamente.', 'error')
            return
        end

        local saved = savedOutfits[index]
        if not saved then
            Notify('No saved outfit for this slot.', 'error')
            return
        end

        if not RunClothingProgress(progress.wearLabel or 'Vestindo roupa...', progress.wearDuration or 1200, progress.wearAnim) then
            Notify('Cancelado.', 'error')
            return
        end

        if item.type == 'prop' then
            if saved.drawable == -1 then
                ClearPedProp(ped, item.component)
            else
                SetPedPropIndex(ped, item.component, saved.drawable, saved.texture, true)
            end
        else
            SetPedComponentVariation(ped, item.component, saved.drawable, saved.texture, 0)
        end

        clothingState[index] = true
        SendNUIMessage({ type = 'updateState', states = clothingState })

        if isTargetMenu then
            local targetServerId = GetPlayerServerIdFromPed(ped)
            if targetServerId then
                local itemData = {
                    component = item.type == 'component' and item.component or nil,
                    prop = item.type == 'prop' and item.component or nil,
                    type = item.type,
                    drawable = saved.drawable,
                    texture = saved.texture
                }
                TriggerServerEvent('clothingmenu:server:syncClothingState', targetServerId, index, true, itemData)
            end
        end

        if not isTargetMenu then
            SaveAppearance(ped)
        end
    end
end

CreateThread(function()
    for i in ipairs(Config.Clothing) do
        clothingState[i] = true
    end

    SetupTarget()

    if GetResourceState('ox_lib') == 'started' then
        lib.registerRadial({
            id = 'clothingmenu_radial',
            items = {
                {
                    label = 'Abrir menu de roupas',
                    icon = 'fa-solid fa-shirt',
                    onSelect = function()
                        ToggleMenu()
                    end
                },
                {
                    label = 'Remover roupa (jogador)',
                    icon = 'fa-solid fa-shirt',
                    onSelect = function()
                        local ped = GetClosestPlayer(5.0)
                        if ped then
                            OpenTargetMenu(ped)
                        else
                            Notify('Nenhum jogador próximo foi encontrado.', 'error')
                        end
                    end
                }
            }
        })

        lib.addRadialItem({
            id = 'clothingmenu_open',
            label = 'Menu de roupas',
            icon = 'fa-solid fa-shirt',
            menu = 'clothingmenu_radial'
        })
    end
end)

function GetClosestPlayer(distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed, closestDist = nil, distance

    for _, ped in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(ped)
        if targetPed ~= playerPed and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)
            if dist < closestDist then
                closestDist = dist
                closestPed = targetPed
            end
        end
    end

    return closestPed
end

RegisterCommand(Config.Command, function()
    ToggleMenu()
end, false)

RegisterCommand('clothingtarget', function(_, args)
    local targetId = tonumber(args[1])
    if not targetId then
        Notify('Uso: /clothingtarget [id do servidor]')
        return
    end

    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if not DoesEntityExist(targetPed) then
        Notify('Jogador não encontrado ou não está próximo.')
        return
    end

    OpenTargetMenu(targetPed)
end, false)

RegisterCommand(Config.CursorCommand or 'clothingcursor', function()
    if not isOpen then return end
    SetCursorEnabled(not cursorEnabled, true)
end, false)

RegisterKeyMapping(Config.Command, 'Abrir menu de roupas', 'keyboard', Config.DefaultKey)
RegisterKeyMapping(Config.CursorCommand or 'clothingcursor', 'Alternar cursor do menu de roupas', 'keyboard', Config.CursorKey or 'LMENU')

RegisterNetEvent('clothingmenu:client:open', function()
    OpenMenu()
end)

RegisterNetEvent('clothingmenu:client:clothingItemApplied', function(metadata)
    if type(metadata) ~= 'table' then return end

    local index
    if metadata.component then
        index = FindClothingIndex('component', metadata.component)
    elseif metadata.prop then
        index = FindClothingIndex('prop', metadata.prop)
    end

    if index then
        clothingState[index] = true
        SendNUIMessage({ type = 'updateState', states = clothingState })
    end

    SaveAppearance()
end)

RegisterNetEvent('clothingmenu:client:useClothingItem', UseClothingItem)
exports('UseClothingItem', UseClothingItem)

-- ox_inventory: os slots de roupa mostram o que esta vestido (lido do ped) e tiram a peca pelo clique.

---@return table<string, boolean> vestido, por nome do item de roupa
exports('GetWornClothing', function()
    local ped = PlayerPedId()
    local worn = {}

    for _, item in ipairs(Config.Clothing) do
        if item.itemName then worn[item.itemName] = IsWearingItem(ped, item) end
    end

    return worn
end)

---Tira a peca do proprio jogador, como pelo menu: progresso, animacao e item gerado.
---@param itemName string
exports('RemoveClothing', function(itemName)
    if isOpen then return end

    for index, item in ipairs(Config.Clothing) do
        if item.itemName == itemName then
            CreateThread(function()
                RefreshClothingState(PlayerPedId())
                ToggleClothingItem(index, item)
            end)

            return
        end
    end
end)

RegisterNetEvent('clothingmenu:client:syncClothingState', function(index, state, itemData)
    if type(index) ~= 'number' then return end
    clothingState[index] = state == true
    SendNUIMessage({ type = 'updateState', states = clothingState })

    if not state and itemData then
        local ped = PlayerPedId()

        if IsEntityDead(ped) or GetEntityHealth(ped) <= 100 then
            return
        end

        if itemData.component then
            SetPedComponentVariation(ped, itemData.component, itemData.offDrawable, itemData.offTexture, 0)
        elseif itemData.prop then
            if itemData.offDrawable == -1 then
                ClearPedProp(ped, itemData.prop)
            else
                SetPedPropIndex(ped, itemData.prop, itemData.offDrawable, itemData.offTexture, true)
            end
        end
    elseif state and itemData then
        local ped = PlayerPedId()

        if IsEntityDead(ped) or GetEntityHealth(ped) <= 100 then
            return
        end

        if itemData.component then
            SetPedComponentVariation(ped, itemData.component, itemData.drawable, itemData.texture, 0)
        elseif itemData.prop then
            if itemData.drawable == -1 then
                ClearPedProp(ped, itemData.prop)
            else
                SetPedPropIndex(ped, itemData.prop, itemData.drawable, itemData.texture, true)
            end
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('toggleItem', function(data, cb)
    local index = tonumber(data.index) and tonumber(data.index) + 1
    local item = index and Config.Clothing[index]

    if item then
        CreateThread(function()
            ToggleClothingItem(index, item)
        end)
    end

    cb('ok')
end)
