-- Adaptadores: o fato acontece em outro resource, o registro acontece aqui.
--
-- noir_drugselling, noir_outposts e noir_territories não conhecem o core. Cada um anuncia por
-- evento de servidor o que aconteceu — uma venda fechou, um posto foi tomado, um bairro trocou
-- de dono — e o adaptador correspondente decide qual atividade isso é. Quanto ela vale mora em
-- `shared/activities.lua`. Assim quem produz o fato nunca escolhe o próprio prêmio, e desligar
-- o core não quebra nenhum deles.
--
-- Todo registro sai com o core como caller, que é o único `publicRecorder`.

NoirIllegal.Adapters = {}

local Adapters = NoirIllegal.Adapters
local CALLER = 'noir_illegal_core'

-- Recusas que fazem parte do jogo e não são defeito: o assalto dentro do cooldown, o replay de
-- um bairro que já pagou no período.
local EXPECTED = {
    COOLDOWN_ACTIVE = true,
    NOT_ELIGIBLE = true,
}

---Evento de servidor não tem remetente garantido: qualquer resource pode dar `TriggerEvent` com
---o mesmo nome. O que separa o anúncio verdadeiro do forjado é quem disparou.
function Adapters.from(resourceName)
    return GetInvokingResource() == resourceName
end

local function report(activityKey, ok, result)
    if ok then return end
    local code = type(result) == 'table' and result.code or 'INTERNAL_ERROR'
    local level = EXPECTED[code] and 'debug' or 'warn'
    NoirIllegal.Logger.write(level, 'adapter_record_refused', {
        activityKey = activityKey,
        code = code,
    })
end

---Registro de atividade com autor. Roda numa thread própria: o banco espera, e quem anunciou o
---fato não tem por que esperar junto.
function Adapters.record(source, activityKey, transactionId, options)
    CreateThread(function()
        if not NoirIllegal.Ready then return end
        local ok, accepted, result = pcall(NoirIllegal.Services.Activity.record,
            source, activityKey, transactionId, options, CALLER)
        if not ok then
            NoirIllegal.Logger.error('adapter_exception', { activityKey = activityKey, error = tostring(accepted) })
            return
        end
        report(activityKey, accepted, result)
    end)
end

---Registro de atividade da gang, sem autor.
function Adapters.recordOrganization(organizationId, activityKey, transactionId, options)
    CreateThread(function()
        if not NoirIllegal.Ready then return end
        local ok, accepted, result = pcall(NoirIllegal.Services.Activity.recordOrganization,
            organizationId, activityKey, transactionId, options, CALLER)
        if not ok then
            NoirIllegal.Logger.error('adapter_exception', { activityKey = activityKey, error = tostring(accepted) })
            return
        end
        report(activityKey, accepted, result)
    end)
end
