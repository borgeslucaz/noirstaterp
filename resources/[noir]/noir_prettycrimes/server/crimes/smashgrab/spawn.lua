---Smash & Grab — quem tem objeto, decidido só aqui.
---
---Antes isto era determinístico e os dois lados calculavam: custava zero rede, mas
---exigia publicar o salt, e com o salt um client adulterado enumerava o mapa
---inteiro antes de sair de casa. Agora o servidor decide e guarda; o client
---pergunta sobre veículos específicos e o servidor **só responde sobre os que estão
---perto dele de verdade**. É isso que fecha o ESP: sem a resposta, não há o que
---calcular, e a resposta não sai sem distância conferida.
---
---A decisão é tomada UMA vez por veículo e memorizada. Dois jogadores que
---perguntam sobre o mesmo carro recebem a mesma coisa porque leem o mesmo registro,
---não porque recalculam.

local Utils = require 'shared.utils'
local Constants = require 'shared.constants'
local CrimeConfig = require 'config.smashgrab'
local ServerConfig = require 'config.smashgrab_server'
local Rules = require 'shared.smashgrab_rules'

local CRIME = Constants.crimes.smashgrab
local DebugPrint = Utils.debugPrint(CRIME)

local Spawn = {}

---[netId] = { plate, loot = table|false }
---
---A placa entra junto porque netId é reciclado pelo jogo: se o carro daquele netId
---tem outra placa, é outro carro e a decisão precisa ser refeita. Sem isso o prop
---de um Sultan reapareceria dentro de um Blista.
---@type table<number, table>
local decisions = {}

---@param class integer?
---@return number
local function spawnMultiplier(class)
    local config = ServerConfig.classMultipliers
    if not config.enabled then return 1.0 end
    if not Utils.isFinite(class) then return config.default end
    return config.spawn[class] or config.default
end

---Rola o objeto de um veículo. Chamada uma vez por veículo; o resultado é memorizado.
---@param class integer?
---@param forced boolean?
---@return table|false loot
local function roll(class, forced)
    if not forced then
        local chance = ServerConfig.spawnChance * spawnMultiplier(class)
        if math.random() >= chance then return false end
    end

    local prop = Utils.pickWeighted(Rules.props)
    local seat = Utils.pickWeighted(Rules.seats)
    if not prop or not seat then return false end

    return { propKey = prop.key, seatKey = seat.key, prop = prop, seat = seat }
end

---Decisão memorizada de um veículo, rolando na primeira vez.
---@param netId number
---@param vehicle number
---@param class integer?
---@return table|false loot
---@return string? plate
function Spawn.decisionFor(netId, vehicle, class)
    local plate = Rules.normalizePlate(GetVehicleNumberPlateText(vehicle))
    if CrimeConfig.eligibility.requirePlate and not plate then return false end

    local known = decisions[netId]
    if known and known.plate == plate then return known.loot, plate end

    -- Sem herdar `forced`: placa diferente é outro carro, e o forçado do debug
    -- valia para aquele, não para este.
    local loot = roll(class)
    decisions[netId] = { plate = plate, loot = loot }
    if loot then
        DebugPrint(('netId %d sorteado: %s no %s'):format(netId, loot.propKey, loot.seatKey))
    end
    return loot, plate
end

---Força objeto num veículo (ferramenta de debug). Grava direto no registro, então
---o objeto forçado é tão real quanto o sorteado e passa pela mesma validação.
---@param netId number
---@param vehicle number
---@return table|false loot
function Spawn.force(netId, vehicle)
    local plate = Rules.normalizePlate(GetVehicleNumberPlateText(vehicle))
    local loot = roll(nil, true)
    decisions[netId] = { plate = plate, loot = loot }
    return loot
end

---Descarta decisões de veículos que não existem mais.
---@return integer removed
function Spawn.prune()
    local dead = {}
    for netId in pairs(decisions) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if not entity or entity == 0 or not DoesEntityExist(entity) then
            dead[#dead + 1] = netId
        end
    end
    for index = 1, #dead do decisions[dead[index]] = nil end
    return #dead
end

---@return integer
function Spawn.count()
    local total = 0
    for _ in pairs(decisions) do total = total + 1 end
    return total
end

return Spawn
