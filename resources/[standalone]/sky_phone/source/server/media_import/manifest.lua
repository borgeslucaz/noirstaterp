local manifest_cache = {}

local function authentication_headers(website)
    local auth = website.Auth
    if not auth or auth.Type == nil or auth.Type == "none" then
        return {}
    end

    if auth.Type == "bearer" then
        return { ["Authorization"] = "Bearer " .. GetConvar(auth.TokenConvar, "") }
    end
    return { [auth.Header] = GetConvar(auth.ValueConvar, "") }
end

local function validate_authentication(auth)
    if auth == nil then
        return true
    end
    if type(auth) ~= "table" then
        return false, "invalid_auth"
    end
    if auth.Type == nil or auth.Type == "none" then
        return true
    end
    if auth.Type == "bearer" then
        if type(auth.TokenConvar) ~= "string" or auth.TokenConvar == ""
            or GetConvar(auth.TokenConvar, "") == ""
        then
            return false, "missing_auth_convar"
        end
        return true
    end
    if auth.Type == "header" then
        if type(auth.Header) ~= "string" or not auth.Header:match("^[%w%-]+$")
            or type(auth.ValueConvar) ~= "string" or auth.ValueConvar == ""
            or GetConvar(auth.ValueConvar, "") == ""
        then
            return false, "invalid_header_auth"
        end
        return true
    end
    return false, "unknown_auth_type"
end

local function fetch_manifest(website)
    local now = os.time()
    local cached = manifest_cache[website.Id]
    if cached and cached.expires_at > now then
        return cached.items
    end

    local response = SkyPhoneMediaImport.HttpRequest(
        website.ManifestUrl,
        authentication_headers(website),
        tonumber(website.RequestTimeoutMs) or 10000
    )
    if response.status == 0 then
        return nil, "import_source_unavailable"
    end
    if response.status == 401 or response.status == 403 then
        return nil, "import_provider_unauthorized"
    end
    if response.status < 200 or response.status >= 300 then
        return nil, "import_provider_failed"
    end

    local max_bytes = math.max(1024, math.floor(tonumber(Config.Media.Import.ManifestMaxBytes) or 2097152))
    if #response.body > max_bytes then
        return nil, "import_provider_failed"
    end

    local success, decoded = pcall(json.decode, response.body)
    if not success or type(decoded) ~= "table" or tonumber(decoded.version) ~= 1
        or type(decoded.items) ~= "table"
    then
        return nil, "import_provider_failed"
    end

    local maximum_items = math.max(1, math.floor(tonumber(Config.Media.Import.ManifestMaxItems) or 5000))
    if #decoded.items > maximum_items then
        return nil, "import_provider_failed"
    end

    local items = {}
    for _, item in ipairs(decoded.items) do
        if type(item) == "table" then
            items[#items + 1] = {
                externalId = item.id,
                filename = item.filename,
                mediaType = item.type,
                mimeType = item.mimeType,
                size = item.size,
                url = item.url,
            }
        end
    end
    manifest_cache[website.Id] = {
        expires_at = now + math.max(1, math.floor(tonumber(website.CacheSeconds)
            or tonumber(Config.Media.Import.ManifestCacheSeconds) or 30)),
        items = items,
    }
    return items
end

SkyPhoneMediaImport.RegisterAdapter("manifest", {
    Validate = function(website)
        if type(website.ManifestUrl) ~= "string"
            or not website.ManifestUrl:match("^https://")
            or #website.ManifestUrl > Config.Media.UrlMaxLength
        then
            return false, "invalid_manifest_url"
        end
        return validate_authentication(website.Auth)
    end,

    List = function(website, requested_type, page, limit)
        local manifest, manifest_error = fetch_manifest(website)
        if not manifest then
            return nil, manifest_error
        end

        local matching = {}
        for _, item in ipairs(manifest) do
            if item.mediaType == requested_type then
                matching[#matching + 1] = item
            end
        end
        local first = (page - 1) * limit + 1
        local last = math.min(#matching, first + limit - 1)
        local items = {}
        for index = first, last do
            items[#items + 1] = matching[index]
        end
        return {
            hasMore = last < #matching,
            items = items,
            total = #matching,
        }
    end,

    Resolve = function(website, external_id)
        local manifest, manifest_error = fetch_manifest(website)
        if not manifest then
            return nil, manifest_error
        end
        for _, item in ipairs(manifest) do
            if item.externalId == external_id then
                return item
            end
        end
        return nil, "import_media_unavailable"
    end,
})
