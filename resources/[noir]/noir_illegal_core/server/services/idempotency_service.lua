local Service = {}
NoirIllegal.Services.Idempotency = Service

local function decode(payload)
    if type(payload) == 'table' then return payload end
    if type(payload) ~= 'string' or payload == '' then return {} end
    local ok, result = pcall(json.decode, payload)
    return ok and result or {}
end

function Service.resolve(row, identity)
    if not row then return nil end
    if row.activity_key ~= identity.activityKey
        or row.caller_resource ~= identity.callerResource
        or row.citizenid ~= identity.citizenId then
        return false, NoirIllegal.error('DUPLICATE_TRANSACTION')
    end

    local payload = decode(row.result_payload)
    if row.status == 'rejected' then
        payload.ok = false
        payload.code = row.rejection_code
        payload.message = NoirIllegal.Errors[row.rejection_code] or NoirIllegal.Errors.INTERNAL_ERROR
        payload.replayed = true
        return false, payload
    end

    payload.ok = true
    payload.replayed = true
    return true, payload
end
