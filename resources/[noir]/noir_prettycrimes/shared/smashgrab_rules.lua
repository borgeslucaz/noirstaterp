---Smash & Grab — formas e nomes compartilhados por client e servidor.
---
---Aqui mora só o que os dois lados precisam enxergar igual para DESENHAR e para
---CONFERIR o objeto: as listas ordenadas de prop e assento, a normalização da placa
---e o cálculo de onde o prop gruda no carro.
---
---O que NÃO está aqui, de propósito: a decisão de qual carro tem objeto. Essa é
---exclusivamente do servidor (`server/crimes/smashgrab/spawn.lua`). O client não
---tem como calculá-la nem adivinhá-la — ele pergunta, e só recebe resposta sobre
---veículos que estão perto dele de verdade.

local Utils = require 'shared.utils'
local CrimeConfig = require 'config.smashgrab'

local Rules = {}

---Listas ordenadas. A ordem importa para o sorteio ponderado do servidor ser
---estável entre reinícios de sessão de leitura de config.
local function orderedEntries(source)
    local keys = Utils.sortedKeys(source)
    local entries = {}
    for index = 1, #keys do
        local key = keys[index]
        local entry = {}
        for field, value in pairs(source[key]) do entry[field] = value end
        entry.key = key
        entries[index] = entry
    end
    return entries
end

Rules.props = orderedEntries(CrimeConfig.props)
Rules.seats = orderedEntries(CrimeConfig.seats)

---@type table<string, table>
Rules.propByKey = {}
for index = 1, #Rules.props do Rules.propByKey[Rules.props[index].key] = Rules.props[index] end

---@type table<string, table>
Rules.seatByKey = {}
for index = 1, #Rules.seats do Rules.seatByKey[Rules.seats[index].key] = Rules.seats[index] end

---Normaliza a placa. Vem com espaços de preenchimento do jogo, e os dois lados
---precisam chegar ao mesmo texto — o servidor a usa para perceber que um handle de
---netId foi reciclado em outro carro.
---@param plate any
---@return string?
function Rules.normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    local trimmed = plate:gsub('%s+', ''):upper()
    if trimmed == '' then return nil end
    return trimmed
end

---Monta o par prop/assento a partir das chaves que o servidor mandou.
---Chave desconhecida devolve nil: o client não inventa objeto.
---@param propKey any
---@param seatKey any
---@return table? loot { propKey, seatKey, prop, seat }
function Rules.compose(propKey, seatKey)
    if type(propKey) ~= 'string' or type(seatKey) ~= 'string' then return nil end
    local prop, seat = Rules.propByKey[propKey], Rules.seatByKey[seatKey]
    if not prop or not seat then return nil end
    return { propKey = propKey, seatKey = seatKey, prop = prop, seat = seat }
end

---Offset final do prop: o da posição (ou o override do modelo) somado ao ajuste do
---próprio prop. Geometria pura, sem estado.
---@param loot table
---@param modelName string? nome do modelo, para procurar override
---@return vector3 offset
---@return vector3 rotation
function Rules.attachmentFor(loot, modelName)
    local seatOffset, seatRotation = loot.seat.offset, loot.seat.rotation

    local override = modelName and CrimeConfig.vehicleOffsets[modelName]
    local seatOverride = override and override[loot.seatKey]
    if seatOverride then
        seatOffset = seatOverride.offset or seatOffset
        seatRotation = seatOverride.rotation or seatRotation
    end

    local propOffset = loot.prop.offset or vec3(0.0, 0.0, 0.0)
    local propRotation = loot.prop.rotation or vec3(0.0, 0.0, 0.0)

    return seatOffset + propOffset, seatRotation + propRotation
end

return Rules
