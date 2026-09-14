CameraManager = {}

local function warn(message, detail)
    print(('[noir_guncraft] %s%s'):format(message, detail and (': ' .. tostring(detail)) or ''))
end

local isCamActive = false
local workbenchCam = nil

function CameraManager.startWorkbenchView(benchEntity)
    if isCamActive then 
        warn("Camera already active")
        return false
    end

    local success, result = pcall(function()
        local benchCoords = GetEntityCoords(benchEntity)
        local camPos = benchCoords + Config.WorkbenchCamera.offset
        local targetPos = benchCoords + Config.WorkbenchCamera.target

        workbenchCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 
            camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 
            Config.WorkbenchCamera.fov, false, 0)
        
        PointCamAtCoord(workbenchCam, targetPos.x, targetPos.y, targetPos.z)
        SetCamActiveWithInterp(workbenchCam, GetRenderingCam(), Config.WorkbenchCamera.transitionTime, true, true)
        RenderScriptCams(true, true, Config.WorkbenchCamera.transitionTime, true, true)

        local playerPed = PlayerPedId()
        FreezeEntityPosition(playerPed, true)
        SetEntityVisible(playerPed, false, false)
        isCamActive = true
        return true
    end)

    if not success then
        warn("Failed to start workbench view", result)
        return false
    end
    
    return result
end

function CameraManager.stopWorkbenchView()
    if not isCamActive then return end

    local success, result = pcall(function()
        RenderScriptCams(false, true, Config.WorkbenchCamera.transitionTime, true, true)
        
        CreateThread(function()
            Wait(Config.WorkbenchCamera.transitionTime)
            if DoesCamExist(workbenchCam) then
                DestroyCam(workbenchCam, false)
            end
            workbenchCam = nil
        end)

        local playerPed = PlayerPedId()
        FreezeEntityPosition(playerPed, false)
        SetEntityVisible(playerPed, true, false)
        isCamActive = false
    end)

    if not success then
        warn("Failed to stop workbench view", result)
    end
end