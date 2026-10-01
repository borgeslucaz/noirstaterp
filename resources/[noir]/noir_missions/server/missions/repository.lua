---Definições de missão: rascunho, versão publicada, status e cooldown.
---
---Cada missão é um registro:
---    { id, status = 'draft'|'published'|'disabled', updatedAt, updatedBy,
---      publishedAt, draft = <definição>, published = <definição>? }
---
---O editor só mexe no `draft`. Publicar copia o rascunho salvo para `published`, e é dessa
---cópia que as execuções reais partem. Testar usa o rascunho. Toda execução leva uma cópia
---própria da definição (snapshot), então nem publicar nem editar mexe numa missão em curso.
local Utils = require 'shared.utils.core'
local Definition = require 'shared.types.definition'
local Storage = require 'server.persistence.storage'

local Repository = {}

---@type table<string, table>
local records = {}

local STATUSES = { draft = true, published = true, disabled = true }

local function now() return os.time() end

---@param record table
---@return table
local function summary(record)
    local def = record.draft or {}
    local _, errors = Definition.normalize(def)
    return {
        id = record.id,
        name = def.name or record.id,
        category = def.category,
        status = record.status,
        minPlayers = def.minPlayers,
        maxPlayers = def.maxPlayers,
        steps = #(def.steps or {}),
        errors = #errors,
        updatedAt = record.updatedAt,
        publishedAt = record.publishedAt,
        -- Rascunho salvo depois da última publicação: a execução real ainda roda a antiga.
        hasUnpublished = record.published ~= nil and record.publishedFrom ~= record.updatedAt,
    }
end

---@param record table
---@return table
function Repository.recordInfo(record)
    local info = summary(record)
    return {
        id = info.id, status = info.status, updatedAt = info.updatedAt,
        publishedAt = info.publishedAt, hasUnpublished = info.hasUnpublished,
    }
end

function Repository.loadAll()
    records = {}
    local ids = Storage.list()
    for index = 1, #ids do
        local id = ids[index]
        local record = Storage.load(id)
        if type(record) == 'table' and type(record.draft) == 'table' then
            record.id = id
            record.status = STATUSES[record.status] and record.status or 'draft'
            -- Normaliza ao carregar: arquivo editado à mão ou gerado por versão anterior do
            -- esquema entra no formato atual.
            record.draft = Definition.normalize(record.draft)
            record.draft.id = id
            if type(record.published) == 'table' then
                record.published = Definition.normalize(record.published)
                record.published.id = id
            end
            records[id] = record
        elseif record ~= nil then
            lib.print.warn(('[noir_missions] missão %s ignorada: arquivo sem rascunho'):format(id))
        end
    end
    lib.print.info(('[noir_missions] %d missões carregadas'):format(Utils.count(records)))
end

