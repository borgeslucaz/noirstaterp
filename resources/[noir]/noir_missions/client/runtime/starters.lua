---Início de missão por NPC ou por zona. O NPC é local de cada cliente: nasce quando o jogador
---chega perto e some quando ele sai. Conversar só pede ao servidor, que confere de novo que a
---missão está publicada, começa assim e que a pessoa está lá.
local ClientConfig = require 'config.client'
local Integrations = require 'client.integrations'
local Hud = require 'client.runtime.hud'

local Starters = {}

local points = {}
local OPTION = 'noir_missions:starter:talk'

---@param result table?
local function report(result)
    if result and result.ok then return end
    local code = result and result.code
    if code == 'rate_limited' then return end
    Integrations.notify(Hud.CODES[code] or 'Agora não.', 'error')
end

local function request(missionId)
    report(lib.callback.await('noir_missions:server:starterRequest', false, missionId))
end

local function removePed(point)
    if point.ped and DoesEntityExist(point.ped) then
        Integrations.removeLocalEntityTarget(point.ped, { OPTION })
        DeletePed(point.ped)
    end
    point.ped = nil
end

local function spawnPed(point, starter)
    local model = joaat(starter.model or '')
    -- Enhanced: modelo inexistente derruba o cliente. Sem conferir, não cria.
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        lib.print.warn(('[noir_missions] NPC de início com modelo inválido: %s'):format(tostring(starter.model)))
        return
    end
    if not lib.requestModel(model, 5000) then return end
    local coords = starter.coords
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then return end
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    if starter.scenario and starter.scenario ~= '' then TaskStartScenarioInPlace(ped, starter.scenario, 0, true) end
    point.ped = ped
    Integrations.addLocalEntityTarget(ped, { {
        name = OPTION,
        label = starter.label or 'Conversar',
        icon = 'fa-solid fa-comments',
        distance = 2.5,
        onSelect = function() request(starter.missionId) end,
    } })
end

function Starters.clear()
    for _, point in ipairs(points) do
        removePed(point)
        point:remove()
    end
    points = {}
end

---@param list table[]
function Starters.load(list)
    Starters.clear()
    for _, starter in ipairs(list or {}) do
        local coords = vec3(starter.coords.x, starter.coords.y, starter.coords.z)
        if starter.type == 'npc' then
            local point = lib.points.new({ coords = coords, distance = ClientConfig.starterSpawnDistance })
            function point:onEnter() spawnPed(self, starter) end
            function point:onExit() removePed(self) end
            points[#points + 1] = point
        elseif starter.type == 'zone' then
            local point = lib.points.new({ coords = coords, distance = starter.radius or 10 })
            function point:onEnter()
                if (self.nextOffer or 0) > GetGameTimer() then return end
                self.nextOffer = GetGameTimer() + 60000
                request(starter.missionId)
            end
            points[#points + 1] = point
        end
    end
end

function Starters.fetch()
    Starters.load(lib.callback.await('noir_missions:server:starters', false))
end

RegisterNetEvent('noir_missions:client:starters', function(list)
    if source ~= 65535 then return end
    Starters.load(list)
end)

return Starters
