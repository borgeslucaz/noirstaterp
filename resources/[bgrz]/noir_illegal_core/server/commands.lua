local function respond(source, payload)
    local message = type(payload) == 'string' and payload or json.encode(payload)
    if source == 0 then
        print(('[noir_illegal_core] %s'):format(message))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 180, 180, 255 },
            args = { 'noir_illegal_core', message },
        })
    end
end

local function authorized(source)
    return source == 0 or IsPlayerAceAllowed(source, NoirIllegal.Permissions.ace)
end

local function commandActor(source)
    if source == 0 then return { actorType = 'console', actorId = 'console' } end
    local identity = NoirIllegal.Bridges.Qbox.getIdentity(source)
    return identity and { actorType = 'player', actorId = identity.citizenId } or nil
end

local function commandSubject(kind, id)
    if kind == 'player' then return NoirIllegal.Validators.subject({
        type = 'player', citizenId = id,
    }) end
    if kind == 'organization' then return NoirIllegal.Validators.subject({
        type = 'organization', id = id,
    }) end
end

RegisterCommand('noirillegal', function(source, args)
    if not NoirIllegal.Config.Commands.enabled then return end
    if not authorized(source) then return respond(source, NoirIllegal.error('FORBIDDEN_CALLER')) end
    local actor = commandActor(source)
    if not actor then return respond(source, NoirIllegal.error('INVALID_SOURCE')) end

    local action = args[1]
    if action == 'profile' then
        local target = tonumber(args[2])
        local profile, profileError = NoirIllegal.Services.Profile.getBySource(target)
        return respond(source, profile or profileError)
    end

    if action == 'activity' then
        if not NoirIllegal.Config.Commands.developmentActivityCommand then
            return respond(source, 'Development activity command is disabled.')
        end
        local ok, result = NoirIllegal.Services.Activity.record(
            tonumber(args[2]), args[3], args[4], {}, 'noir_illegal_core')
        return respond(source, result or { ok = ok })
    end

    if action == 'grant' or action == 'revoke' then
        local subject = commandSubject(args[2], args[3])
        if not subject then return respond(source, NoirIllegal.error('INVALID_ARGUMENT')) end
        local reason = table.concat(args, ' ', 5)
        local ok, result = NoirIllegal.Services.Admin.setUnlock(
            subject, args[4], action == 'grant', reason, {}, actor)
        return respond(source, result or { ok = ok })
    end

    if action == 'rep' then
        local subject = commandSubject(args[2], args[3])
        if not subject then return respond(source, NoirIllegal.error('INVALID_ARGUMENT')) end
        local reason = table.concat(args, ' ', 7)
        local ok, result = NoirIllegal.Services.Admin.adjustReputation(
            subject, args[4], tonumber(args[5]), reason, args[6], actor)
        return respond(source, result or { ok = ok })
    end

    if action == 'heat' then
        local identity = NoirIllegal.Bridges.Qbox.getIdentity(tonumber(args[2]))
        if not identity then return respond(source, NoirIllegal.error('INVALID_SOURCE')) end
        local reason = table.concat(args, ' ', 6)
        local ok, result = NoirIllegal.Services.Admin.changeHeat(
            identity.citizenId, tonumber(args[4]), args[3], reason, args[5], actor)
        return respond(source, result or { ok = ok })
    end

    if action == 'cache' and args[3] == 'clear' then
        if args[2] == 'all' then
            NoirIllegal.Cache.invalidateAll()
        else
            local identity = NoirIllegal.Bridges.Qbox.getIdentity(tonumber(args[2]))
            if not identity then return respond(source, NoirIllegal.error('INVALID_SOURCE')) end
            NoirIllegal.Cache.invalidatePlayer(identity.citizenId)
        end
        return respond(source, { ok = true })
    end

    respond(source, 'Usage: /noirillegal <profile|activity|grant|revoke|rep|heat|cache> ...')
end, false)
