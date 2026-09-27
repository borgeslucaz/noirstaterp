SkyPhoneYouTube = {}

local function trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or nil
end

local function truncate_text(value, maximum)
    local length = type(value) == "string" and utf8.len(value) or nil
    if not length or length <= maximum then return value end
    local boundary = utf8.offset(value, maximum + 1)
    return boundary and value:sub(1, boundary - 1) or value
end

function SkyPhoneYouTube.ParseId(value)
    if type(value) ~= "string" or #value > 500 or value:find("[^\33-\126]") then return nil end

    local authority, path = value:match("^https://([^/]+)(/.*)$")
    if not authority or authority:find("@", 1, true) then return nil end

    local host = authority:lower():gsub(":443$", "")
    local id
    if host == "youtu.be" or host == "www.youtu.be" then
        id = path:match("^/([%w_-]+)")
    elseif host == "youtube.com"
        or host == "www.youtube.com"
        or host == "m.youtube.com"
        or host == "music.youtube.com"
        or host == "youtube-nocookie.com"
        or host == "www.youtube-nocookie.com"
    then
        id = path:match("[?&]v=([%w_-]+)")
            or path:match("^/shorts/([%w_-]+)")
            or path:match("^/embed/([%w_-]+)")
            or path:match("^/live/([%w_-]+)")
    end
    return id and #id == 11 and id or nil
end

function SkyPhoneYouTube.WatchUrl(video_id)
    return "https://www.youtube.com/watch?v=" .. video_id
end

function SkyPhoneYouTube.FetchMetadata(video_id)
    local request = promise.new()
    local settled = false
    local function resolve(value)
        if settled then return end
        settled = true
        request:resolve(value)
    end

    PerformHttpRequest(
        "https://www.youtube.com/oembed?format=json&url=" .. SkyPhoneYouTube.WatchUrl(video_id),
        function(status, body)
            if status ~= 200 or type(body) ~= "string" then
                resolve(nil)
                return
            end
            local success, decoded = pcall(json.decode, body)
            if not success or type(decoded) ~= "table" then
                resolve(nil)
                return
            end
            local title = trim(decoded.title)
            local artist = trim(decoded.author_name)
            if not title or title == "" or not artist or artist == "" then
                resolve(nil)
                return
            end
            resolve({
                title = truncate_text(title, 160),
                artist = truncate_text(artist, 120),
            })
        end,
        "GET",
        "",
        { ["Accept"] = "application/json" }
    )

    SetTimeout(Config.Music.MetadataTimeoutMs, function()
        resolve(nil)
    end)
    return Citizen.Await(request)
end
