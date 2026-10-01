-- PATCH NOIR: o app Faturas é uma janela para as faturas do Renewed-Banking.
--
-- Faturas e multas moram no banco (`bank_invoices`, Renewed-Banking/server/invoices.lua): é lá
-- que se emite, paga e bloqueia saque. O celular só lista, marca como lida, contesta e paga
-- pelos exports do banco, que já devolvem no formato deste app. As tabelas
-- `sky_phone_billing_*` ficam paradas (histórico antigo), nada novo é gravado nelas.

Bridge.Database.AfterMigration("sky_phone", function()

local BANK = "Renewed-Banking"

local function bank_ready()
    return GetResourceState(BANK) == "started"
end

---Erros do banco que o app não conhece viram um dos que ele sabe mostrar.
local KNOWN_ERRORS = {
    invoice_not_found = true, invoice_not_payable = true, invoice_already_paid = true,
    insufficient_funds = true, payment_in_progress = true, dispute_unavailable = true,
}

local function bank_error(err)
    return KNOWN_ERRORS[err] and err or "payment_failed"
end

local function require_billing_session(source)
    if not Config.Billing.Enabled or not bank_ready() then
        return nil, { success = false, error = "billing_unavailable" }
    end
    local session, error_response = SkyPhone.RequireSession(source)
    if not session then
        return nil, error_response
    end
    local identifier = Bridge.Framework.GetIdentifier(source)
    if type(identifier) ~= "string" or identifier == "" then
        return nil, { success = false, error = "billing_unavailable" }
    end
    return identifier
end

local function direction_of(data)
    return data and data.direction == "sent" and "sent" or "inbox"
end

Bridge.Callbacks.Register("sky_phone:billing:overview", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local summary = exports[BANK]:GetInvoiceSummary(identifier, direction_of(data))
    summary.currency = Config.Billing.Currency
    return { success = true, data = summary }
end)

Bridge.Callbacks.Register("sky_phone:billing:list", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local filter = type(data and data.filter) == "string" and data.filter or "all"
    if filter ~= "all" and filter ~= "open" and filter ~= "overdue" and filter ~= "paid" then
        return { success = false, error = "invalid_request" }
    end
    return {
        success = true,
        data = exports[BANK]:ListInvoices(identifier, {
            direction = direction_of(data),
            filter = filter,
            offset = data and data.offset,
            search = data and data.search,
            pageSize = Config.Billing.PageSize,
        }),
    }
end)

Bridge.Callbacks.Register("sky_phone:billing:detail", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local invoice = exports[BANK]:GetInvoice(identifier, data and data.id)
    if not invoice then
        return { success = false, error = "invoice_not_found" }
    end
    return { success = true, data = invoice }
end)

Bridge.Callbacks.Register("sky_phone:billing:markRead", function(source, data)
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    if not exports[BANK]:MarkInvoiceRead(identifier, data and data.id) then
        return { success = false, error = "invoice_not_found" }
    end
    local summary = exports[BANK]:GetInvoiceSummary(identifier, "inbox")
    return { success = true, data = { unreadCount = summary.unreadCount or 0 } }
end)

Bridge.Callbacks.Register("sky_phone:billing:dispute", function(source, data)
    if not Config.Billing.AllowDisputes then
        return { success = false, error = "dispute_unavailable" }
    end
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    -- Multa não se contesta: o banco recusa com dispute_unavailable.
    local invoice, err = exports[BANK]:DisputeInvoice(identifier, data and data.id)
    if not invoice then
        return { success = false, error = bank_error(err) }
    end
    return { success = true, data = invoice }
end)

Bridge.Callbacks.Register("sky_phone:billing:pay", function(source, data)
    if not SkyPhone.AllowOperation(source, "billing_payment", Config.Billing.ActionsPerMinute, 60) then
        return { success = false, error = "rate_limited" }
    end
    local identifier, error_response = require_billing_session(source)
    if not identifier then
        return error_response
    end
    local invoice, err = exports[BANK]:PayInvoice(source, data and data.id)
    if not invoice then
        return { success = false, error = bank_error(err) }
    end
    TriggerClientEvent("sky_phone:banking:changed", source)
    return { success = true, data = invoice }
end)

-- Avisos do banco -> celular -----------------------------------------------------------
-- Eventos locais do servidor (TriggerEvent no Renewed): AddEventHandler, então cliente não dispara.

AddEventHandler("Renewed-Banking:noir:invoicesChanged", function(target)
    if tonumber(target) then
        TriggerClientEvent("sky_phone:billing:changed", tonumber(target))
    end
end)

AddEventHandler("Renewed-Banking:noir:invoiceCreated", function(target, data)
    if tonumber(target) and type(data) == "table" then
        TriggerClientEvent("sky_phone:billing:new", tonumber(target), {
            amount = tonumber(data.amount) or 0,
            issuer = tostring(data.issuer or ""),
        })
    end
end)

-- Exports antigos: quem ainda chama o celular para cobrar cai no banco. -------------------

exports("CreateInvoice", function(data)
    if not bank_ready() or type(data) ~= "table" then
        return nil, "billing_unavailable"
    end
    return exports[BANK]:CreateInvoice({
        recipientCid = data.recipientCid or data.recipientIdentifier,
        recipientSource = data.recipientSource,
        issuerCid = data.issuerCid or data.issuerIdentifier,
        issuerSource = data.issuerSource,
        issuerAccount = data.issuerAccount,
        issuerLabel = data.issuerLabel,
        kind = data.kind,
        blocking = data.blocking,
        title = data.title,
        description = data.description,
        amount = data.amount,
        dueDays = data.dueDays,
    })
end)

exports("CancelInvoice", function(invoice_id, actor_identifier)
    if not bank_ready() then
        return false
    end
    return exports[BANK]:CancelInvoice(invoice_id, actor_identifier)
end)

end)
