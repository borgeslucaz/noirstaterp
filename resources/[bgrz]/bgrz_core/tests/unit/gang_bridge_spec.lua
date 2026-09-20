local T = dofile('tests/testlib.lua')

BGRZ = {}
BGRZConfig = { Providers = {} }

local gangs = {
    none = { label = 'Sem gang', grades = { [0] = { name = 'Sem gang' } } },
    ballas = { label = 'Ballas', grades = {
        [0] = { name = 'Novato' }, [2] = { name = 'Tenente' }, [4] = { name = 'Chefe', isboss = true } } },
    vagos = { label = 'Vagos', grades = { [0] = { name = 'Membro' } } },
}

local online = {
    ONLINE1 = { PlayerData = { source = 7, citizenid = 'ONLINE1', gangs = { ballas = 4 },
        charinfo = { firstname = 'Ana', lastname = 'Chefe' } } },
}

local offlineRows = {
    OFFLINE1 = { citizenid = 'OFFLINE1', charinfo = '{"firstname":"Beto","lastname":"Sumido"}' },
    OFFLINE2 = { citizenid = 'OFFLINE2', charinfo = '{"firstname":"Caio","lastname":"Ausente"}' },
}

local groupRows = {
    { citizenid = 'ONLINE1', grade = 4 },
    { citizenid = 'OFFLINE1', grade = '2' },
}

local addCalls, primaryCalls, removeCalls, queryCount = {}, {}, {}, 0

local created = { gangs = nil, commitToFile = nil }
local commits = 0

local qbx = {}

---Modela o provider de verdade: `CreateGangs` ATRIBUI a entrada (a escada some), e só
---depois grava. Sem isso o teste não enxergaria a diferença entre ele e o upsert.
function qbx:CreateGangs(payload, commitToFile)
    created.gangs, created.commitToFile = payload, commitToFile
    for name, gang in pairs(payload) do gangs[name] = gang end
    if commitToFile then commits = commits + 1 end
end

function qbx:UpsertGangData(name, data, commitToFile)
    if gangs[name] then
        gangs[name].label = data.label
    else
        gangs[name] = { label = data.label, grades = {} }
    end
    if commitToFile then commits = commits + 1 end
end
function qbx:GetGang(name) return gangs[name] end
function qbx:GetGangs() return gangs end
function qbx:GetGroupMembers() return groupRows end
function qbx:GetPlayerByCitizenId(citizenId) return online[citizenId] end
function qbx:GetOfflinePlayer(citizenId)
    if not offlineRows[citizenId] then return nil end
    return { Offline = true, PlayerData = { citizenid = citizenId, gangs = { vagos = 0 } } }
