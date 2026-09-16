-- O cliente guarda o XP bruto que o servidor manda e calcula nível e progresso com a
-- mesma curva (shared/xp.lua). Assim os exports respondem na hora, sem callback, e podem
-- ser chamados dentro de loop de render sem custo de rede.
local Xp = NoirSkills.xp
local core = exports.bgrz_core

---@type table<string, number>
local xpBySkill = {}
local visible = false

---Habilidade zerada fica de fora: o painel mostra o que o personagem já treinou, não o
---catálogo do servidor. Quem nunca fez nada vê o estado vazio, e a habilidade aparece
---sozinha no primeiro XP.
local function buildPayload()
    local list = {}

    for _, skill in ipairs(Xp.list()) do
        local xp = xpBySkill[skill] or 0

        if xp > 0 then
            local conf = Config.Skills[skill]
            local progress = Xp.progress(skill, xp)

            list[#list + 1] = {
                name = skill,
                label = conf.label,
                icon = conf.icon,
                color = conf.color,
                level = progress.level,
                maxLevel = progress.maxLevel,
                xp = progress.xp,
                need = progress.need,
                ratio = progress.ratio,
            }
        end
    end

    return list
end

local function push(state)
    SendNUIMessage({ action = 'skills', data = { visible = state, skills = buildPayload() } })
end

local function setVisible(state)
    visible = state
    SetNuiFocus(state, state)
    push(state)
end

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------
local function GetXp(skill)
    return Xp.exists(skill) and (xpBySkill[skill] or 0) or 0
end

local function GetLevel(skill)
    if not Xp.exists(skill) then return 0 end
    return Xp.levelFor(skill, xpBySkill[skill] or 0)
end

local function HasLevel(skill, level)
    if type(level) ~= 'number' then return false end
    return GetLevel(skill) >= level
end

local function GetAll()
    local all = {}
    for _, skill in ipairs(Xp.list()) do
        all[skill] = Xp.progress(skill, xpBySkill[skill] or 0)
    end
    return all
end

exports('GetXp', GetXp)
exports('GetLevel', GetLevel)
exports('HasLevel', HasLevel)
exports('GetAll', GetAll)

-- ---------------------------------------------------------------------------
-- Sincronização
-- ---------------------------------------------------------------------------
RegisterNetEvent('noir_skills:client:sync', function(xp)
    if type(xp) ~= 'table' then return end
    xpBySkill = xp
    if visible then push(true) end
end)

RegisterNetEvent('noir_skills:client:update', function(skill, xp, leveledUp)
    if type(skill) ~= 'string' or type(xp) ~= 'number' then return end
    xpBySkill[skill] = xp

    if visible then push(true) end

    if leveledUp then
        local conf = Config.Skills[skill]
        TriggerEvent('noir_skills:client:levelUp', skill, Xp.levelFor(skill, xp))
        if Config.NotifyLevelUp and conf then
            core:Notify(('%s subiu para o nível %d.'):format(conf.label, Xp.levelFor(skill, xp)), 'success')
        end
    end
end)

-- Restart só deste resource com o jogador já logado: o servidor não vai reemitir
-- playerLoaded, então quem pergunta é o cliente.
CreateThread(function()
    local synced = lib.callback.await('noir_skills:server:sync', false)
    if type(synced) == 'table' then xpBySkill = synced end
end)

-- ---------------------------------------------------------------------------
-- Painel
-- ---------------------------------------------------------------------------
RegisterCommand(Config.Command, function()
    if visible then return setVisible(false) end
    if IsPauseMenuActive() or IsNuiFocused() then return end
    setVisible(true)
end, false)

RegisterKeyMapping(Config.Command, 'Abrir habilidades', 'keyboard', Config.Hotkey)

RegisterNUICallback('close', function(_, cb)
    setVisible(false)
    cb(1)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and visible then SetNuiFocus(false, false) end
end)
