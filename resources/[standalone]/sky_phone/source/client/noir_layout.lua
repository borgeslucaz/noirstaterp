-- Noir State: o celular por cima de tudo e fora do velocímetro.
--
-- * Z-index da página do celular acima das outras NUIs: a notificação aparecia por baixo da
--   HUD do carro (noir_hud), que é outro resource.
-- * Dentro de veículo, o celular sai do canto inferior direito, onde fica o velocímetro do
--   noir_hud, e vai para o lado dele. A página recebe `noir:layout` e troca uma classe; o CSS
--   está em source/html/noir-layout.css.

pcall(SetNuiZindex, 1000)

local inVehicle = nil

local function send(state)
    if state == inVehicle then return end
    inVehicle = state
    SendNUIMessage({ type = "noir:layout", inVehicle = state })
end

CreateThread(function()
    while true do
        send(GetVehiclePedIsIn(PlayerPedId(), false) ~= 0)
        Wait(500)
    end
end)

-- Página recarregada (restart): manda o estado de novo no próximo ciclo.
AddEventHandler("onClientResourceStart", function(resource)
    if resource == GetCurrentResourceName() then inVehicle = nil end
end)
