---Único ponto do servidor que conhece outro resource pelo nome. Framework e gang
---passam pelo `bgrz_core`; a contagem de polícia é do `noir_police`, dono do serviço.

local CORE = 'bgrz_core'
local POLICE = 'noir_police'

local Integrations = {}

---@param resource string
---@return boolean
local function ready(resource)
    return GetResourceState(resource) == 'started'
end

---@param label string
---@param fn function
---@return any
local function guarded(label, fn)
    local ok, result = pcall(fn)
    if not ok then
        lib.print.warn(('%s falhou: %s'):format(label, tostring(result)))
        return nil
    end
    return result
end

---Policiais em serviço. nil quando o noir_police não responde: quem pergunta trata
---como "não sei", e "não sei" não libera crime.
---@return integer?
function Integrations.policeCount()
    if not ready(POLICE) then return nil end
    local count = guarded('noir_police:GetCopCount', function() return exports[POLICE]:GetCopCount() end)
    return math.type(count) == 'integer' and count or nil
end

---Gangs do personagem, pelo provider de gangs do bridge (não pelo `players.gang` do Qbox).
---@param source integer
---@return table<string, integer>?
function Integrations.characterGangs(source)
    if not ready(CORE) then return nil end
    local citizenId = guarded('bgrz_core:GetCitizenId', function() return exports[CORE]:GetCitizenId(source) end)
    if type(citizenId) ~= 'string' then return nil end
    return guarded('bgrz_core:GetCharacterGangs', function() return exports[CORE]:GetCharacterGangs(citizenId) end)
end

---Admin em serviço: permissão de admin e opt-in ligado, como no qbx_scoreboard.
---@param source integer
---@return boolean
function Integrations.isAdminOnDuty(source)
    if not IsPlayerAceAllowed(tostring(source), 'admin') then return false end
    if not ready(CORE) then return false end
    return guarded('bgrz_core:GetMetadata', function() return exports[CORE]:GetMetadata(source, 'optin') end) == true
end

return Integrations
