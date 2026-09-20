---Smash & Grab — ponto de entrada do client.
---
---Segura a única thread do módulo (a varredura em intervalo) e as ferramentas de
---debug. A lógica está em `world.lua` (o que existe no mundo) e em
---`interaction.lua` (o que o jogador faz com isso).

local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local SharedConfig = require 'config.shared'
local CrimeConfig = require 'config.smashgrab'
local Integrations = require 'client.integrations'
local World = require 'client.crimes.smashgrab.world'

local CRIME = Constants.crimes.smashgrab
local DebugPrint = Utils.debugPrint(CRIME)

local module = {}
local running = false
local overlay = false

-- ---------------------------------------------------------------------------
-- Varredura
-- ---------------------------------------------------------------------------

---A única thread do módulo, com sleep adaptativo (§14.3).
---
---O intervalo cresce quando não há nada a fazer: dirigindo, morto, deslogado ou sem
---nenhum objeto por perto. Varrer o pool de veículos a cada 1,5 s faz sentido com o
---jogador a pé numa rua cheia de carros parados; não faz nenhum quando ele está
---atravessando o mapa de carro.
---@return integer sleep em ms
local function nextInterval()
    if not Integrations.isLoggedIn() or IsPlayerSwitchInProgress()
        or IsEntityDead(cache.ped) then
        return CrimeConfig.scanIdleInterval
    end

    -- O backoff é por REGIÃO VAZIA, e não por estar dirigindo nem por não ter
    -- nada rastreado ainda. Dirigindo o jogador cobre 100 m em 5 s, e o prop só
    -- nasce a 60 m: desacelerar ali fazia passar batido justo quando ele está
    -- caçando. "Nada rastreado" também é o estado de quem está procurando.
    -- Sem nenhum veículo por perto, aí sim não há o que fazer.
    if World.lastNearbyCount() == 0 then return CrimeConfig.scanIdleInterval end
    return CrimeConfig.scanInterval
end

---Por que a varredura não está rodando, ou nil quando está.
---
---Existe para que "nenhuma linha no console" nunca mais seja um mistério: o
---silêncio passa a ter motivo escrito.
---@return string?
local function inactiveReason()
    if not Integrations.isLoggedIn() then return 'personagem não carregado' end
    if IsPlayerSwitchInProgress() then return 'troca de personagem em andamento' end
    if IsEntityDead(cache.ped) then return 'jogador morto' end
    return nil
end

local function scanLoop()
    local lastReason

    while running do
        -- Dirigindo a varredura CONTINUA rodando, só mais devagar (`nextInterval`
        -- devolve o intervalo ocioso). Procurar carro estacionado enquanto se
        -- roda a cidade é o loop natural deste crime; desligar aqui deixava o
        -- sistema inerte justamente na hora em que o jogador está caçando.
        local reason = inactiveReason()

        if not reason then
            local ok, err = pcall(World.scan)
            if not ok then lib.print.error(('erro na varredura: %s'):format(err)) end
        else
            if reason ~= lastReason then
                DebugPrint('varredura parada:', reason)
            end
            if next(World.tracked()) then pcall(World.releaseAll) end
        end

        lastReason = reason
        Wait(nextInterval())
    end
end

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------

---Desenha o estado de cada objeto rastreado. Só existe com `Config.debug` ligado e
---só roda depois de `/smashdebug`. É o único Wait(0) contínuo do resource — o outro
---(carregar modelo, em world.lua) tem prazo e termina. Em produção, nenhum dos dois
---fica de pé.
local function overlayLoop()
    while overlay do
        for _, entry in pairs(World.tracked()) do
            if DoesEntityExist(entry.prop) then
                local coords = GetEntityCoords(entry.prop)
                local status = Entity(entry.vehicle).state[Constants.state.smashGrab] or 'available'
                local intact = IsVehicleWindowIntact(entry.vehicle, entry.windowIndex)

                DrawLine(coords.x, coords.y, coords.z,
                    coords.x, coords.y, coords.z + 1.0, 0, 255, 128, 200)

                SetTextScale(0.30, 0.30)
                SetTextFont(4)
                SetTextColour(intact and 255 or 120, intact and 160 or 255, 120, 255)
                SetTextCentre(true)
                SetDrawOrigin(coords.x, coords.y, coords.z + 1.05, 0)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(('%s / %s\nnetId %d  janela %d  %s\n%s')
                    :format(entry.loot.propKey, entry.loot.seatKey, entry.netId,
                        entry.windowIndex, intact and 'INTEIRO' or 'QUEBRADO', status))
                EndTextCommandDisplayText(0.0, 0.0)
                ClearDrawOrigin()
            end
        end
        Wait(0)
    end
end

local function registerDebugCommands()

    RegisterCommand('smashdebug', function()
        overlay = not overlay
        Integrations.notify(('Smash & grab overlay: %s'):format(overlay and 'ligado' or 'desligado'), 'inform')
        if overlay then CreateThread(overlayLoop) end
    end, false)

    ---Explica o veículo em que o jogador está mirando: por que tem ou não tem
    ---objeto. É o comando que responde "por que esse carro nunca tem nada".
    RegisterCommand('smashinfo', function()
        local hit, entity = GetEntityPlayerIsFreeAimingAt(cache.playerId)
        if not hit or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
            local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, false)
            if not vehicle then return Integrations.notify('Nenhum veículo por perto.', 'error') end
            entity = vehicle
        end

        local eligible, reason = World.isEligible(entity)
        local plate = GetVehicleNumberPlateText(entity)
        lib.print.info(('smashinfo: netId %s | placa "%s" | classe %d | elegível: %s%s')
            :format(NetworkGetNetworkIdFromEntity(entity), plate, GetVehicleClass(entity),
                tostring(eligible), eligible and '' or (' (' .. tostring(reason) .. ')')))

        if not eligible then
            return Integrations.notify(('Não elegível: %s'):format(reason), 'error')
        end

        -- A decisão é do servidor, então aqui só lemos o que ele já respondeu. Um
        -- carro ainda não perguntado aparece como "aguardando" em vez de mentir.
        local loot = World.known(entity)
        if loot == nil then
            lib.print.info('smashinfo: ainda não perguntado ao servidor')
            return Integrations.notify('Aguardando a próxima varredura.', 'inform')
        end
        if not loot then
            lib.print.info('smashinfo: o servidor disse que não tem objeto')
            return Integrations.notify('Elegível, mas sem objeto.', 'inform')
        end

        lib.print.info(('smashinfo: %s no %s, janela %d'):format(loot.propKey, loot.seatKey, loot.seat.window))
        Integrations.notify(('%s no %s (janela %d)'):format(loot.propKey, loot.seatKey, loot.seat.window), 'success')
    end, false)
end

-- ---------------------------------------------------------------------------
-- Ciclo de vida
-- ---------------------------------------------------------------------------

function module.start()
    World.start()

    running = true
    CreateThread(scanLoop)

    if SharedConfig.debug then
        registerDebugCommands()
        DebugPrint('comandos /smashdebug e /smashinfo registrados')
    end
end

function module.stop()
    running = false
    overlay = false
    World.stop()
end

return module
