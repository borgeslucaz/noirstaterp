---Boot do servidor: banco, layout e depois os módulos. A ordem importa: os módulos
---leem o layout, e fleet vem antes de equipment e surveillance (que o usam por require).

local Storage = require 'server.storage'
local Layout = require 'server.layout'

local modules = {
    'server.modules.restraint',
    'server.modules.duty',
    'server.modules.evidence',
    'server.modules.seizure',
    'server.modules.fleet',
    'server.modules.field',
    'server.modules.equipment',
    'server.modules.surveillance',
    'server.modules.editor',
}

CreateThread(function()
    local migrated, err = pcall(Storage.migrate)
    if not migrated then lib.print.error(('[noir_police] migration falhou: %s'):format(err)) end
    Layout.load()

    for _, name in ipairs(modules) do
        local ok, loadErr = pcall(require, name)
        if not ok then lib.print.error(('[noir_police] falha ao carregar %s: %s'):format(name, loadErr)) end
    end
end)
