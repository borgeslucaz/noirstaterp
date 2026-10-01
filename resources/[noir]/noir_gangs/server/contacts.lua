---Contato do crime aparece para a gang. Quando o noir_illegal_core libera um contato de
---organização (`unlockGranted`, ex. `contact_meth` no nível 2 da reputação da gang), o líder e o
---sub-líder (os dois cargos mais altos da escada da gang) recebem um SMS anônimo no celular:
---número aleatório, sem nome, que não atende nem recebe resposta. Fica na conversa e chega mesmo
---para quem está offline (chips registrados).
---
---As mensagens ficam aqui, no servidor, e não no config compartilhado: ninguém precisa saber o
---texto do contato antes de a gang chegar lá.

local CONTACTS = {
    contact_meth = 'Andei ouvindo o nome de vocês na rua. Tenho química e preciso de gente que '
        .. 'segure o ponto. Quando for a hora, eu chamo. Não respondam este número.',
    contact_coke = 'O pessoal de cima reparou em vocês. Produto puro, direto da fonte, pra quem '
        .. 'prova que aguenta. Esperem o sinal. Este número não existe.',
}

local function sendTo(citizenId, body)
    local called, ok, result = pcall(function()
        return exports.bgrz_core:SendPhoneAnonymousMessage(citizenId, body)
    end)
    if not called or not ok then
        lib.print.warn(('[noir_gangs] contato não chegou a %s: %s'):format(citizenId, tostring(called and result or ok)))
        return false
    end
    return true
end

AddEventHandler('noir_illegal_core:server:unlockGranted', function(payload)
    if GetInvokingResource() ~= 'noir_illegal_core' or type(payload) ~= 'table' then return end
    if payload.scope ~= 'organization' or type(payload.subjectId) ~= 'string' then return end
    local body = CONTACTS[payload.unlockKey]
    if not body then return end

    -- Líder e sub-líder: o cargo do topo e o logo abaixo dele.
    local leader = NoirGangs.topLevel(payload.subjectId)
    local second = NoirGangs.levelBelow(payload.subjectId, leader)
    local reached, recipients = 0, 0
    for _, member in ipairs(NoirGangs.membersOf(payload.subjectId)) do
        if member.grade == leader or member.grade == second then
            recipients = recipients + 1
            if sendTo(member.citizenId, body) then reached = reached + 1 end
        end
    end
    lib.print.info(('[noir_gangs] %s liberou %s: SMS para %d de %d da liderança'):format(
        payload.subjectId, payload.unlockKey, reached, recipients))
end)
