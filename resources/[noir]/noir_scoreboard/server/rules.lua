---Regras puras do placar: sem export, sem native. É o que os testes exercitam.

local Rules = {}

---@param crimes { key: string, label: string, minimumPolice: integer }[]
---@return table<string, { key: string, label: string, minimumPolice: integer }> byKey
function Rules.index(crimes)
    local byKey = {}
    for index = 1, #crimes do
        local crime = crimes[index]
        assert(type(crime.key) == 'string' and crime.key ~= '', ('crimes[%d].key inválida'):format(index))
        assert(not byKey[crime.key], ('crimes[%d].key duplicada: %s'):format(index, crime.key))
        assert(type(crime.label) == 'string' and crime.label ~= '', ('crimes[%d].label inválida'):format(index))
        assert(math.type(crime.minimumPolice) == 'integer' and crime.minimumPolice >= 0,
            ('crimes[%d].minimumPolice precisa ser inteiro >= 0'):format(index))
        byKey[crime.key] = crime
    end
    return byKey
end

---@param crime { minimumPolice: integer }?
---@param police integer
---@return boolean ok
---@return string? code
function Rules.check(crime, police)
    if not crime then return false, 'unknown_crime' end
    if police < crime.minimumPolice then return false, 'not_enough_police' end
    return true
end

---Linhas da tabela, na ordem da config. Status: `busy` (em andamento), `open` ou `closed`.
---@param crimes { key: string, label: string, minimumPolice: integer }[]
---@param police integer
---@param busy table<string, boolean>
---@return { key: string, label: string, minimumPolice: integer, status: 'busy'|'open'|'closed' }[]
function Rules.table(crimes, police, busy)
    local rows = {}
    for index = 1, #crimes do
        local crime = crimes[index]
        local status
        if busy[crime.key] then
            status = 'busy'
        elseif police >= crime.minimumPolice then
            status = 'open'
        else
            status = 'closed'
        end
        rows[index] = { key = crime.key, label = crime.label, minimumPolice = crime.minimumPolice, status = status }
    end
    return rows
end

---@param gangs table<string, integer>?
---@return boolean
function Rules.isGangMember(gangs)
    return type(gangs) == 'table' and next(gangs) ~= nil
end

return Rules
