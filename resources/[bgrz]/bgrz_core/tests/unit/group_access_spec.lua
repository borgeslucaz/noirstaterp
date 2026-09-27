local T = dofile('tests/testlib.lua')

-- GetJobList e HasGroupAccess: job primario vem do Qbox; gang vem do provider de gangs, nunca do
-- PlayerData (que o noir_gangs nao sincroniza mais).

BGRZ = {}
BGRZConfig = { Providers = {} }

local jobs = {
    police = { label = 'LSPD', grades = { [0] = { name = 'Recruit' }, [2] = { name = 'Sergeant' } } },
    taxi = { label = 'Taxi', grades = { ['0'] = { name = 'Motorista' } } },
}

local players = {
    [1] = { PlayerData = { citizenid = 'COP', job = { name = 'police', grade = { level = 2 }, onduty = false },
        gang = { name = 'vagos', grade = { level = 3 } } } },
    [2] = { PlayerData = { citizenid = 'BALLA', job = { name = 'unemployed', grade = { level = 0 } } } },
    [3] = { PlayerData = { citizenid = 'NOVATO', job = { name = 'police', grade = { level = 0 } } } },
}

local qbx = {}
function qbx:GetJobs() return jobs end
function qbx:GetPlayer(source) return players[source] end

local gangProvider = {
    GetCitizenGang = function(_, citizenId)
        if citizenId == 'BALLA' then return { name = 'ballas', grade = 2 } end
        return nil
    end,
}

exports = T.exports({ qbx_core = qbx, noir_gangs = gangProvider })
GetResourceState = function() return 'started' end
GetCurrentResourceName = function() return 'bgrz_core' end
TriggerEvent = function() end
TriggerClientEvent = function() end
local _, AddEventHandlerStub = T.events()
AddEventHandler = AddEventHandlerStub
local __, RegisterNetEventStub = T.events()
RegisterNetEvent = RegisterNetEventStub

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')

-- GetJobList ------------------------------------------------------------------------------
local list = BGRZ.GetJobList()
T.equal(#list, 2, 'todos os jobs entram')
T.equal(list[1].label, 'LSPD', 'lista sai ordenada por label')
T.equal(list[1].grades[2], 'Sergeant', 'cargos por nivel')
T.equal(list[2].grades[0], 'Motorista', 'nivel em texto vira numero')

-- HasGroupAccess --------------------------------------------------------------------------
T.truthy(BGRZ.HasGroupAccess(1, { police = 2 }), 'job com o cargo minimo passa')
T.truthy(BGRZ.HasGroupAccess(1, { police = 0 }), 'fora de servico tambem passa')
T.falsy(BGRZ.HasGroupAccess(3, { police = 2 }), 'cargo abaixo do minimo nao passa')
T.truthy(BGRZ.HasGroupAccess(2, { ballas = 2 }), 'gang do provider passa')
T.falsy(BGRZ.HasGroupAccess(2, { ballas = 3 }), 'gang com cargo abaixo do minimo nao passa')
T.falsy(BGRZ.HasGroupAccess(1, { vagos = 0 }), 'gang velha do PlayerData e ignorada')
T.falsy(BGRZ.HasGroupAccess(2, { police = 0 }), 'sem job nem gang da lista, nao passa')
T.falsy(BGRZ.HasGroupAccess(9, { police = 0 }), 'jogador inexistente nao passa')
T.falsy(BGRZ.HasGroupAccess(1, nil), 'lista invalida nao passa')

print('group_access_spec: ok')
