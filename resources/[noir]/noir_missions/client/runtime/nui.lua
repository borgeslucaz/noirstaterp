---Página NUI única (editor + HUD + oferta) e o foco dela.
---
---Dois donos de foco podem existir ao mesmo tempo: o editor e a oferta. O foco só sai quando
---nenhum dos dois precisa dele; assim, uma ligação que chega com o editor aberto não solta o
---mouse do admin ao ser respondida.
local Nui = {}

local owners = {}
local ready = false
local queue = {}
local readyHooks = {}

---Roda quando a página avisa que está pronta, inclusive depois de um reload do CEF: quem tem
---estado na tela (HUD da missão) manda de novo (§15.3).
---@param fn function
function Nui.onReady(fn)
    readyHooks[#readyHooks + 1] = fn
end

---@param action string
---@param data? table
function Nui.send(action, data)
    if not ready then
        queue[#queue + 1] = { action = action, data = data or {} }
        return
    end
    SendNUIMessage({ action = action, data = data or {} })
end

---@param owner string
---@param enabled boolean
function Nui.focus(owner, enabled)
    owners[owner] = enabled or nil
    local any = next(owners) ~= nil
    SetNuiFocus(any, any)
    SetNuiFocusKeepInput(false)
end

---@param owner string
---@return boolean
function Nui.hasFocus(owner)
    return owners[owner] == true
end

function Nui.releaseAll()
    owners = {}
    SetNuiFocus(false, false)
end

RegisterNUICallback('uiReady', function(_, cb)
    ready = true
    local pending = queue
    queue = {}
    for index = 1, #pending do SendNUIMessage(pending[index]) end
    cb({ ok = true })
    for index = 1, #readyHooks do pcall(readyHooks[index]) end
end)

return Nui
