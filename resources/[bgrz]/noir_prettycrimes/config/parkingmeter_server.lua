---Parquímetro — configuração que o cliente NÃO recebe.
---
---Este arquivo não está em `files{}` do manifest, então ele nunca é enviado ao
---jogador. É onde ficam as coisas que o §19.1 do SCRIPT_GOOD_PRACTICES manda manter
---fora do shared: recompensa real, regra anti-exploit, áreas aceitas e limites.
---
---**Leia `areas` e `maxPerHour` antes de mexer em qualquer outra coisa.** Eles são
---a defesa deste crime, e o motivo está escrito lá.

return {
    -- =======================================================================
    -- Onde existe parquímetro
    -- =======================================================================
    --
    -- O servidor NÃO consegue ver prop de mapa: ele não existe do lado de cá, e
    -- não há entidade para resolver. Quando o client diz "estou arrombando o
    -- poste em tal coordenada", o servidor não tem como conferir que há um poste
    -- ali. O que ele consegue conferir é tudo em volta: que o JOGADOR está
    -- naquela coordenada (posição server-side), que ela cai numa área onde
    -- parquímetro existe, e quantos o jogador já arrombou na última hora.
    --
    -- Estas esferas são a allowlist grossa do §7.4 aplicada ao que dá para
    -- aplicar. Elas cobrem a cidade; fora delas o pedido é recusado, o que tira
    -- do mapa o cheater que quer arrombar postes imaginários no meio do deserto,
    -- sozinho, sem ninguém para ver.
    --
    -- Elas NÃO impedem quem está numa rua com postes de verdade de inventar
    -- coordenadas vizinhas. Quem fecha essa porta é o `maxPerHour`: com teto por
    -- hora, o cheater ganha no máximo o que um jogador honesto ganharia achando
    -- a mesma quantidade de postes. Ele economiza a caminhada, não o dinheiro.
    --
    -- Para fechar de vez, preencha `positions` (logo abaixo).
    areas = {
        { coords = vec3(180.0, -900.0, 30.0), radius = 700.0 },    -- Legion / Pillbox / centro
        { coords = vec3(300.0, 200.0, 90.0), radius = 700.0 },     -- Vinewood / Hawick
        { coords = vec3(-600.0, -100.0, 40.0), radius = 700.0 },   -- Rockford Hills / Burton
        { coords = vec3(-1300.0, -900.0, 12.0), radius = 800.0 },  -- Del Perro / Vespucci
        { coords = vec3(-600.0, -1000.0, 20.0), radius = 600.0 },  -- Little Seoul / Textile
        { coords = vec3(1100.0, -600.0, 57.0), radius = 700.0 },   -- Mirror Park / East LS
        { coords = vec3(800.0, -1600.0, 30.0), radius = 600.0 },   -- La Mesa / Cypress Flats
        { coords = vec3(-1200.0, -400.0, 35.0), radius = 500.0 },  -- Morningwood
    },

    -- Allowlist ESTRITA, por poste. Vazia, só as áreas acima valem.
    --
    -- Preenchida, ela passa a ser a única palavra: uma chave que não estiver aqui
    -- é recusada, e o crime deixa de aceitar coordenada inventada. As chaves são
    -- as que `Rules.meterKey` produz, e o jeito de levantá-las é o comando de
    -- debug `/dumpmeters`, que imprime no console do jogador as chaves de todos
    -- os postes carregados em volta dele. Rode por alguns bairros, junte a saída
    -- e cole aqui.
    --
    -- Elas dependem do `gridSize` de `config/parkingmeter.lua`: mudar aquele
    -- número invalida esta lista.
    positions = {
        -- ['360:-1800:58'] = true,
    },

    -- =======================================================================
    -- Ferramenta
    -- =======================================================================

    tool = {
        -- Nenhuma ferramenta -> nenhum arrombamento. A conferência é SERVER-SIDE,
        -- pelo bgrz_core: o `items` do ox_target só esconde a opção da tela, e
        -- esconder não é impedir.
        required = true,

        -- Qualquer um destes serve. A lista é uma lista de propósito: dá para
        -- acrescentar uma pé-de-cabra ou um kit melhor sem tocar em código.
        --
        -- `screwdriver` é o item deste servidor, e a descrição dele no
        -- ox_inventory já fala em "prying coin boxes". Não use
        -- `screwdriverset`: ele aparece em `data/items.lua` mas não está em uso
        -- aqui, e um item inexistente faria a checagem recusar todo mundo — em
        -- silêncio, porque `GetItemCount` de item que não existe é zero, não erro.
        items = { 'screwdriver' },

        -- Chance de a ferramenta quebrar e ser consumida no fim de um
        -- arrombamento bem-sucedido. 0 desliga.
        breakChance = 0.08,
    },

    -- =======================================================================
    -- Limites
    -- =======================================================================

    -- Quanto tempo um poste esvaziado fica vazio, em SEGUNDOS.
    --
    -- Em segundos e com `os.time` porque é a única duração deste módulo que
    -- precisa fazer sentido em escala de meia hora; o resto é `GetGameTimer`
    -- (§9.4). Não persiste entre restarts, e isso está no README.
    meterCooldown = 1800,

    -- Espera mínima entre dois arrombamentos CONCLUÍDOS do mesmo jogador, em
    -- SEGUNDOS.
    --
    -- Conta a partir do que deu certo, e não da tentativa. É uma distinção que
    -- custa uma linha e muda o jogo: com o cooldown na tentativa, esbarrar num
    -- poste que outro já esvaziou custaria ao jogador o minuto inteiro, sem ele
    -- ter feito nada. O anti-spam de evento é outra trava, bem mais curta, em
    -- `attemptInterval`.
    --
    -- Em segundos porque sai do mesmo relógio do teto por hora (`os.time`).
    playerCooldown = 45,

    -- Anti-spam de evento, em MILISSEGUNDOS. Este é cobrado em toda tentativa,
    -- inclusive nas recusadas — senão a recusa vira o caminho barato para
    -- martelar o servidor. O piso real é o `rateLimit.default` de
    -- `config/server.lua`.
    attemptInterval = 1500,

    -- Teto por jogador numa janela deslizante. É o limite que realmente segura a
    -- economia — e o que torna inútil inventar coordenada.
    maxPerHour = 8,
    -- Tamanho da janela do teto, em SEGUNDOS.
    heatWindow = 3600,

    -- Quanto tempo uma reserva sobrevive sem confirmação (ms). Cobre o jogador
    -- que desconecta ou trava no meio da animação. Deixe acima da soma das duas
    -- barras (`pryDuration` + `collectDuration`).
    reservationTimeout = 20000,

    -- Fração da soma das duas barras que precisa ter passado entre reservar e
    -- entregar.
    --
    -- Sem isto, quem chama os eventos à mão reserva e entrega no mesmo instante,
    -- pulando as animações inteiras. 0.8 dá folga para lag e para o
    -- arredondamento do progresso, sem deixar o roubo virar um clique.
    minElapsedFactor = 0.8,

    -- =======================================================================
    -- Recompensa
    -- =======================================================================
    --
    -- É moeda de parquímetro. Continua sendo petty crime: o valor precisa ser
    -- menor que o risco de tomar um 10-35 no meio da calçada.

    reward = {
        -- Dinheiro, sempre. Vai para `cash`, que é onde moeda faz sentido.
        money = { account = 'cash', min = 25, max = 90 },

        -- Itens extras, cada um com sua rolagem independente (0..1).
        --
        -- Vazio de propósito. Caixa de parquímetro tem moeda, e mais nada — o
        -- gancho existe para quem quiser um item de evento ou uma ficha de
        -- lavanderia, não porque falte alguma coisa aqui.
        --
        -- Não devolva a própria ferramenta como loot: com `tool.items` e este
        -- campo apontando para o mesmo item, o crime passa a se financiar e a
        -- exigência de ferramenta deixa de custar qualquer coisa.
        items = {
            -- { item = 'lockpick', min = 1, max = 1, chance = 0.04 },
        },
    },

    dispatch = {
        chance = 0.20,
        code = '10-35',
        -- Quando o alerta sai:
        --   'reserved' = quando o jogador começa a forçar (o momento suspeito)
        --   'claimed'  = só depois de levar as moedas
        --   'both'     = nos dois, cada um com sua rolagem
        trigger = 'reserved',
    },

    -- Chave da activity no noir_illegal_core (só com progression ligada).
    progressionActivity = 'petty_parkingmeter',
}
