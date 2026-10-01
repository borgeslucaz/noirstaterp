---Editor de posições em jogo (/policiaeditor). Só admin (ACE `noir.police.admin`).
---O cliente monta o rascunho; aqui ele é validado inteiro (shared/layout.lua) antes
---de gravar e publicar.

local Codec = require 'shared.layout'
local Integrations = require 'server.integrations'
local Layout = require 'server.layout'

local ACE = 'noir.police.admin'

local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, ACE)
end

lib.addCommand('policiaeditor', {
    help = locale('command.editor'),
    restricted = 'group.admin',
}, function(source)
    if not isAdmin(source) then return Integrations.notify(source, locale('error.not_admin'), 'error') end
    TriggerClientEvent('noir_police:client:openEditor', source, Layout.snapshot())
end)

lib.callback.register('noir_police:server:editorSave', function(source, kind, data)
    if not isAdmin(source) then return { ok = false, code = 'not_admin' } end
    if not Codec.kinds[kind] then return { ok = false, code = 'invalid_layout' } end
    local ok, err = Layout.save(kind, data, Integrations.getCitizenId(source))
    if not ok then return { ok = false, code = err } end
    Integrations.log(source, 'layout_save', ('%s salvou o layout "%s"'):format(Integrations.getName(source), kind))
    return { ok = true, snapshot = Layout.snapshot() }
end)

lib.callback.register('noir_police:server:editorReset', function(source, kind)
    if not isAdmin(source) then return { ok = false, code = 'not_admin' } end
    local ok, err = Layout.save(kind, nil)
    if not ok then return { ok = false, code = err } end
    Integrations.log(source, 'layout_reset', ('%s voltou o layout "%s" para o config'):format(Integrations.getName(source), kind))
    return { ok = true, snapshot = Layout.snapshot() }
end)
