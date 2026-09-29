---Parquímetro — arrombar a caixa de moedas de um poste na calçada.
---
---A diferença entre este crime e o smash & grab não é o tema, é a **entidade**. O
---veículo do smash & grab é uma entidade de rede: tem netId, existe no servidor,
---aceita state bag. O parquímetro é prop de MAPA — ele não foi criado por ninguém,
---não existe no servidor, e o handle local muda toda vez que o streaming recarrega
---a região. Nada disso serve como identidade.
---
---O que sobra, e é o que o módulo usa: a **coordenada**. Prop de mapa não anda, e
---a posição dele é idêntica em todos os clients. Arredondada para uma grade, ela
---vira uma chave estável que os dois lados calculam igual — é o `meterKey` de
---`shared/parkingmeter_rules.lua`, e é por ela que o servidor sabe qual poste já
---foi esvaziado.
---
---**Este arquivo É enviado ao cliente** (está em `files{}`). O que decide
---recompensa, área permitida, cooldown e teto por jogador mora em
---`config/parkingmeter_server.lua`, que não é enviado (§19.1).

return {
    -- =======================================================================
    -- Os postes
    -- =======================================================================

    -- Models do parquímetro no jogo base. Conferidos contra a lista de objetos
    -- do `ps_lib` (`modules/streamed_assets/shared/objectList.lua`).
    --
    -- O target é registrado POR MODEL no ox_target, via bgrz_core: não há
    -- varredura de pool de objetos, nenhuma thread, e postes que entram no
    -- streaming depois já nascem com a opção.
    models = {
        'prop_parknmeter_01',
        'prop_parknmeter_02',
    },

    -- Lado da célula da grade que transforma coordenada em identidade, em metros.
    --
    -- Prop de mapa é estático, então na prática dois clients leem exatamente a
    -- mesma coordenada e qualquer grade funcionaria. A grade existe para o caso
    -- em que não funcionam: ruído de float e o eventual poste que algum MLO põe
    -- meio metro fora do lugar. Meio metro é folgado o bastante para absorver
    -- isso e apertado o bastante para que dois postes vizinhos — que no mapa
    -- ficam a metros de distância — nunca caiam na mesma célula.
    --
    -- Mudar este número reinicia a memória de quais postes foram esvaziados: as
    -- chaves antigas deixam de bater. Não é destrutivo, só é um reset.
    gridSize = 0.5,

    -- Distância do alvo do ox_target ao poste.
    targetDistance = 1.6,

    -- Distância máxima aceita durante a ação. Vale no client (cancela a barra) e
    -- no servidor (recusa a reserva e a entrega). Mais folgada que a do target
    -- porque a coordenada do jogador no servidor e a no client divergem um pouco.
    maxDistance = 3.0,

    -- Teto de espera por resposta do servidor (ms), para TODO callback.
    -- `lib.callback.await` sem prazo espera para sempre; o §13.3 não permite.
    callbackTimeout = 5000,

    -- =======================================================================
    -- O roubo
    -- =======================================================================

    -- São dois gestos, como no smash & grab: forçar a fechadura e depois recolher
    -- as moedas. O primeiro é o que compromete o jogador; o segundo é o que paga.

    -- Minigame da fechadura. `lib.skillCheck` do ox_lib, que já é dependência —
    -- nenhum provider novo entra por causa disto.
    --
    -- `false` desliga o minigame e deixa só as barras de progresso.
    skillCheck = {
        enabled = true,
        -- Uma rodada por dificuldade, na ordem. Aceita 'easy', 'medium', 'hard'
        -- ou tabela `{ areaSize, speedMultiplier }`.
        difficulty = { 'easy', 'easy', 'medium' },
        -- Teclas aceitas em cada rodada.
        keys = { 'w', 'a', 's', 'd' },
    },

    -- Duração da barra de forçar a fechadura (ms).
    pryDuration = 4000,

    -- Duração da barra de recolher as moedas (ms).
    collectDuration = 3000,

    -- Animações.
    --
    -- Duas coisas diferentes podem dar errado aqui, e falham de formas diferentes:
    --
    --   * dicionário ausente -> o módulo confere com DoesAnimDictExist e roda a
    --     barra SEM animação, deixando um aviso no console. Não derruba o cliente
    --     (que é o que aconteceria se o nome passasse direto ao jogo);
    --   * clip errado dentro de um dicionário que existe -> silêncio total: a
    --     barra roda, o personagem não faz nada, e nada é logado.
    --
    -- `anim@gangops@facility@servers@` / `hotwire` é o "mexendo num painel" do
    -- jogo base, o mesmo que o cbd-meters usa, e serve para os dois gestos: de
    -- fora, forçar a portinhola e recolher o troco têm a mesma pose. São dois
    -- campos mesmo assim porque trocar um sem trocar o outro é uma mudança que
    -- alguém vai querer fazer, e o módulo confere cada dicionário separadamente.
    pryAnim = {
        dict = 'anim@gangops@facility@servers@',
        clip = 'hotwire',
        flag = 49,
    },

    collectAnim = {
        dict = 'anim@gangops@facility@servers@',
        clip = 'hotwire',
        flag = 49,
    },

    -- =======================================================================
    -- Apresentação
    -- =======================================================================

    -- Ícone do alvo.
    icon = 'fa-solid fa-coins',

    -- Teto da duração que o client aceita para um poste esvaziado (ms).
    --
    -- Quem manda a duração é sempre o servidor; isto só impede que um número
    -- absurdo vindo de um evento esconda um poste até o restart do client.
    --
    -- **Precisa ser maior ou igual a `meterCooldown` de
    -- `config/parkingmeter_server.lua`** (que está em segundos). Menor que ele, o
    -- client passaria a mostrar o alvo antes de o servidor liberar o poste, e o
    -- jogador levaria uma recusa sem entender. O client não recebe o config de
    -- servidor e não tem como conferir isso sozinho — quem confere é
    -- `tests/unit/parkingmeter_rules_spec.lua`.
    emptiedFallback = 3600000,
}
