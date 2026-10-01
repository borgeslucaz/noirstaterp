local resourceName      = "zydrec-starlitemotel"
local BANNER_COLOR      = "^5"
local repositoryOwner   = "Zydrec"
local repositoryName    = "versioncheck"
local versionFileName   = "versions.json"
local branchName        = "main"

local baseVersionFileUrl = ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(
  repositoryOwner,
  repositoryName,
  branchName,
  versionFileName
)

local function buildVersionUrl()
    return ("%s?cb=%d"):format(baseVersionFileUrl, os.time())
end

local function logInfo(msg)
    print(("^2[%s][VersionCheck]^0 %s"):format(resourceName, msg))
end

local function logWarn(msg)
    print(("^3[%s][VersionCheck]^0 %s"):format(resourceName, msg))
end

local function logError(msg)
    print(("^1[%s][VersionCheck]^0 %s"):format(resourceName, msg))
end

CreateThread(function()
    Wait(5000)

    local currentVersion = GetResourceMetadata(resourceName, "version") or "unknown"
    if currentVersion == "unknown" or currentVersion == "" then
        logWarn("Could not read version from fxmanifest. Ensure 'version ".."' is set.")
    end

    local url = buildVersionUrl()

    PerformHttpRequest(url, function(statusCode, resultData, _)
        if not statusCode then
            logError("No status code returned from HTTP request (network issue?)")
            return
        end

        if statusCode ~= 200 then
            logWarn("Version file not reachable (HTTP "..statusCode.."). Github is down?")
            return
        end

        if not resultData or resultData == "" then
            logError("Empty response body from version file URL")
            return
        end

        local ok, jsonContent = pcall(function()
            return json.decode(resultData)
        end)

        if not ok or type(jsonContent) ~= "table" then
            logError("Failed to decode JSON from version file")
            return
        end

        local latestVersion = jsonContent[resourceName]
        if not latestVersion then
            logWarn("No entry for '"..resourceName.."' found in versions.json")
            return
        end

        if currentVersion ~= latestVersion then
            print(BANNER_COLOR.."["..resourceName.."][VersionCheck] ===============================================^0")
            print(BANNER_COLOR.."["..resourceName.."][VersionCheck]  Update available!^0")
            print(BANNER_COLOR.."["..resourceName.."][VersionCheck]  Current: ^1"..currentVersion.."^0  ->  Latest: ^2"..latestVersion.."^0")
            print(BANNER_COLOR.."["..resourceName.."][VersionCheck]  Get it here: ^4https://portal.cfx.re/^0")
            print(BANNER_COLOR.."["..resourceName.."][VersionCheck] ===============================================^0")
        end
    end, "GET", "", { ["Content-Type"] = "application/json" })
end)