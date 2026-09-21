local Framework = GetResourceState('es_extended') == 'started' and 'esx' or GetResourceState('qbx_core') == 'started' and 'qbx' or GetResourceState('qb-core') == 'started' and 'qb' or 'Unknown'
FullyLoaded = false
if Framework == 'qb' or Framework == 'qbx' then
    FullyLoaded = LocalPlayer.state.isLoggedIn
elseif Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
    FullyLoaded = Framework == 'esx' and ESX.PlayerLoaded or false
else
	print('^6[^3Renewed-Banking^6]^0 Unsupported Framework detected!')
end

AddStateBagChangeHandler('isLoggedIn', nil, function(_, _, value)
    FullyLoaded = value
end)

local function initalizeBanking()
    CreatePeds()
    local locales = lib.getLocales()
    SendNUIMessage({
        action = 'updateLocale',
        translations = locales,
        currency = Config.currency
    })
end
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(100)
    initalizeBanking()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    Wait(100)
    FullyLoaded = true
    initalizeBanking()
end)

-- PATCH NOIR: restart deixava o banco sem ped.
--
-- `FullyLoaded` é lido UMA vez, quando o script carrega. Num restart os scripts recarregam e
-- essa leitura pega o state bag antes de ele replicar -- fica falso. E o
-- `AddStateBagChangeHandler` acima só dispara quando o valor MUDA, o que não acontece: o
-- jogador já estava logado. Resultado: `initalizeBanking` nunca rodava e o ped não nascia até
-- relogar.
--
-- Aqui relemos o state bag ao vivo, com teto de espera em vez de desistir na primeira leitura.
-- É o padrão que o XS-CriminalTablet já usa neste servidor.
-- `onClientResourceStart` é o evento de CLIENT. O upstream usava `onResourceStart`, que é
-- server-side e NUNCA dispara aqui -- por isso `initalizeBanking` só rodava pelo caminho do
-- `OnPlayerLoaded`, e num restart com o jogador já logado esse evento não se repete.
--
-- Essa é a causa do ped sumir, confirmada em jogo: `FullyLoaded=true`, jogador a 1 metro do
-- banco, e `pontos de ped ativos: 0`.
--
-- Os dois ficam registrados. Chamar duas vezes é inofensivo: `CreatePeds` guarda com `pedSpawned`.
local function onStart(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Espera com teto: num restart o state bag pode ainda não ter replicado.
    local waited = 0
    while not (FullyLoaded or LocalPlayer.state.isLoggedIn) do
        if waited >= 30000 then
            return
        end
        Wait(200)
        waited = waited + 200
    end

    FullyLoaded = true
    initalizeBanking()
end

AddEventHandler('onClientResourceStart', onStart)
AddEventHandler('onResourceStart', onStart)


RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    DeletePeds()
end)

AddEventHandler('esx:onPlayerLogout', function()
    DeletePeds()
end)


-- `/bancodiag` despeja o estado do banco no console (F8). Ficou permanente: foi o que
-- localizou o evento errado que impedia o ped de nascer, e custa nada estar disponível.
RegisterCommand('bancodiag', function()
    print('^5[banco]^0 ----- diagnostico -----')
    print(('^5[banco]^0 isLoggedIn no state bag: %s'):format(tostring(LocalPlayer.state.isLoggedIn)))
    print(('^5[banco]^0 FullyLoaded: %s'):format(tostring(FullyLoaded)))
    print(('^5[banco]^0 peds configurados: %s'):format(tostring(Config and #Config.peds)))
    print(('^5[banco]^0 ox_target: %s'):format(GetResourceState('ox_target')))

    local pontos = lib.points.getAllPoints()
    print(('^5[banco]^0 pontos de ped ativos: %s'):format(#pontos))

    local vivos = 0
    for i = 1, #pontos do
        if pontos[i].ped and DoesEntityExist(pontos[i].ped) then vivos = vivos + 1 end
    end
    print(('^5[banco]^0 peds existindo agora: %s'):format(vivos))

    local meu = GetEntityCoords(cache.ped)
    local perto, dist = nil, 9999
    for i = 1, #Config.peds do
        local d = #(meu - vector3(Config.peds[i].coords.x, Config.peds[i].coords.y, Config.peds[i].coords.z))
        if d < dist then perto, dist = i, d end
    end
    print(('^5[banco]^0 banco mais proximo: #%s a %.0f metros'):format(tostring(perto), dist))
    print('^5[banco]^0 ----- fim -----')
end, false)
