local VehicleKeys = require 'client.interface'
local Utils = require 'client.modules.utils'

local Hotwire = {
    isHotwiring = false,
    watching = false
}

local function ShowHotwireText(show)
    if show and not VehicleKeys.showTextUi then
        lib.showTextUI('Ligação direta', { position = "right-center", icon = 'h' })
        VehicleKeys.showTextUi = true
    elseif not show and VehicleKeys.showTextUi then
        lib.hideTextUI()
        VehicleKeys.showTextUi = false
    end
end

function Hotwire:HotwireHandler()
    if self.isHotwiring then return end
    self.isHotwiring = true
    local vehicle = VehicleKeys.currentVehicle
    local success = false
    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, math.random(Shared.hotwire.minTime, Shared.hotwire.maxTime))
    lib.hideTextUI()
    VehicleKeys.showTextUi = false

    -- Minigame de fios no lugar da barra de progresso; a animação roda por baixo da NUI.
    local dict, clip = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer'
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, clip, 8.0, -8.0, -1, 1, 0, false, false, false)
    local wired = exports['rep-enginewire']:MiniGame()
    StopAnimTask(cache.ped, dict, clip, 1.0)
    RemoveAnimDict(dict)

    if wired and VehicleKeys.currentVehicle == vehicle and VehicleKeys.isInDrivingSeat then
        TriggerServerEvent('hud:server:GainStress', Shared.hotwire.stressIncrease)
        -- Chance sobe um degrau por nível de arrombamento, até 100% no nível máximo.
        local level = math.max(Utils:GetSkillLevel(), 1)
        local chance = math.min(Shared.hotwire.chance + Shared.hotwire.chancePerLevel * (level - 1), 1.0)

        if math.random() <= chance then
            -- sem chave: o carro fica ligado enquanto o motor rodar; desligou, precisa de nova ligacao
            Utils:SetHotwired(VehicleKeys.currentVehicle, true)
            -- depois do setHotwired: o servidor confere a marca antes de dar XP
            TriggerServerEvent('mri_Qcarkeys:server:hotwireXp', NetworkGetNetworkIdFromEntity(VehicleKeys.currentVehicle))
            SetVehicleEngineOn(VehicleKeys.currentVehicle, true, true, true)
            VehicleKeys.isEngineRunning = true
            success = true
            self.isHotwiring = false
            return
        end

        local description
        if chance < 0.4 then
            description = 'Isso parece muito complicado para você!'
        elseif chance < 0.55 then
            description = 'Isso parece complicado pra você!'
        elseif chance < 0.7 then
            description = 'Isso parece difícil pra você!'
        elseif chance < 0.85 then
            description = 'Isso parece normal para você!'
        else
            description = 'Erros? Mas você não erra...'
        end

        lib.notify({
            title = 'Falhou',
            description = description,
            type = 'error'
        })
    else
        lib.notify({
            title = 'Falhou',
            description = 'Ligação direta falhou!',
            type = 'error'
        })
    end
    if VehicleKeys.currentVehicle and VehicleKeys.isInDrivingSeat and not success and not VehicleKeys.showTextUi then
        lib.showTextUI('Ligação direta', {
            position = "right-center",
            icon = 'h',
        })
        VehicleKeys.showTextUi = true
    end
    self.isHotwiring = false
end

---Motorista sem chave: motor so roda se o carro estiver em ligacao direta. Quando o motor para, a
---ligacao acaba e precisa ser feita de novo. Um laco por vez.
function Hotwire:SetupHotwire()
    if self.watching then return end
    self.watching = true
    CreateThread(function()
        while VehicleKeys.currentVehicle ~= 0 and not VehicleKeys.hasKey do
            local vehicle = VehicleKeys.currentVehicle
            if Utils:IsHotwired(vehicle) then
                if not GetIsVehicleEngineRunning(vehicle) then
                    Utils:SetHotwired(vehicle, false)
                end
                ShowHotwireText(false)
            else
                SetVehicleEngineOn(vehicle, false, false, true)
                VehicleKeys.isEngineRunning = false
                if Shared.hotwire.available and VehicleKeys.isInDrivingSeat then
                    ShowHotwireText(true)
                    if IsControlJustPressed(0, 74) then
                        self:HotwireHandler()
                    end
                end
            end
            Wait(5)
        end
        self.watching = false
    end)
end

return Hotwire