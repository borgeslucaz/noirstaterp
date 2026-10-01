local config = require 'config.server'
local Rules = require 'server.rules'
local Integrations = require 'server.integrations'

local crimesByKey = Rules.index(config.crimes)
local busy = {} ---@type table<string, boolean>
local nextOpenAt = {} ---@type table<integer, integer>

-- API para os crimes ------------------------------------------------------------

---Mínimo de policiais de um crime da tabela pública.
---@param key string
---@return integer? minimumPolice nil quando o crime não está na tabela
local function getMinimumPolice(key)
    local crime = crimesByKey[key]
    return crime and crime.minimumPolice or nil
end

---Confere no servidor se o crime pode começar agora. Sem contagem de polícia, não libera.
---@param key string
---@return boolean ok
---@return string? code 'unknown_crime' | 'police_unavailable' | 'not_enough_police'
---@return integer? minimumPolice
---@return integer? police policiais em serviço contados agora
local function checkPolice(key)
    local crime = crimesByKey[key]
    if not crime then
        lib.print.warn(('CheckPolice: crime fora da tabela: %s'):format(tostring(key)))
        return false, 'unknown_crime'
    end
    local police = Integrations.policeCount()
    if not police then return false, 'police_unavailable', crime.minimumPolice end
    local ok, code = Rules.check(crime, police)
    return ok, code, crime.minimumPolice, police
end

---Marca o crime como em andamento no placar.
---@param key string
---@param state boolean
local function setActivityBusy(key, state)
    if not crimesByKey[key] then
        lib.print.warn(('SetActivityBusy: crime fora da tabela: %s'):format(tostring(key)))
        return
    end
    busy[key] = state == true or nil
end

exports('GetMinimumPolice', getMinimumPolice)
exports('CheckPolice', checkPolice)
exports('SetActivityBusy', setActivityBusy)

-- O qbx_jewelery e o qbx_bankrobbery marcam "em andamento" por este evento, com
-- TriggerEvent no servidor. É local de propósito: no qbx_scoreboard ele era de rede,
-- e qualquer cliente podia marcar ou desmarcar um banco.
AddEventHandler('qb-scoreboard:server:SetActivityBusy', setActivityBusy)

-- Placar ------------------------------------------------------------------------

lib.callback.register('noir_scoreboard:server:open', function(source)
    local now = GetGameTimer()
    if (nextOpenAt[source] or 0) > now then return nil end
    nextOpenAt[source] = now + config.openCooldownMs

    local admins = {}
    local players = GetPlayers()
    for index = 1, #players do
        local playerSource = tonumber(players[index])
        if playerSource and Integrations.isAdminOnDuty(playerSource) then admins[playerSource] = true end
    end

    local data = {
        players = #players,
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        admins = admins,
    }

    -- A tabela é só para quem está numa gang; os outros nem recebem os números.
    if Rules.isGangMember(Integrations.characterGangs(source)) then
        local police = Integrations.policeCount()
        data.crimes = police and Rules.table(config.crimes, police, busy) or nil
        data.policeUnavailable = police == nil
    end

    return data
end)

AddEventHandler('playerDropped', function()
    nextOpenAt[source] = nil
end)
