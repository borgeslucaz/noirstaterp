-- Bridge de estado médico: caído/morto e reanimação, sem o consumidor conhecer o qbx_medical.
BGRZ = BGRZ or {}
BGRZ.Medical = BGRZ.Medical or {}

---True quando o jogador está caído (last stand) ou morto.
---O qbx_medical publica isso no state bag `isDead`, replicado pelo servidor.
---@param source number
---@return boolean
function BGRZ.Medical.IsDowned(source)
    if type(source) ~= 'number' or source <= 0 then return false end
    local state = Player(source).state
    return state and state.isDead == true or false
end

---Reanima o jogador pelo provider médico (limpa ferimentos e o estado de morte).
---@param source number
---@return boolean ok
---@return string? errorCode
function BGRZ.Medical.Revive(source)
    if type(source) ~= 'number' or source <= 0 then return false, 'invalid_source' end
    local resource = BGRZ.Provider.name('medical')
    if not BGRZ.Provider.isStarted(resource) then return false, 'provider_unavailable' end
    local called = pcall(function()
        exports[resource]:Revive(source)
    end)
    if not called then return false, 'provider_unavailable' end
    return true
end

exports('IsPlayerDowned', BGRZ.Medical.IsDowned)
exports('RevivePlayer', BGRZ.Medical.Revive)
