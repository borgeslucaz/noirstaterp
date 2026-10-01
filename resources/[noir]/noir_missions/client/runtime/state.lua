---Estado de missão deste cliente: o último retrato (view) que o servidor mandou. O cliente
---não decide nada com ele; usa para desenhar HUD, blips e alvos.
local State = {
    view = nil, ---@type table?
    listeners = {},
}

---@param fn fun(view: table?)
function State.onChange(fn)
    State.listeners[#State.listeners + 1] = fn
end

---@param view table?
function State.set(view)
    State.view = view
    for index = 1, #State.listeners do
        local ok, err = pcall(State.listeners[index], view)
        if not ok then lib.print.error(('[noir_missions] estado: %s'):format(err)) end
    end
end

---@return integer?
function State.instanceId()
    return State.view and State.view.instanceId or nil
end

---Este jogador está carregando carga? Lido do state bag que o servidor escreve.
---@return boolean
function State.isCarrying()
    return LocalPlayer.state['noir_missions:carry'] ~= nil
end

return State
