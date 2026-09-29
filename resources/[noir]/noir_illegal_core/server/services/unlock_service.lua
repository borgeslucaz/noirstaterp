local Service = {}
NoirIllegal.Services.Unlock = Service

local SCOPES = { player = true, organization = true }

function Service.toMap(rows)
    local result = {}
    for i = 1, #rows do
        if rows[i].state == 'granted' then result[rows[i].unlock_key] = true end
    end
    return result
end

local function stateMap(rows)
    local result = {}
    for i = 1, #(rows or {}) do result[rows[i].unlock_key] = rows[i].state end
    return result
end

---Monta o candidato de cada escopo com os dados DAQUELE escopo. Unlock de gang lê a reputação
---e os unlocks da gang; ler os do jogador que fez a venda fazia `contact_coke` exigir que o
---vendedor, e não a gang, tivesse `contact_meth`.
local function candidateFor(scope, subject)
    local levels = NoirIllegal.Services.Level.all(subject.reputations)
    if scope == 'organization' then
        return {
            reputations = subject.reputations,
            levels = levels,
            organization = { id = subject.id },
            unlocks = subject.unlocks,
        }
    end
    return {
        citizenId = subject.id,
        reputations = subject.reputations,
        levels = levels,
        heat = subject.heat,
        organization = subject.organization,
        unlocks = subject.unlocks,
    }
end

---Concede os unlocks automáticos que passaram a ser devidos.
---
---`subjects.player` e `subjects.organization` são opcionais e trazem `id`, `reputations` e
---`unlockRows` (as linhas travadas na transação de quem chama); o do jogador traz também `heat`
---e `organization`. Cada escopo só olha o próprio sujeito.
---
---Repete até não conceder mais nada: `contact_coke` depende de `contact_meth`, e uma gang que
---cruza os dois limiares de uma vez (ajuste de admin, reputação acumulada antes deste unlock
---existir) recebe os dois na mesma atividade, qualquer que seja a ordem do `pairs`.
---
---Unlock revogado não volta sozinho: a revogação é decisão de admin, e ela só se desfaz por
---outro `GrantUnlock`.
function Service.evaluateAutomatic(subjects, query, actor)
    local granted = {}
    local prepared = {}
    for scope in pairs(SCOPES) do
        local subject = subjects[scope]
        if subject and subject.id then
            prepared[scope] = {
                subject = subject,
                states = stateMap(subject.unlockRows),
            }
            subject.unlocks = Service.toMap(subject.unlockRows or {})
        end
    end

    local changed = true
    while changed do
        changed = false
        for unlockKey, definition in pairs(NoirIllegal.Unlocks) do
            local entry = definition.automatic and prepared[definition.scope]
            if entry and entry.states[unlockKey] == nil then
                local candidate = candidateFor(definition.scope, entry.subject)
                if NoirIllegal.Services.Eligibility.unlockRequirements(definition, candidate) then
                    NoirIllegal.Repositories.Unlock.upsert(
                        definition.scope, entry.subject.id, unlockKey, 'granted', 'automatic',
                        actor.actorId, 'requirements_met', {}, query)
                    entry.states[unlockKey] = 'granted'
                    entry.subject.unlocks[unlockKey] = true
                    granted[#granted + 1] = {
                        key = unlockKey,
                        scope = definition.scope,
                        subjectId = entry.subject.id,
                    }
                    changed = true
                end
            end
        end
    end
    return granted
end

function Service.validateConfiguration()
    for unlockKey, definition in pairs(NoirIllegal.Unlocks) do
        assert(NoirIllegal.Validators.string(unlockKey, 1, 96), 'Invalid unlock key')
        assert(SCOPES[definition.scope], ('Unlock %s has an invalid scope'):format(unlockKey))
        local requirements = definition.requirements or {}
        for category in pairs(requirements.reputation or {}) do
            assert(NoirIllegal.Validators.category(category),
                ('Unlock %s requires unknown category %s'):format(unlockKey, category))
        end
        for category in pairs(requirements.minLevel or {}) do
            assert(NoirIllegal.Validators.category(category),
                ('Unlock %s requires unknown category %s'):format(unlockKey, category))
        end
        if definition.scope == 'organization' then
            assert(requirements.maxHeat == nil,
                ('Organization unlock %s cannot require maxHeat'):format(unlockKey))
            assert(requirements.organization == nil,
                ('Organization unlock %s cannot require organization'):format(unlockKey))
        end
        for i = 1, #(requirements.unlocks or {}) do
            local dependency = NoirIllegal.Unlocks[requirements.unlocks[i]]
            assert(dependency, ('Unlock %s requires unknown unlock %s'):format(
                unlockKey, tostring(requirements.unlocks[i])))
            assert(dependency.scope == definition.scope,
                ('Unlock %s requires %s from another scope'):format(unlockKey, requirements.unlocks[i]))
        end
    end
end
