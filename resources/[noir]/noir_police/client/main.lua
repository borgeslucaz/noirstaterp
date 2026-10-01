---Boot do cliente: carrega os módulos. Cada módulo registra os próprios targets,
---eventos e limpeza no stop do resource.

local modules = {
    'client.modules.restraint',
    'client.modules.duty',
    'client.modules.evidence',
    'client.modules.station',
    'client.modules.field',
    'client.modules.equipment',
    'client.modules.surveillance',
    'client.modules.editor',
}

for _, name in ipairs(modules) do
    local ok, err = pcall(require, name)
    if not ok then lib.print.error(('[noir_police] falha ao carregar %s: %s'):format(name, err)) end
end
