-- Repasse dos bairros do Zone Manager para o cliente.
--
-- A geometria só existe no servidor (`exports.zonemanager:GetZones()`), e é o cliente que
-- precisa dela para desenhar. O cálculo do preenchimento fica lá porque assim dá para trocar
-- a grade em jogo, sem ida e volta de rede a cada tentativa.

local function zoneList()
    if GetResourceState('zonemanager') ~= 'started' then return {} end

    local ok, zones = pcall(function() return exports.zonemanager:GetZones() end)
    if not ok or type(zones) ~= 'table' then return {} end
    return zones
end

---Espelho do diagnóstico do cliente no console do servidor. Só texto, e só isso.
RegisterNetEvent('noir_territories:server:log', function(line)
    if type(line) ~= 'string' or #line > 300 then return end
    print(('[%s] %s'):format(GetPlayerName(source) or source, line))
end)

RegisterNetEvent('noir_territories:server:requestZones', function()
    TriggerClientEvent('noir_territories:client:zones', source, zoneList())
end)

---O editor do Zone Manager salva e reinicia o resource dele: quando isso acontece, o que os
---clientes têm desenhado é a cidade de antes.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'zonemanager' then return end
    CreateThread(function()
        Wait(1000)
        TriggerClientEvent('noir_territories:client:zones', -1, zoneList())
    end)
end)
