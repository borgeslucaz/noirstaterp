local function allowed(src)
    if src == 0 then return true end
    return Framework.IsAdmin and Framework.IsAdmin(src)
end

local function say(src, text)
    if src == 0 then
        print(('^5[robberies]^0 %s'):format(text))
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'robberies', text } })
        print(('^5[robberies]^0 %s'):format(text))
    end
end

RegisterCommand('robberylist', function(src)
    if not allowed(src) then return end

    local rows = MySQL.query.await('SELECT id, name, enabled, revision FROM xs_robberies') or {}

    say(src, '---- id | nome | ativo | equipe | polícia | revisão | locais ----')

    for _, row in ipairs(rows) do
        local def = Store.robberies[row.id]

        local sites, liveSites = 0, 0
        for _, loc in pairs(Store.locations) do
            if loc.robberyId == row.id then
                sites = sites + 1
                if loc.enabled then liveSites = liveSites + 1 end
            end
        end

        local g = (def and def.gates) or {}

        say(src, ('%-18s %-14s ativo=%-6s equipe=%s-%s polícia=%s rev=%-4s locais=%d(%d ligados)'):format(
            row.id, row.name,
            tostring(def and def.enabled),
            tostring(g.minCrew or 1), tostring(g.maxCrew or '-'),
            tostring(g.policeRequired or 0),
            tostring(row.revision), sites, liveSites))
    end

    say(src, ('%d roubos. Use /robberylive <id> para ativar um daqui.'):format(#rows))
end, false)

RegisterCommand('robberylive', function(src, args)
    if not allowed(src) then return end

    local id = args[1]
    if not id then
        say(src, 'Qual deles? /robberylive <id>. Use /robberylist para ver os ids.')
        return
    end

    local def = Store.robberies[id]
    if not def then
        say(src, ('Nenhum roubo com o id "%s".'):format(id))
        return
    end

    say(src, ('antes: memória=%s'):format(tostring(def.enabled)))

    def.enabled = true
    local ok, err = Store.Save(def, 'console')

    if not ok then
        say(src, ('^1Store.Save recusou: %s^0'):format(tostring(err)))
        return
    end

    local row = MySQL.single.await(
        'SELECT enabled, revision FROM xs_robberies WHERE id = ?', { id })

    if not row then
        say(src, '^1a linha sumiu depois de salvar^0')
        return
    end

    say(src, ('depois: memória=%s banco=%s revisão=%s'):format(
        tostring(Store.robberies[id].enabled), tostring(row.enabled), tostring(row.revision)))

    if row.enabled == true or row.enabled == 1 then
        say(src, '^2a gravação entrou. Recarregando e reenviando para todos.^0')
        Store.Load()
        SyncLocations()

        local reloaded = Store.robberies[id]
        say(src, ('após recarregar: memória=%s'):format(tostring(reloaded and reloaded.enabled)))
    else
        say(src, '^1a gravação NÃO entrou - o banco ainda diz que está desligado^0')
    end
end, false)
