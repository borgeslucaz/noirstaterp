---Dixavador: usar no inventário abre o menu com as variedades que dá para bolar.

local Shared = require 'config.shared'
local Integrations = require 'client.integrations'
local Actions = require 'client.actions'

local roll = Shared.roll

exports('useGrinder', function(data)
    local grinder = type(data) == 'table' and data.name
    if not grinder or not Shared.grinders[grinder] or Actions.isBusy() then return end

    local response = lib.callback.await('noir_weed:server:rollOptions', false, grinder)
    if not response or not response.ok then return Actions.fail(response and response.code) end
    if #response.strains == 0 then return Actions.fail('no_bud') end
    if response.papers < roll.papers then return Actions.fail('no_paper') end

    local options = {}
    for _, strain in ipairs(response.strains) do
        options[#options + 1] = {
            title = strain.label,
            description = locale('menu_roll_hint', strain.count, roll.papers, roll.joints),
            icon = 'cannabis',
            onSelect = function()
                local done = Actions.perform('roll', { grinder = grinder, seed = strain.seed })
                if done and done.result then
                    Integrations.notify(locale('success_roll', done.result.amount, done.result.label), 'success')
                end
            end,
        }
    end

    lib.registerContext({ id = 'noir_weed:roll', title = locale('menu_roll_title'), options = options })
    lib.showContext('noir_weed:roll')
end)
