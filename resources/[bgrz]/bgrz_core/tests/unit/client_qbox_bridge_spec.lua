local T = dofile('tests/testlib.lua')

BGRZ = {}
LocalPlayer = { state = { isLoggedIn = true } }
QBX = {
    PlayerData = {
        job = {
            name = 'police',
            label = 'LSPD',
            grade = { level = 2, name = 'Officer' },
            onduty = true,
        },
        gang = {
            name = 'none',
            label = 'Sem gang',
            grade = { level = 0, name = 'Civil' },
            isboss = false,
        },
        metadata = {},
    },
}

exports = T.exports({
    qbx_core = { Notify = function() end },
})

local handlers
handlers, RegisterNetEvent = T.events()

local emitted = {}
TriggerEvent = function(name, payload)
    emitted[#emitted + 1] = { name = name, payload = payload }
end

dofile('client/qbox_bridge.lua')

local function lastOf(name)
    for index = #emitted, 1, -1 do
        if emitted[index].name == name then return emitted[index] end
    end
end

-- O evento pode chegar assim que o resource carrega; a função local precisa já estar no escopo.
T.fire(handlers, 'QBCore:Client:OnJobUpdate')
local update = lastOf('bgrz_core:client:jobUpdated')
T.truthy(update, 'job update re-emitted')
T.equal(update.payload.name, 'police', 'job name normalized')
T.equal(update.payload.grade, 2, 'job grade normalized')
T.equal(update.payload.onDuty, true, 'job duty normalized')

-- O carregamento inicializa o estado usado para distinguir mudanças de job e gang.
T.fire(handlers, 'QBCore:Client:OnPlayerLoaded')
QBX.PlayerData.job = {
    name = 'unemployed',
    label = 'Civilian',
    grade = { level = 0, name = 'Freelancer' },
    onduty = false,
}
T.fire(handlers, 'qbx_core:client:onGroupUpdate')
update = lastOf('bgrz_core:client:jobUpdated')
T.equal(update.payload.name, 'unemployed', 'leaving a job re-emits the new job')

print('client_qbox_bridge_spec: ok')
