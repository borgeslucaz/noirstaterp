local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }

-- Personagem controlado pelo teste, como o Qbox entrega.
local playerData = {
    source = 5,
    job = { name = 'unemployed', label = 'Civil', grade = { level = 0, name = 'Civil' }, onduty = false },
    gang = { name = 'ballas', label = 'Ballas', grade = { level = 4, name = 'Chefe' }, isboss = true },
}

local qbx = {}
function qbx:GetPlayer() return { PlayerData = playerData } end

-- A gang não sai mais do PlayerData: o bridge pergunta ao provider configurado em
-- `Providers.gangs`. O stub responde o mesmo contrato que os consumidores já esperavam.
currentGang = { name = 'ballas', label = 'Ballas', grade = 4, gradeName = 'Chefe',
    isBoss = true, bankAuth = true }

local gangProvider = {
    GetGang = function(_, source)
        if source ~= 5 then return nil end
        return currentGang
    end,
}

exports = T.exports({ qbx_core = qbx, noir_gangs = gangProvider })
GetResourceState = function() return 'started' end
GetCurrentResourceName = function() return 'bgrz_core' end

local emitted = {}
TriggerEvent = function(name, source, payload)
    emitted[#emitted + 1] = { name = name, source = source, payload = payload }
end

local handlers
handlers, AddEventHandler = T.events()
local netHandlers
netHandlers, RegisterNetEvent = T.events()

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')

local function lastOf(name)
    for index = #emitted, 1, -1 do
        if emitted[index].name == name then return emitted[index] end
    end
    return nil
end

local function countOf(name)
    local total = 0
    for index = 1, #emitted do
        if emitted[index].name == name then total = total + 1 end
    end
    return total
end

-- Leitura normalizada -----------------------------------------------------------------

local gang = BGRZ.GetGang(5)
T.equal(gang.name, 'ballas', 'gang name normalized')
T.equal(gang.grade, 4, 'gang grade flattened to the level')
T.equal(gang.gradeName, 'Chefe', 'gang grade name kept')
T.equal(gang.isBoss, true, 'boss flag normalized')

-- Baseline no load ---------------------------------------------------------------------

source = 5 -- no FXServer é global dentro do handler de net event
T.fire(netHandlers, 'QBCore:Server:OnPlayerLoaded')
T.equal(lastOf('bgrz_core:server:playerLoaded') ~= nil, true, 'player loaded re-emitted')

-- Sair da gang dispara apenas onGroupUpdate no Qbox -------------------------------------

local before = countOf('bgrz_core:server:gangUpdated')
-- Sair da gang é uma mudança NO PROVIDER, não no PlayerData -- é lá que a gang mora.
currentGang = { name = 'none', label = 'Sem gang', grade = 0, gradeName = 'Civil', isBoss = false }
T.fire(handlers, 'qbx_core:server:onGroupUpdate', 5, 'ballas')

T.equal(countOf('bgrz_core:server:gangUpdated'), before + 1, 'leaving a gang re-emits the update')
local update = lastOf('bgrz_core:server:gangUpdated')
T.equal(update.source, 5, 'update carries the source')
T.equal(update.payload.name, 'none', 'update carries the current gang')
T.equal(update.payload.grade, 0, 'grade reset with the gang')

-- Um grupo que não mexeu na gang não deve reemitir ----------------------------------------

before = countOf('bgrz_core:server:gangUpdated')
T.fire(handlers, 'qbx_core:server:onGroupUpdate', 5, 'police')
T.equal(countOf('bgrz_core:server:gangUpdated'), before, 'a job-only group change stays quiet')

-- Entrar em outra gang ---------------------------------------------------------------------

currentGang = { name = 'vagos', label = 'Vagos', grade = 1, gradeName = 'Membro', isBoss = false }
T.fire(handlers, 'qbx_core:server:onGroupUpdate', 5, 'vagos')
T.equal(lastOf('bgrz_core:server:gangUpdated').payload.name, 'vagos', 'joining a gang re-emits')

-- Só a promoção também conta ------------------------------------------------------------------

before = countOf('bgrz_core:server:gangUpdated')
currentGang = { name = 'vagos', label = 'Vagos', grade = 3, gradeName = 'Tenente', isBoss = false }
T.fire(handlers, 'qbx_core:server:onGroupUpdate', 5, 'vagos')
T.equal(countOf('bgrz_core:server:gangUpdated'), before + 1, 'a promotion re-emits')
T.equal(lastOf('bgrz_core:server:gangUpdated').payload.grade, 3, 'new grade carried')

print('group_update_spec: ok')
