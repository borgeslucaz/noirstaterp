-- Saída dos comandos de administração, e o diagnóstico do caminho que o menu da gang usa.

---O servidor manda linhas prontas; aqui elas só aparecem. Vai para o F8 porque o relatório do
---`/territoryinfo` tem uma linha por gang e não caberia numa notificação.
RegisterNetEvent('noir_territories:client:adminSay', function(lines)
    if type(lines) ~= 'table' then return end
    for i = 1, #lines do print(tostring(lines[i])) end
end)

---Exercita exatamente o que o menu do noir_gangs chama, e conta o que voltou.
---
---Aquele lado envolve a chamada num `pcall`, então um erro nosso vira "o controle de
---territórios está fora do ar" na tela dele em vez de aparecer. Já escondeu um crash real —
---o `os.time()` que não existe no cliente. Este comando tira o pcall da frente.
RegisterCommand('territoryping', function()
    local ok, data = pcall(function() return exports.noir_territories:GetTerritoryMap() end)

    if not ok then
        return print(('[noir_territories] GetTerritoryMap ESTOUROU: %s'):format(tostring(data)))
    end

    if type(data) ~= 'table' or type(data.zones) ~= 'table' then
        return print('[noir_territories] GetTerritoryMap devolveu algo que não é o esperado')
    end

    local donos, travados, desafiados = 0, 0, 0
    for _, zone in ipairs(data.zones) do
        if zone.gang then donos = donos + 1 end
        if zone.lockedUntil and zone.now and zone.lockedUntil > zone.now then
            travados = travados + 1
        end
        if zone.challenger then desafiados = desafiados + 1 end
    end

    print(('[noir_territories] ping: %d bairros | %d com dono | %d travados | %d sob desafio')
        :format(#data.zones, donos, travados, desafiados))
    print(('    relogio do servidor: %s | tiles: %s'):format(
        data.zones[1] and tostring(data.zones[1].now) or 'sem bairro',
        data.map and tostring(data.map.tiles) or 'sem projecao'))
end, false)
