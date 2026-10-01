BGRZ = BGRZ or {}

local notificationFields = {
    app = 64,
    appId = 64,
    title = 96,
    body = 512,
    image = 2048,
    time = 32,
}


-- Ícone/agrupamento no telefone quando o caller não informa o app de origem.
local DEFAULT_APP_ID = 'noir'

local function normalizePayload(payload)
    if type(payload) ~= 'table' or type(payload.title) ~= 'string'
        or #payload.title == 0 or #payload.title > notificationFields.title then
        return nil
    end
    local normalized = {}
    for field, maximum in pairs(notificationFields) do
        local value = payload[field]
        if value ~= nil then
            if type(value) ~= 'string' or #value > maximum then return nil end
            normalized[field] = value
        end
    end
    return normalized
end

---@param source number
---@param payload table
---@return boolean ok
---@return string? errorCode
function BGRZ.SendPhoneNotification(source, payload)
    if type(source) ~= 'number' or source <= 0 or source % 1 ~= 0 then
        return false, 'invalid_source'
    end
    local normalized = normalizePayload(payload)
    if not normalized then return false, 'invalid_payload' end

    if not BGRZ.Provider.isAvailable('phone') then return false, 'provider_unavailable' end
    -- O sky_phone só notifica por export nativo em nome de um app com policy de servidor. A
    -- notificação solta, por source, ele expõe no alias de compatibilidade qs-smartphone, que vai
    -- direto para o sistema de notificações dele. O alias não devolve resultado: jogador sem
    -- telefone equipado simplesmente não recebe.
    local appId = normalized.appId
    if not appId or not appId:match('^[a-z0-9][a-z0-9._-]+$') then appId = DEFAULT_APP_ID end
    local called = pcall(function()
        exports['qs-smartphone']:sendPhoneNotification(source, {
            appId = appId,
            title = normalized.title,
            body = normalized.body or normalized.title,
        })
    end)
    if not called then return false, 'provider_unavailable' end
    return true
end

exports('SendPhoneNotification', BGRZ.SendPhoneNotification)

---SMS de sistema pela linha de serviço de uma empresa do telefone (ex.: 911 da LSPD).
---Fica salvo na conversa e chega mesmo com o destinatário offline (vai para os chips
---registrados no nome do personagem).
---@param companyId string id da empresa no sky_phone (Config.Companies.Definitions)
---@param citizenId string
---@param body string
---@return boolean ok
---@return string|integer? errorCodeOrSent
function BGRZ.SendPhoneServiceMessage(companyId, citizenId, body)
    if type(companyId) ~= 'string' or companyId == '' then return false, 'invalid_company' end
    if type(citizenId) ~= 'string' or citizenId == '' then return false, 'invalid_recipient' end
    if type(body) ~= 'string' or body == '' or #body > 2000 then return false, 'invalid_message' end
    if not BGRZ.Provider.isAvailable('phone') then return false, 'provider_unavailable' end
    local resource = BGRZ.Provider.name('phone')
    local called, sent, err = pcall(function()
        return exports[resource]:SendServiceMessage(companyId, { identifier = citizenId }, body)
    end)
    if not called then return false, 'provider_unavailable' end
    if not sent then return false, err or 'operation_failed' end
    if sent == 0 then return false, err or 'no_sim' end
    return true, sent
end

exports('SendPhoneServiceMessage', BGRZ.SendPhoneServiceMessage)

---SMS anônimo do servidor: sai de um número aleatório que não é de ninguém (sem nome, sem
---empresa) e responder não chega a lugar nenhum. Como o de serviço, fica na conversa e chega
---mesmo com o destinatário offline, nos chips registrados no nome do personagem.
---@param citizenId string
---@param body string
---@return boolean ok
---@return integer|string sentOrError chips que receberam, ou o código do erro
function BGRZ.SendPhoneAnonymousMessage(citizenId, body)
    if type(citizenId) ~= 'string' or citizenId == '' then return false, 'invalid_recipient' end
    if type(body) ~= 'string' or body == '' or #body > 2000 then return false, 'invalid_message' end
    if not BGRZ.Provider.isAvailable('phone') then return false, 'provider_unavailable' end
    local resource = BGRZ.Provider.name('phone')
    local called, sent, err = pcall(function()
        return exports[resource]:SendAnonymousMessage(citizenId, body)
    end)
    if not called then return false, 'provider_unavailable' end
    if not sent then return false, err or 'operation_failed' end
    if sent == 0 then return false, err or 'no_sim' end
    return true, sent
end

exports('SendPhoneAnonymousMessage', BGRZ.SendPhoneAnonymousMessage)
