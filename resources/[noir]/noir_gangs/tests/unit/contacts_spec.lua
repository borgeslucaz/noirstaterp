-- Contato do crime: quando o core libera um contato da gang, cada membro recebe um SMS anônimo.

local T = dofile('tests/testlib.lua')

local handlers, invoking, sent = {}, 'noir_illegal_core', {}
AddEventHandler = function(name, fn) handlers[name] = fn end
GetInvokingResource = function() return invoking end
lib = { print = { info = function() end, warn = function() end } }
-- Escada da ballas: 0 Recruit, 1 Enforcer, 2 Shot Caller, 3 Boss.
NoirGangs = {
    membersOf = function(gang)
        if gang ~= 'ballas' then return {} end
        return {
            { citizenId = 'BOSS', grade = 3 }, { citizenId = 'SHOT', grade = 2 },
            { citizenId = 'SHOT2', grade = 2 }, { citizenId = 'ENF', grade = 1 }, { citizenId = 'REC', grade = 0 },
        }
    end,
    topLevel = function() return 3 end,
    levelBelow = function(_, level) return level - 1 end,
}
exports = T.exports({ bgrz_core = { SendPhoneAnonymousMessage = function(_, citizenId, body)
    sent[#sent + 1] = { citizenId = citizenId, body = body }
    if citizenId == 'NOSIM' then return false, 'no_sim' end
    return true, 1
end } })

dofile('server/contacts.lua')
local unlock = handlers['noir_illegal_core:server:unlockGranted']

unlock({ scope = 'organization', subjectId = 'ballas', unlockKey = 'contact_meth' })
T.equal(#sent, 3, 'only the leader and the sub-leaders get the message')
T.equal(sent[1].citizenId, 'BOSS', 'the leader')
T.equal(sent[2].citizenId, 'SHOT', 'the sub-leader')
for _, message in ipairs(sent) do
    T.truthy(message.citizenId ~= 'ENF' and message.citizenId ~= 'REC', 'lower ranks get nothing')
end
T.truthy(sent[1].body:find('química', 1, true), 'meth contact text')

sent = {}
unlock({ scope = 'organization', subjectId = 'ballas', unlockKey = 'contact_coke' })
T.truthy(sent[1].body:find('Produto puro', 1, true), 'coke contact text')

sent = {}
unlock({ scope = 'player', subjectId = 'A1', unlockKey = 'contact_meth' })
unlock({ scope = 'organization', subjectId = 'ballas', unlockKey = 'dealer_contact' })
T.equal(#sent, 0, 'player unlocks and unknown keys send nothing')

invoking = 'some_cheat'
unlock({ scope = 'organization', subjectId = 'ballas', unlockKey = 'contact_meth' })
T.equal(#sent, 0, 'only the core can announce an unlock')

print('contacts_spec: ok')
