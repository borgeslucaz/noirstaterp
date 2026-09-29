---Configuração comum a todos os crimes, **enviada ao cliente**.
---
---Só entra aqui o que os dois lados precisam enxergar. Limite de rate limit,
---distância máxima aceita, dispatch e progressão são regra de servidor e moram em
---`config/server.lua`, que não é enviado (§19.1 do SCRIPT_GOOD_PRACTICES).

return {
    -- Liga o DebugPrint de todos os módulos. Desligado, nenhum print sai.
    -- Também é o que registra os comandos de debug: sem isto eles não existem,
    -- e o console responde "Not allowed to execute command" — que é o que o
    -- FiveM diz para comando inexistente, não para comando sem permissão.
    --
    -- Os comandos de SERVIDOR ficam atrás de `debugAce` além disto. Os de
    -- client, não: com esta flag ligada, qualquer jogador pode rodar
    -- `/dumpmeters`, que entrega o mapa dos parquímetros. É a razão principal
    -- de ela ficar desligada em produção.
    debug = false,

    -- Quais crimes o container carrega.
    --
    -- `false` não é "carrega e fica quieto": o arquivo do crime nem chega a ser
    -- lido, nem no client nem no servidor. Nenhum evento dele é registrado,
    -- nenhum target dele é criado.
    --
    -- `smashgrab` e `parkingmeter` têm módulo; o resto está no roadmap e ligar
    -- um deles faz o boot avisar que ainda não existe.
    crimes = {
        smashgrab = true,
        parkingmeter = true,
        vendingmachine = false,
        atm = false,
        streetrobbery = false,
        cardoor = false,
    },
}
