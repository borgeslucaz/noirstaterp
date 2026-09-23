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
    local enginewire = nil
    if GetResourceState('rep-enginewire') == 'started' then
        enginewire = exports["rep-enginewire"]:MiniGame()
    end
    if self.isHotwiring then return end
    self.isHotwiring = true
    local hotwireTime = math.random(Shared.hotwire.minTime, Shared.hotwire.maxTime)
    local success = false
    SetVehicleAlarm(VehicleKeys.currentVehicle, true)
    SetVehicleAlarmTimeLeft(VehicleKeys.currentVehicle, hotwireTime)
    lib.hideTextUI()
    VehicleKeys.showTextUi = false

    if lib.progressBar({
        label = Shared.hotwire.label,
        duration = hotwireTime,
        position = 'bottom',
        allowCuffed = false,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    }) and (enginewire == nil and true or enginewire) then
        TriggerServerEvent('hud:server:GainStress', Shared.hotwire.stressIncrease)
        local level = Utils:GetSkillLevel("hotwiring")
        if level > 8 then
            level = 8
        end

        if level ==  0 then
            level = 1
        end

        if (math.random() <= Shared.hotwire.chance * level) then
            Utils:AddSkill("hotwiring")
            -- sem chave: o carro fica ligado enquanto o motor rodar; desligou, precisa de nova ligacao
            Utils:SetHotwired(VehicleKeys.currentVehicle, true)
            SetVehicleEngineOn(VehicleKeys.currentVehicle, true, true, true)
            VehicleKeys.isEngineRunning = true
            success = true
            self.isHotwiring = false
            return
        end

        local description
        if level <= 1 then
            description = 'Isso parece impossível para você!'
        elseif level <= 2 then
            description = 'Isso parece muito complicado para você!'
        elseif level <= 3 then
            description = 'Isso parece complicado pra você!'
        elseif level <= 4 then
            description = 'Isso parece difícil pra você!'
        elseif level <= 5 then
            description = 'Isso parece normal para você!'
        elseif level <= 8 then
            description = 'Erros? Mas você não erra...'
        else
            description = 'Você é tão experiente, como errou?'
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