---@return table[]
function Repository.summaries()
    local list = {}
    for _, record in pairs(records) do list[#list + 1] = summary(record) end
    table.sort(list, function(a, b) return (a.name or a.id) < (b.name or b.id) end)
    return list
end

---@param id string
---@return table?
function Repository.get(id)
    return records[id]
end

---Definição que uma execução real usa: a publicada, e só se a missão está publicada.
---@param id string
---@return table? definition
---@return string? code
function Repository.publishedDefinition(id)
    local record = records[id]
    if not record then return nil, 'not_found' end
    if record.status ~= 'published' or not record.published then return nil, 'mission_disabled' end
    return Utils.deepCopy(record.published)
end

---Definição de teste: o rascunho salvo, se não tiver erro.
---@param id string
---@return table? definition
---@return string? code
---@return table? errors
function Repository.draftDefinition(id)
    local record = records[id]
    if not record then return nil, 'not_found' end
    local def, errors = Definition.normalize(record.draft)
    if #errors > 0 then return nil, 'invalid_definition', errors end
    def.id = id
    return def
end

---@param id string
---@param name string
---@param actor string
---@return table? record
---@return string? code
function Repository.create(id, name, actor)
    if not Utils.isId(id, 48) then return nil, 'invalid_id' end
    if records[id] then return nil, 'id_exists' end
    local record = {
        id = id, status = 'draft', updatedAt = now(), updatedBy = actor,
        draft = Definition.blank(id, Utils.cleanString(name, 64, id)),
    }
    if not Storage.save(id, record) then return nil, 'internal_error' end
    records[id] = record
    return record
end

---@param raw table definição vinda do editor
---@param actor string
---@return table? record
---@return string? code
---@return table errors
---@return table? definition
function Repository.saveDraft(raw, actor)
    local id = type(raw) == 'table' and raw.id or nil
    local record = records[id]
    if not record then return nil, 'not_found', {} end
    local def, errors = Definition.normalize(raw)
    def.id = id
    record.draft = def
    record.updatedAt = now()
    record.updatedBy = actor
    if not Storage.save(id, record) then return nil, 'internal_error', errors end
    return record, nil, errors, def
end

---@param id string
---@param status string
---@param actor string
---@return table? record
---@return string? code
---@return table? errors
function Repository.setStatus(id, status, actor)
    local record = records[id]
    if not record then return nil, 'not_found' end
    if not STATUSES[status] then return nil, 'invalid_id' end

    if status == 'published' then
        local def, errors = Definition.normalize(record.draft)
        if #errors > 0 then return nil, 'invalid_definition', errors end
        def.id = id
        record.published = def
        record.publishedAt = now()
        record.publishedFrom = record.updatedAt
    end
    record.status = status
    record.updatedBy = actor
    if not Storage.save(id, record) then return nil, 'internal_error' end
    return record
end

---@param id string
---@param newId string
---@param newName string
---@param actor string
---@return table? record
---@return string? code
function Repository.duplicate(id, newId, newName, actor)
    local source = records[id]
    if not source then return nil, 'not_found' end
    if not Utils.isId(newId, 48) then return nil, 'invalid_id' end
    if records[newId] then return nil, 'id_exists' end
    local def = Utils.deepCopy(source.draft)
    def.id = newId
    def.name = Utils.cleanString(newName, 64, def.name)
    local record = { id = newId, status = 'draft', updatedAt = now(), updatedBy = actor, draft = def }
    if not Storage.save(newId, record) then return nil, 'internal_error' end
    records[newId] = record
    return record
end

---@param id string
---@return boolean ok
---@return string? code
function Repository.remove(id)
    if not records[id] then return false, 'not_found' end
    if not Storage.remove(id) then return false, 'internal_error' end
    records[id] = nil
    return true
end

-- Cooldown -------------------------------------------------------------------------------
-- Em KVP do servidor: sobrevive a restart sem tabela própria. A chave é por missão; uma
-- execução de teste não grava cooldown.

local function cooldownKey(id) return ('noir_missions:cooldown:%s'):format(id) end

---@param id string
---@return integer seconds restantes
function Repository.cooldownRemaining(id)
    local untilAt = GetResourceKvpInt(cooldownKey(id))
    local remaining = (untilAt or 0) - now()
    return remaining > 0 and remaining or 0
end

---@param id string
---@param minutes number
function Repository.startCooldown(id, minutes)
    if not minutes or minutes <= 0 then return end
    SetResourceKvpInt(cooldownKey(id), now() + math.floor(minutes * 60))
end

---@param id string
function Repository.clearCooldown(id)
    DeleteResourceKvp(cooldownKey(id))
end

---Missões publicadas com início por NPC ou zona: o cliente precisa saber onde criar o NPC
---e onde fica a zona. Só posição, modelo e texto; nada de recompensa.
---@return table[]
function Repository.publicStarters()
    local list = {}
    for id, record in pairs(records) do
        local def = record.status == 'published' and record.published or nil
        local start = def and def.start
        if start and start.type == 'npc' and start.npcCoords then
            list[#list + 1] = {
                missionId = id, type = 'npc', model = start.npcModel, coords = start.npcCoords,
                scenario = start.npcScenario, label = start.npcLabel or 'Conversar',
            }
        elseif start and start.type == 'zone' and start.zoneCoords then
            list[#list + 1] = { missionId = id, type = 'zone', coords = start.zoneCoords, radius = start.zoneRadius }
        end
    end
    return list
end

return Repository
