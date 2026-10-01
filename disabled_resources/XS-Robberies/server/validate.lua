Validate = {}

local function issue(list, level, message, stageId)
    list[#list + 1] = { level = level, message = message, stage = stageId }
end

local function hasCycle(stages)
    local byId, state = {}, {}
    for _, s in ipairs(stages) do byId[s.id] = s end

    local function visit(id)
        if state[id] == 'done' then return false end
        if state[id] == 'open' then return true end

        state[id] = 'open'
        for _, dep in ipairs(byId[id] and byId[id].requires or {}) do
            if byId[dep] and visit(dep) then return true end
        end
        state[id] = 'done'
        return false
    end

    for _, s in ipairs(stages) do
        if visit(s.id) then return true, s.id end
    end
    return false
end

local function reachable(stages)
    local byId, seen = {}, {}
    for _, s in ipairs(stages) do byId[s.id] = s end

    local changed = true
    while changed do
        changed = false
        for _, s in ipairs(stages) do
            if not seen[s.id] then
                local ok = true
                for _, dep in ipairs(s.requires or {}) do
                    if not seen[dep] then ok = false break end
                end
                if ok then seen[s.id] = true changed = true end
            end
        end
    end
    return seen
end

local LOOT_STAGES = { register = true, safe = true, container = true }

function Validate.Robbery(def)
    local issues = {}

    if not def.name or def.name == '' then
        issue(issues, 'error', 'Este roubo não tem nome.')
    end

    local all = def.stages or {}
    if #all == 0 then
        issue(issues, 'error', 'Nenhuma etapa posicionada ainda.')
        return issues
    end

    local stages, switchedOff = {}, 0
    for _, s in ipairs(all) do
        if s.enabled == false then
            switchedOff = switchedOff + 1
        else
            stages[#stages + 1] = s
        end
    end

    if #stages == 0 then
        issue(issues, 'error', 'Todas as etapas estão desligadas, então não há nada para roubar.')
        return issues
    end

    if switchedOff > 0 then
        issue(issues, 'warn', ('%d %s e não vai aparecer no mundo.')
            :format(switchedOff, switchedOff == 1 and 'etapa está desligada' or 'etapas estão desligadas'))
    end

    local ids, escapes = {}, 0
    for _, s in ipairs(stages) do
        if ids[s.id] then
            issue(issues, 'error', ('Duas etapas usam o mesmo id "%s".'):format(s.id), s.id)
        end
        ids[s.id] = true

        if not Stages.Get(s.type) then
            issue(issues, 'error', ('Tipo de etapa desconhecido "%s".'):format(tostring(s.type)), s.id)
        end

        if s.type == 'escape' then escapes = escapes + 1 end

        if not s.coords then
            issue(issues, 'error', ('%s ainda não foi posicionada no mundo.'):format(s.label or s.id), s.id)
        end
    end

    if escapes == 0 then
        issue(issues, 'warn',
            'Sem zona de fuga. O assalto termina assim que a última etapa obrigatória é concluída e paga na hora. Serve para um caixa eletrônico, não para um banco.')
    end

    for _, s in ipairs(stages) do
        for _, dep in ipairs(s.requires or {}) do
            if not ids[dep] then
                issue(issues, 'error',
                    ('%s depende de uma etapa que não existe mais.'):format(s.label or s.id), s.id)
            end
        end

        local opts = s.opts or {}
        if opts.codeFrom and opts.codeFrom ~= '' and not ids[opts.codeFrom] then
            issue(issues, 'error', ('%s lê o código de uma etapa que não existe mais.')
                :format(s.label or s.id), s.id)
        end
        if s.type == 'keypad' then
            if not opts.codeFrom or opts.codeFrom == '' then
                issue(issues, 'error', ('%s não tem etapa de onde tirar o código.')
                    :format(s.label or s.id), s.id)
            else
                local source
                for _, other in ipairs(stages) do
                    if other.id == opts.codeFrom then source = other break end
                end
                if source and (tonumber((source.opts or {}).revealCode) or 0) <= 0 then
                    issue(issues, 'error', ('%s lê o código de %s, que nunca revela um.')
                        :format(s.label or s.id, source.label or source.id), s.id)
                end
            end
        end

        if s.type == 'doorlock' then
            if not opts.doorId or opts.doorId == '' then
                issue(issues, 'error', ('%s não tem id de porta, então nunca vai abrir nada.')
                    :format(s.label or s.id), s.id)
            elseif not Doors.Available() then
                issue(issues, 'warn', ('%s precisa de um resource de portas, e nenhum está rodando.')
                    :format(s.label or s.id), s.id)
            end
        end

        if s.type == 'guard' then
            if not opts.weapon or opts.weapon == '' then
                issue(issues, 'warn', ('%s é um segurança armado sem arma.')
                    :format(s.label or s.id), s.id)
            end
        end

        if s.type == 'twoman' and (not opts.pairWith or opts.pairWith == '') then
            issue(issues, 'error', ('%s precisa de um segundo ponto para formar a dupla.')
                :format(s.label or s.id), s.id)
        end

        if opts.pairWith and opts.pairWith ~= '' and not ids[opts.pairWith] then
            issue(issues, 'error', ('%s está pareada com uma etapa que não existe mais.')
                :format(s.label or s.id), s.id)
        end

        if opts.requiredItem and opts.requiredItem ~= '' and not Inv.Exists(opts.requiredItem) then
            issue(issues, 'warn', ('%s exige "%s", que não corresponde a nenhum item do inventário.')
                :format(s.label or s.id, opts.requiredItem), s.id)
        end

        if LOOT_STAGES[s.type] then
            local reward = Runs.NormalisePayout(s.payout)
            local emptyCash = not reward.cash or (reward.cash.max or 0) <= 0
            local emptyItems = #(reward.items or {}) == 0
            local emptyLoot = not reward.lootTable or reward.lootTable == ''

            if emptyCash and emptyItems and emptyLoot then
                issue(issues, 'warn', ('%s não paga nada.'):format(s.label or s.id), s.id)
            end

            if reward.lootTable and reward.lootTable ~= '' and not Store.loot[reward.lootTable] then
                issue(issues, 'error', ('%s usa uma tabela de saque que não existe mais.')
                    :format(s.label or s.id), s.id)
            end

            for _, entry in ipairs(reward.items or {}) do
                if entry.item and entry.item ~= '' and not Inv.Exists(entry.item) then
                    issue(issues, 'warn', ('%s paga "%s", que não corresponde a nenhum item do inventário.')
                        :format(s.label or s.id, entry.item), s.id)
                end
            end
        end
    end

    local cycle, at = hasCycle(stages)
    if cycle then
        issue(issues, 'error', 'Os requisitos das etapas formam um ciclo.', at)
    else
        local seen = reachable(stages)
        for _, s in ipairs(stages) do
            if not seen[s.id] then
                issue(issues, 'error', ('%s nunca pode ser alcançada.'):format(s.label or s.id), s.id)
            end
        end
    end

    local gates = def.gates or {}
    local slots = GetConvarInt('sv_maxclients', 48)
    if (gates.policeRequired or 0) > slots then
        issue(issues, 'warn', ('Polícia exigida (%d) é maior do que o servidor comporta (%d).')
            :format(gates.policeRequired, slots))
    end
    if (gates.minCrew or 1) > (gates.maxCrew or 1) then
        issue(issues, 'error', 'A equipe mínima é maior que a equipe máxima.')
    end

    return issues
end

function Validate.Blocking(issues)
    for _, i in ipairs(issues) do
        if i.level == 'error' then return true end
    end
    return false
end
