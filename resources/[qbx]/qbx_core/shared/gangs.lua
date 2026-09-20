---Gang names must be lower case (top level table key)
---@type table<string, Gang>
return {
    ['cartel'] = {
        label = 'Cartel',
        grades = {
            [1] = { name = 'Sicario' },
            [2] = { name = 'Lugarteniente' },
            [3] = { name = 'Jefe de Plaza' },
            [4] = { name = 'Patrón', isboss = true, bankAuth = true },
            [0] = { name = 'Halcón' },
        },
    },
    ['families'] = {
        label = 'Families',
        grades = {
            [1] = { name = 'Enforcer' },
            [2] = { name = 'Shot Caller' },
            [3] = { name = 'Boss', isboss = true, bankAuth = true },
            [0] = { name = 'Recruit' },
        },
    },
    ['vagos'] = {
        label = 'Vagos',
        grades = {
            [1] = { name = 'Enforcer' },
            [2] = { name = 'Shot Caller' },
            [3] = { name = 'TESTE' },
            [4] = { name = 'Boss', isboss = true, bankAuth = true },
            [0] = { name = 'Recruit' },
        },
    },
    ['ballas'] = {
        label = 'Ballas',
        grades = {
            [1] = { name = 'Enforcer' },
            [2] = { name = 'Shot Caller' },
            [3] = { name = 'Boss', isboss = true, bankAuth = true },
            [0] = { name = 'Recruit' },
        },
    },
    ['none'] = {
        label = 'No Gang',
        grades = {
            [0] = { name = 'Unaffiliated' },
        },
    },
    ['lostmc'] = {
        label = 'The Lost MC',
        grades = {
            [1] = { name = 'Member' },
            [2] = { name = 'Road Captain' },
            [3] = { name = 'Sergeant at Arms' },
            [4] = { name = 'Vice President' },
            [5] = { name = 'President', isboss = true, bankAuth = true },
            [0] = { name = 'Prospect' },
        },
    },
    ['triads'] = {
        label = 'Triads',
        grades = {
            [1] = { name = 'Sicario' },
            [2] = { name = 'Lugarteniente' },
            [3] = { name = 'Jefe de Plaza' },
            [4] = { name = 'Patrón', isboss = true, bankAuth = true },
            [0] = { name = 'Halcón' },
        },
    },
}