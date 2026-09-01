-- modules/clipboard.lua
-- Clipboard helper. Falls back to F8 console if ox_lib clipboard is not available.

SFD = SFD or {}

function SFD.SetClipboard(text)
    if text == nil then return false end
    text = tostring(text)
    if lib and lib.setClipboard then
        lib.setClipboard(text)
        return true
    end
    -- Fallback: F8 console output
    print('^5[ShadowForge DevTools — Clipboard]^7')
    print(text)
    return false
end
