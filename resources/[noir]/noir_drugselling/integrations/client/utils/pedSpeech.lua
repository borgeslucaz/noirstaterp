-- Fala do ped (noir_lib): a reação do comprador aparece num balão acima da cabeça dele, com
-- uma das falas de `Config.PedSpeech` sorteada. Sem o noir_lib no ar, ou se o balão não
-- sair, cai na notificação de antes.

---@param ped integer
---@param kind string chave em Config.PedSpeech
---@param notifyKey string locale da notificação de reserva
---@param tone? 'neutral'|'alert'
function pedSpeak(ped, kind, notifyKey, tone)
    local lines = Config.PedSpeech and Config.PedSpeech[kind]
    if lines and ped and DoesEntityExist(ped) and GetResourceState('noir_lib') == 'started' then
        local ok, id = pcall(function()
            return exports.noir_lib:PedSay(ped, lines, { tone = tone or 'neutral' })
        end)
        if ok and id then return end
    end
    if notifyKey then sendNotify(TranslateIt(notifyKey), 'error', 5) end
end
