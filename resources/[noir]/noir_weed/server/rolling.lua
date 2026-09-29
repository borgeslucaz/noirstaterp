---Bolar baseado com o dixavador: um bud e duas sedas viram dois baseados, e o dixavador
---perde `grinderCost` de qualidade. Em 0 ele fica gasto no inventário (sem `decay`).

local Shared = require 'config.shared'
local Integrations = require 'server.integrations'
local Actions = require 'server.actions'

local roll = Shared.roll

---Código da ponte -> código do resource.
local GRINDER_CODES = { not_enough_items = 'no_grinder', low_durability = 'grinder_worn' }

---Variedades que o jogador tem bud para bolar, e quantas sedas tem.
lib.callback.register('noir_weed:server:rollOptions', function(source, grinder)
    if type(grinder) ~= 'string' or not Shared.grinders[grinder] then return { ok = false, code = 'invalid_request' } end
    local ok, err = Integrations.hasDurability(source, grinder, Shared.grinderCost)
    if not ok then return { ok = false, code = GRINDER_CODES[err] or 'operation_failed' } end

    local strains = {}
    for seed, strain in pairs(Shared.strains) do
        local count = Integrations.count(source, strain.product)
        if count >= roll.buds then
            strains[#strains + 1] = { seed = seed, label = strain.label, product = strain.product, count = count }
        end
    end
    table.sort(strains, function(a, b) return a.label < b.label end)
    return { ok = true, strains = strains, papers = Integrations.count(source, Shared.items.paper) }
end)

Actions.register('roll', {
    check = function(source, _, payload)
        if type(payload) ~= 'table' then return false, 'invalid_request' end
        local grinder, strain = payload.grinder, Shared.strains[payload.seed or '']
        if type(grinder) ~= 'string' or not Shared.grinders[grinder] or not strain then return false, 'invalid_request' end

        local ok, err = Integrations.hasDurability(source, grinder, Shared.grinderCost)
        if not ok then return false, GRINDER_CODES[err] or 'operation_failed' end
        if Integrations.count(source, strain.product) < roll.buds then return false, 'no_bud' end
        if Integrations.count(source, Shared.items.paper) < roll.papers then return false, 'no_paper' end
        if not Integrations.canCarry(source, Shared.items.joint, roll.joints) then return false, 'inventory_full' end
        return true, nil, { grinder = grinder, strain = strain }
    end,
    apply = function(source, _, context)
        local product, paper = context.strain.product, Shared.items.paper
        if not Integrations.removeItem(source, product, roll.buds) then return false, 'no_bud' end
        if not Integrations.removeItem(source, paper, roll.papers) then
            Integrations.addItem(source, product, roll.buds)
            return false, 'no_paper'
        end
        local used, err = Integrations.useDurability(source, context.grinder, Shared.grinderCost)
        if not used then
            Integrations.addItem(source, product, roll.buds)
            Integrations.addItem(source, paper, roll.papers)
            return false, GRINDER_CODES[err] or 'operation_failed'
        end

        local ok, code = Integrations.addItem(source, Shared.items.joint, roll.joints)
        if not ok then
            lib.print.error(('bolar: AddItem falhou para %d (%s)'):format(source, tostring(code)))
            return false, 'operation_failed'
        end
        return true, nil, { amount = roll.joints, label = context.strain.label }
    end,
})
