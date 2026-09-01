-- ---------------------------------------------------------------------------
--  Voice module - pma-voice integration
-- ---------------------------------------------------------------------------
--  Per spec: SINGLE source of truth = LocalPlayer.state.proximity.mode.
--  Mode is normalized to exactly one of "whisper" / "normal" / "shouting".
--  Distance is mapped to fixed values (1.5 / 7.5 / 15.0). No dynamic distance.
--  Updates are only sent when the mode actually changes.
-- ---------------------------------------------------------------------------

local FIXED = {
    whisper  = 1.5,
    normal   = 7.5,
    shouting = 15.0,
}

-- Normalize incoming pma-voice values to a clean mode string. Supports both
-- string ("whisper"/"normal"/"shouting") and numeric (1/2/3) formats.
local function normalize(raw)
    if raw == nil then return nil end
    if type(raw) == 'number' then
        if raw == 1 then return 'whisper' end
        if raw == 2 then return 'normal'  end
        if raw == 3 then return 'shouting' end
        return nil
    end
    if type(raw) == 'string' then
        local v = string.lower(raw)
        if v == 'whisper' or v == 'normal' or v == 'shouting' then
            return v
        end
    end
    return nil
end

local lastMode = nil

local function readMode()
    local proximity = LocalPlayer and LocalPlayer.state and LocalPlayer.state.proximity or nil
    if type(proximity) == 'table' then
        local m = normalize(proximity.mode)
        if m then return m end
    elseif proximity ~= nil then
        -- Some pma-voice forks expose the mode directly on a separate key.
        local m = normalize(proximity)
        if m then return m end
    end

    -- Some pma-voice versions expose voiceMode via convar/state instead.
    local alt = LocalPlayer and LocalPlayer.state and LocalPlayer.state.voiceMode or nil
    local m = normalize(alt)
    if m then return m end

    return nil
end

CreateThread(function()
    if not Config.Voice.enabled then return end

    -- One-shot failsafe so the HUD shows something immediately at boot.
    HUD.state.voice = { mode = 'normal', distance = FIXED.normal }
    HUD.pushVoice('normal', FIXED.normal)
    lastMode = 'normal'

    while true do
        Wait(Config.Tick.voice or 200)
        local mode = readMode()

        if mode == nil then
            -- Invalid / missing -> only apply fallback once, do not override.
            if lastMode == nil then
                lastMode = 'normal'
                HUD.state.voice = { mode = 'normal', distance = FIXED.normal }
                HUD.pushVoice('normal', FIXED.normal)
            end
        elseif mode ~= lastMode then
            lastMode = mode
            local d = FIXED[mode] or FIXED.normal
            HUD.state.voice = { mode = mode, distance = d }
            HUD.pushVoice(mode, d)
            -- Let the marker module know.
            TriggerEvent('lcp_hud_v4:voiceModeChanged', mode, d)
        end
    end
end)

-- Public export so other resources can read the normalized mode.
exports('GetVoiceMode', function()
    local v = HUD.state.voice or { mode = 'normal', distance = FIXED.normal }
    return v.mode, v.distance
end)