end
function qbx:AddPlayerToGang(citizenId, gangName, grade)
    addCalls[#addCalls + 1] = { citizenId, gangName, grade }
    return true
end
function qbx:SetPlayerPrimaryGang(citizenId, gangName)
    primaryCalls[#primaryCalls + 1] = { citizenId, gangName }
    return true
end
function qbx:RemovePlayerFromGang(citizenId, gangName)
    removeCalls[#removeCalls + 1] = { citizenId, gangName }
    return true
end

exports = T.exports({ qbx_core = qbx })
GetResourceState = function() return 'started' end
GetCurrentResourceName = function() return 'bgrz_core' end
TriggerEvent = function() end
TriggerClientEvent = function() end
local _, AddEventHandlerStub = T.events()
AddEventHandler = AddEventHandlerStub
local __, RegisterNetEventStub = T.events()
RegisterNetEvent = RegisterNetEventStub

json = { decode = function(raw)
    local first, last = raw:match('"firstname":"(%w+)","lastname":"(%w+)"')
    return { firstname = first, lastname = last }
end }

MySQL = { query = { await = function(_, values)
    queryCount = queryCount + 1
    local rows = {}
    for i = 1, #values[1] do
        local row = offlineRows[values[1][i]]
        if row then rows[#rows + 1] = row end
    end
    return rows
end } }

dofile('shared/provider.lua')
dofile('server/qbox_bridge.lua')

-- GetGangInfo ---------------------------------------------------------------------------
local info = BGRZ.GetGangInfo('ballas')
T.equal(info.label, 'Ballas', 'label normalizado')
T.equal(info.topGrade, 4, 'topGrade é o maior cargo configurado, não a contagem')
T.equal(info.grades[4].name, 'Chefe', 'nome do cargo preservado')
T.equal(info.grades[4].isBoss, true, 'isboss vira isBoss')
T.equal(info.grades[2].isBoss, false, 'cargo sem isboss vira false explícito')
T.falsy(BGRZ.GetGangInfo('none'), 'a gang vazia não é uma gang')
T.falsy(BGRZ.GetGangInfo('inexistente'), 'gang desconhecida retorna nil')

-- Gang de um cargo só: topGrade 0, que é o caso que quebraria uma sucessão ingênua.
T.equal(BGRZ.GetGangInfo('vagos').topGrade, 0, 'gang de cargo único tem topGrade 0')

-- GetGangList ----------------------------------------------------------------------------
local list = BGRZ.GetGangList()
T.equal(#list, 2, 'a gang vazia fica de fora da lista')
T.equal(list[1].label, 'Ballas', 'lista sai ordenada por label')

-- GetGangMembers -------------------------------------------------------------------------
local members = BGRZ.GetGangMembers('ballas')
T.equal(#members, 2, 'todos os membros persistidos entram')
T.equal(members[2].citizenId, 'OFFLINE1', 'citizenid renomeado para citizenId')
T.equal(members[2].grade, 2, 'grade em texto vira número')

-- GetCharacterNames ------------------------------------------------------------------------
queryCount = 0
local names = BGRZ.GetCharacterNames({ 'ONLINE1', 'OFFLINE1', 'OFFLINE2', 'OFFLINE1' })
T.equal(names.ONLINE1, 'Ana Chefe', 'quem está online sai da memória')
T.equal(names.OFFLINE1, 'Beto Sumido', 'quem está offline sai do banco')
T.equal(names.OFFLINE2, 'Caio Ausente', 'o lote cobre todo mundo')
T.equal(queryCount, 1, 'uma query só, por mais membros offline que existam')

queryCount = 0
BGRZ.GetCharacterNames({ 'ONLINE1' })
T.equal(queryCount, 0, 'sem membro offline não há query')

-- GetCharacterGangs / GetCharacterSource ----------------------------------------------------
T.equal(BGRZ.GetCharacterGangs('ONLINE1').ballas, 4, 'gangs do personagem online')
T.equal(BGRZ.GetCharacterGangs('OFFLINE1').vagos, 0, 'gangs do personagem offline')
T.equal(next(BGRZ.GetCharacterGangs('DESCONHECIDO')), nil, 'personagem inexistente não tem gang')
T.equal(BGRZ.GetCharacterSource('ONLINE1'), 7, 'source de quem está online')
T.falsy(BGRZ.GetCharacterSource('OFFLINE1'), 'offline não tem source')

-- SetGangGrade ------------------------------------------------------------------------------
local ok, err = BGRZ.SetGangGrade('ONLINE1', 'ballas', 3)
T.falsy(ok, 'cargo que não existe na gang é recusado')
T.equal(err, 'invalid_grade', 'e o erro diz o porquê')
T.equal(#addCalls, 0, 'a recusa acontece antes de tocar no provider')

ok = BGRZ.SetGangGrade('ONLINE1', 'ballas', 2)
T.truthy(ok, 'cargo válido passa')
T.equal(#addCalls, 1, 'entrou na gang uma vez')
T.equal(#primaryCalls, 1, 'e a gang virou primária, senão o cargo novo não apareceria')

ok, err = BGRZ.SetGangGrade('ONLINE1', 'none', 0)
T.falsy(ok, 'ninguém entra na gang vazia')
T.equal(err, 'invalid_gang', 'com o erro certo')

-- RemoveFromGang -----------------------------------------------------------------------------
T.truthy(BGRZ.RemoveFromGang('ONLINE1', 'ballas'), 'remoção válida passa')
T.equal(#removeCalls, 1, 'o provider foi chamado uma vez')
T.falsy(BGRZ.RemoveFromGang('ONLINE1', 'none'), 'não dá para remover da gang vazia')

-- RegisterGangs -----------------------------------------------------------------------------
-- O provider guarda as gangs em memória; quem é dono da lista registra a cada start. Sem
-- isto, o login descarta a gang do personagem com um aviso e a pessoa entra sem gang.
local ok, err = BGRZ.RegisterGangs({ { name = 'nova', label = 'Nova Gang' }, { name = 'outra' } })
T.truthy(ok, 'lista válida registra')
T.equal(created.commitToFile, false, 'sem gravar no arquivo do provider: a verdade é de quem chamou')
T.equal(created.gangs.nova.label, 'Nova Gang', 'o rótulo vai junto')
T.equal(created.gangs.outra.label, 'outra', 'sem rótulo, o nome serve de rótulo')
T.truthy(created.gangs.nova.grades, 'a gang nasce com a tabela de cargos vazia')
T.falsy(next(created.gangs.nova.grades), 'e sem nenhum cargo: eles chegam por UpsertGangGrade')

created = { gangs = nil }
ok, err = BGRZ.RegisterGangs({ { name = 'none' } })
T.falsy(ok, 'a gang vazia do provider não é registrável')
T.equal(err, 'empty_list', 'e a lista vira vazia')
T.falsy(created.gangs, 'nada foi enviado ao provider')

T.falsy(BGRZ.RegisterGangs('nao é lista'), 'entrada inválida é recusada')

-- UpsertGangData e a diferença que ele existe para ter ------------------------------------
-- Renomear uma gang não pode custar a escada de cargos das outras. É a armadilha do
-- `CreateGangs`: ele atribui a entrada inteira, então uma lista com `grades = {}` zera todo
-- mundo. Um teste aqui porque o erro é silencioso: só aparece quando alguém tenta entrar.
gangs.comcargos = { label = 'Com Cargos', grades = { [0] = { name = 'Base' }, [1] = { name = 'Topo' } } }

T.truthy(BGRZ.UpsertGangData('comcargos', 'Renomeada'), 'renomear uma gang existente funciona')
T.equal(gangs.comcargos.label, 'Renomeada', 'o rótulo muda')
T.truthy(gangs.comcargos.grades[0], 'e os cargos continuam lá')
T.truthy(gangs.comcargos.grades[1], 'todos eles')

T.truthy(BGRZ.UpsertGangData('inexistente', 'Nova'), 'gang que não existe é criada')
T.falsy(next(gangs.inexistente.grades), 'nascendo sem cargo, que é o esperado')

T.falsy(BGRZ.UpsertGangData('none', 'X'), 'a gang vazia do provider não é renomeável')
T.falsy(BGRZ.UpsertGangData('comcargos', ''), 'rótulo vazio é recusado')

-- CommitGangsToFile grava sem mexer em nada.
local before = gangs.comcargos.label
commits = 0
T.truthy(BGRZ.CommitGangsToFile(), 'o commit responde')
T.equal(commits, 1, 'e gravou uma vez')
T.equal(gangs.comcargos.label, before, 'sem alterar o dicionário')
T.truthy(gangs.comcargos.grades[0], 'e sem encostar nos cargos')

print('gang_bridge_spec: ok')
