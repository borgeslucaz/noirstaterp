local ped
local InMenu = false

---@param slot integer
CreateMenu = function(slot)

    ped = PlayerPedId()
    InMenu = true

    local offset = GetOffsetFromEntityInWorldCoords(ped, 0, 2.5, 0.5 )

    SetCamParams(cam,  offset.x + Config.CreateMenu.camoffset.x, offset.y + Config.CreateMenu.camoffset.y, offset.z + Config.CreateMenu.camoffset.z, Config.CreateMenu.camrotation.x, Config.CreateMenu.camrotation.y, Config.CreateMenu.camrotation.z, Config.CreateMenu.fov,1000, 0, 0, 2)
    PointCamAtEntity(cam, ped, Config.CreateMenu.pointcamoffset.x, Config.CreateMenu.pointcamoffset.y, Config.CreateMenu.pointcamoffset.z, true)
    SetTimecycleModifier('MIDDAY')
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, 0.4)
    SetCamFarDof(cam, 1.8)
    SetCamDofStrength(cam, 0.7)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 3000, true, true)

    CreateThread(function()
        while InMenu do
            SetUseHiDof()
            Wait(0)
        end
    end)

    Wait(1000)

    Nuimessage('charactercreator', slot)
end

-- ---@return integer
-- CreateNewCharacterPed = function ()
--     local ped
--     local coords = Config.CreateMenu.location
--     local model = Config.CreateMenu.newcharactermodel
--     local dict = Config.CreateMenu.dict
--     local anim = Config.CreateMenu.anim

--     lib.requestModel(model)
--     ped = CreatePed(2, model, coords.x, coords.y, coords.z, coords.w, false, false)
--     lib.requestAnimDict(dict)
--     TaskPlayAnim(ped,dict,anim,-1,-1, -1, 1, 1, true, true, true)
--     FreezeEntityPosition(ped, true)
--     SetFocusEntity(ped)
--     SetModelAsNoLongerNeeded(model)

--     return ped
-- end



DeleteCreateCamScene = function()
    ClearFocus()
    SetCamActive(cam, false)
    DestroyCam(cam, true)
    RenderScriptCams(false, false, 1, true, true)
    DeleteEntity(ped)

    CreateThread( function ()
        Wait(1000)
        if DoesEntityExist(previewvehicle) then
            DeleteEntity(previewvehicle)
        end
    end)
end





NewCharacterAnimation = function()
    local data = Config.NewCharacterSpawn
    SetEntityCoordsNoOffset(PlayerPedId(), data.startcoords.x, data.startcoords.y, data.startcoords.z)
    FreezeEntityPosition(PlayerPedId(),false)
    local Cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', data.camcoords.x, data.camcoords.y,data.camcoords.z, data.camrotation.x, data.camrotation.y,
    data.camrotation.z, 50.0, true, 0)
    SetCamActive(Cam, true)
    RenderScriptCams(true, false, 0, true, true)

    Wait(750)
    DoScreenFadeIn(750)


    TaskGoToCoordAnyMeans(PlayerPedId(), data.endcoords.x, data.endcoords.y, data.endcoords.z, 1.0, 0, false, 1, 0)

    while true do
        if #(GetEntityCoords(PlayerPedId()) - data.endcoords) < 8 then
            break
        end
        Wait(100)
    end

    SetGameplayCamRelativeHeading(9)
    SetNuiFocus(false, false)
    RenderScriptCams(false, true, 3000, true, true)
    SetCamActive(cam, false)
    Wait(3000)

    return true
end


LastLocation = function()
    local coords = GetEntityCoords(PlayerPedId())
    local Cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x,coords.y,coords.z + 8, 0, 0,0, 50.0, true, 0)
    SetCamActive(Cam, true)
    RenderScriptCams(true, false, 0, true, true)

    Wait(750)
    DoScreenFadeIn(750)

    SetGameplayCamRelativeHeading(9)
    SetNuiFocus(false, false)
    RenderScriptCams(false, true, 3000, true, true)
    SetCamActive(cam, false)
    Wait(3000)
    AnimpostfxPlay('SwitchSceneMichael',2000,false)
    PlaySoundFrontend(-1, "1st_Person_Transition", 'PLAYER_SWITCH_CUSTOM_SOUNDSET', 0)

    CreateThread( function ()
        Wait(2000)
        DestroyCam(Cam, true)
    end)
    return true
end


RegisterNUICallback('exitcharactercreator', function(payload, cb)
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
    local data = GetCurrentScene()
    SetCamParams(cam,  data.camlocation.x, data.camlocation.y,data.camlocation.z, data.camrotation.x,data.camrotation.y,data.camrotation.z, data.fov,1000, 0, 0, 2)
    RenderScriptCams(true, false, 3000, true, true)
    Wait(1000)
    InMenu = false
    cb { {}  }
end)
