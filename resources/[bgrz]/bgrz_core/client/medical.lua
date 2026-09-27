-- Bridge de estado médico no client: caído/morto, tempo restante e pedido de respawn.
BGRZ = BGRZ or {}
BGRZ.Medical = BGRZ.Medical or {}

local function provider()
    local resource = BGRZ.Provider.name('medical')
    if not BGRZ.Provider.isStarted(resource) then return nil end
    return resource
end

---Estado de queda do jogador local.
---@return { state: 'laststand'|'dead', seconds: integer }? info nil quando está de pé
function BGRZ.Medical.GetDownedInfo()
    local resource = provider()
    if not resource then return nil end
    local called, info = pcall(function()
        local medical = exports[resource]
        if medical:IsLaststand() then
            return { state = 'laststand', seconds = medical:GetLaststandTime() }
        elseif medical:IsDead() then
            return { state = 'dead', seconds = medical:GetDeathTime() }
        end
    end)
    if not called or not info then return nil end
    info.seconds = math.max(0, math.floor(tonumber(info.seconds) or 0))
    return info
end

---Pede o respawn no hospital. Só é aceito morto (não caído) e com o respawn liberado.
---@return boolean accepted
function BGRZ.Medical.RequestRespawn()
    local resource = provider()
    if not resource then return false end
    local called, accepted = pcall(function()
        return exports[resource]:RequestRespawn()
    end)
    return called and accepted == true
end

exports('GetDownedInfo', BGRZ.Medical.GetDownedInfo)
exports('RequestRespawn', BGRZ.Medical.RequestRespawn)

-- Reemite o respawn com nome do bridge: o consumidor não depende do evento do qbx_medical.
AddEventHandler('qbx_medical:client:onPlayerRespawned', function()
    TriggerEvent('bgrz_core:client:playerRespawned')
end)
