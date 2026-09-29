---Ponto único de registro do resource. Hoje vai para o console do servidor; quando
---existir o sistema de logs, só esta função muda.

local Logs = {}

---@param source number
---@param event string nome curto e estável (`pack_fast`...)
---@param data table campos do evento
function Logs.event(source, event, data)
    local parts = {}
    for key, value in pairs(data) do parts[#parts + 1] = ('%s=%s'):format(key, tostring(value)) end
    table.sort(parts)
    lib.print.warn(('[%s] %s (%s) %s'):format(event, GetPlayerName(source) or '?', source, table.concat(parts, ' ')))
end

return Logs
