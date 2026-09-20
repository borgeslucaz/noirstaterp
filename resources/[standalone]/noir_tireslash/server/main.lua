local cooldown = {}

---Toca o som do corte saindo do proprio veiculo, para todos os clientes por perto.
---Nome ou ref de audio que nao existem falham em silencio, sem erro.
---@param netId number
local function playSlashSound(netId)
    if not Config.sound then return end

    if GetResourceState('mana_audio') ~= 'started' then
        if Config.debug then print('[noir_tireslash] mana_audio nao esta started, som ignorado') end
        return
    end

    if Config.debug then
        print(('[noir_tireslash] tocando %s / %s no netId %s')
            :format(Config.sound.audioName, Config.sound.audioRef, netId))
    end

    exports.mana_audio:PlaySoundFromEntity({
        audioBank = Config.sound.audioBank,
        audioName = Config.sound.audioName,
        audioRef = Config.sound.audioRef,
        netId = netId,
    })
end

---Validacao compartilhada pelos dois caminhos: indice de pneu real, cooldown do
---jogador e distancia ate o veiculo.
---@param source number
---@param netId number
---@param tyreIndex number?
---@return number? vehicle
local function validate(source, netId, tyreIndex)
    if type(netId) ~= 'number' then return end
    if tyreIndex ~= nil and not Config.validTyreIndex[tyreIndex] then return end

    local now = GetGameTimer()

    if cooldown[source] and now < cooldown[source] then return end

    cooldown[source] = now + Config.cooldown

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end

    local ped = GetPlayerPed(source)

    if ped == 0 then return end
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.maxDistance then return end

    return vehicle
end

-- Disparado quando o proprio cortador conseguiu estourar o pneu: o estouro ja
-- replicou sozinho, so o som precisa passar pelo servidor para todos ouvirem.
RegisterNetEvent('noir_tireslash:sound', function(netId)
    local source = source

    if not validate(source, netId) then return end

    playSlashSound(netId)
end)

-- Fallback used when the slasher cannot take network control of the vehicle
-- (mostly when another player is driving it). The request is relayed to the
-- entity owner, who is the only client able to replicate the tyre burst.
RegisterNetEvent('noir_tireslash:slash', function(netId, tyreIndex)
    local source = source
    local vehicle = validate(source, netId, tyreIndex)

    if not vehicle then return end

    local owner = NetworkGetEntityOwner(vehicle)

    if owner <= 0 then return end

    TriggerClientEvent('noir_tireslash:burst', owner, netId, tyreIndex)
    playSlashSound(netId)
end)

AddEventHandler('playerDropped', function()
    cooldown[source] = nil
end)
