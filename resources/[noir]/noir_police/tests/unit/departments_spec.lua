-- Regras de departamento e permissão: quem é polícia, grade por ação, subunidade e frota.

local T = dofile('tests/testlib.lua')
T.natives()
require = T.require()

local Departments = require 'shared.departments'

local police = { name = 'police', type = 'leo', grade = 0, onDuty = true }
local offDuty = { name = 'police', type = 'leo', grade = 4, onDuty = false }
local sheriff = { name = 'bcso', type = 'leo', grade = 3, onDuty = true }
local medic = { name = 'ambulance', type = 'ems', grade = 3, onDuty = true }
local fakeCop = { name = 'mechanic', type = 'leo', grade = 4, onDuty = true }

T.truthy(Departments.isPolice(police), 'police é polícia')
T.truthy(Departments.isPolice(sheriff), 'bcso é polícia')
T.falsy(Departments.isPolice(medic), 'ems não é polícia')
T.falsy(Departments.isPolice(fakeCop), 'job leo fora de departments não é polícia')
T.falsy(Departments.isPolice(nil), 'sem job não é polícia')

T.truthy(Departments.isOnDutyPolice(police), 'em serviço')
T.falsy(Departments.isOnDutyPolice(offDuty), 'fora de serviço')
T.truthy(Departments.isOnDutyEms(medic), 'ems em serviço')

-- Grade por ação
T.truthy(Departments.can(police, 'fine'), 'multa com grade 0')
T.falsy(Departments.can(police, 'license'), 'licença exige grade 2')
T.truthy(Departments.can(sheriff, 'license'), 'grade 3 concede licença')
T.falsy(Departments.can(offDuty, 'fine'), 'fora de serviço não multa')
T.truthy(Departments.can(police), 'sem ação: basta estar em serviço')

-- Subunidade
T.falsy(Departments.inSubunit(police, nil, 'swat'), 'grade 0 não é SWAT')
T.truthy(Departments.inSubunit(sheriff, nil, 'swat'), 'grade 3 é SWAT')
T.falsy(Departments.inSubunit(medic, nil, 'k9'), 'ems nunca é subunidade')
T.falsy(Departments.inSubunit(police, nil, 'inexistente'), 'subunidade desconhecida')

-- Frota
T.truthy(Departments.fleetAllows({ grade = 0, departments = { 'police' } }, police), 'viatura do departamento')
T.falsy(Departments.fleetAllows({ grade = 0, departments = { 'bcso' } }, police), 'viatura de outro departamento')
T.falsy(Departments.fleetAllows({ grade = 2 }, police), 'grade insuficiente')
T.truthy(Departments.fleetAllows({ grade = 1 }, sheriff), 'sem departamentos: todos')

-- Estação
T.truthy(Departments.stationServes({ departments = { 'police', 'sasp' } }, 'sasp'), 'estação atende sasp')
T.falsy(Departments.stationServes({ departments = { 'police' } }, 'bcso'), 'estação não atende bcso')

local names = Departments.jobNames()
T.equal(#names, 3, 'três departamentos')
T.equal(names[1], 'bcso', 'ordem estável')

print('departments_spec: ok')
