Config = Config or {}

-- Quem pode usar os comandos de administração de território (`server/admin.lua`). O mesmo
-- arranjo do noir_graffiti e do noir_gangs: a permissão é declarada no `permissions.cfg` do
-- servidor, e o resource só pergunta.
Config.AdminAce = 'noir.territoryadmin'

-- Ferramenta de ajuste, não de jogo: desenha no mundo um pino no centro exato de cada tag por
-- perto. Nada disso vai para o mapa — território se olha pelo /territorymap.
-- O comando /territorydebug liga e desliga sem reiniciar.
Config.DebugTerritories = false

-- ---------------------------------------------------------------------------
-- Influência
-- ---------------------------------------------------------------------------
-- Cada bairro tem um pool fixo de pontos. As gangs dividem esse pool entre si, e o que
-- ninguém tomou é neutro — bairro virgem é `Total` de neutro e nada mais. A aritmética e o
-- porquê do pool ser fechado estão no cabeçalho de `shared/influence.lua`.
--
-- `RequiredPercent` é maioria, não metade: 51% do pool. Dois donos simultâneos deixam de ser
-- possíveis por aritmética — 510 + 510 passa de 1000 —, e não por regra escrita.
--
-- `Rates` é quanto cada fato do mundo vale em influência. Quem faz o fato não escolhe o
-- número: o noir_graffiti avisa que uma tag nasceu, o noir_drugselling avisa que uma venda
-- fechou, e é aqui que se decide o que isso significa no mapa. Um resource novo entra
-- acrescentando uma linha nesta tabela, e não um `addInfluence(zone, gang, 40)` solto no meio
-- do código dele.
--
-- 75 por tag põe o bairro em sete tags (525 de 1000), contra as cinco do modelo de contagem
-- que existia antes. É mais caro de propósito: a tag deixou de ser a única moeda.
-- `Underdog` é a rampa de entrada de quem chega depois. Uma atividade vale mais quanto maior
-- for a distância entre quem age e a gang que lidera o bairro:
--
--     ganho = base × (1 + 1.5 × (fatia do líder − sua fatia))
--
-- Contra uma gang com 800, quem tem 100 ganha 21 por atividade em vez de 10; empatados em 500,
-- os dois ganham 10. O bônus se desliga sozinho ao chegar em cima, e o líder nunca o recebe —
-- não é muleta permanente, é o que separa "a gang nova é irrelevante" de "a gang nova
-- incomoda". Medido: contra um dono que trabalha o bairro na mesma frequência, sem o bônus a
-- gang nova empaca em 100 de 1000; com ele, chega a 463.
--
-- Vale só para atividade (`grantInfluence`). `addInfluence` com número na mão é ferramenta de
-- administração e não leva bônus: quem digita 40 quer 40.
-- TODO: Ajeitar os valores para produção.
--
-- `drug_sale` está em 150 para teste: com o limiar em 510, quatro vendas viram um bairro — o
-- que permite exercitar tomada e trava em minutos em vez de uma hora. O valor de jogo é 10, que
-- é o que faz uma venda ser um empurrão e não um golpe.
Config.Influence = {
    Total = 1000,
    RequiredPercent = 51,
    Underdog = 1.5,
    Rates = {
        graffiti = 75,
        drug_sale = 150,
    },
}

-- ---------------------------------------------------------------------------
-- Trava de domínio
-- ---------------------------------------------------------------------------
-- Quanto tempo um bairro fica intocável depois de trocar de dono. Durante a trava o bairro está
-- protegido: o dono não perde ponto nenhum e só ele ganha. Venda e tag de qualquer outra gang
-- ali não rendem nada — sem isto a trava seguraria só o nome na placa, e o rival passaria as
-- quatro horas esvaziando o dono para tomar no primeiro minuto depois dela.
--
-- Existe porque bairro que troca de mão toda hora não é território, é placar. Com a trava, uma
-- gang que tomou a rua tem uma tarde inteira de posse garantida para fazer alguma coisa com
-- ela, e quem quer de volta precisa chegar aos 51% e segurar até a trava cair.
Config.OwnershipLockSeconds = 4 * 60 * 60

-- ---------------------------------------------------------------------------
-- Bairros fixos
-- ---------------------------------------------------------------------------
-- Nem todo bairro mapeado está em jogo. Bairro fixo ignora graffiti: por mais tags que uma
-- gang ponha lá dentro, o dono não muda. É o que separa o que se toma na rua do que é
-- cenário — porto, aeroporto, delegacia, a mansão de alguém.
--
-- O valor diz de quem ele é:
--     ['vinewood_hills'] = true       -- fixo e de ninguém: neutro para sempre
--     ['grove_street']   = 'families' -- fixo e sempre dos Families, sem ter de pichar
--
-- Bairro que não estiver nesta lista é conquistável, e isso é de propósito: desenhar um
-- bairro novo no Zone Manager já o põe em disputa, sem passar por aqui. Quem quiser tirá-lo
-- do jogo diz isso em voz alta, nesta tabela.
--
-- Mora aqui, e não no `zones.json` do Zone Manager: aquele arquivo é reescrito inteiro pelo
-- editor dele a cada save, e o campo sumiria sem erro nenhum. Fora isso, o que é disputa e o
-- que é cenário é regra deste resource — o Zone Manager só sabe desenhar polígono.
Config.FixedZones = {}

-- ---------------------------------------------------------------------------
-- Cores
-- ---------------------------------------------------------------------------
-- RGB puro: nada mais aqui desenha blip, e blip era a única coisa que precisava de índice de
-- paleta. A tela do /territorymap e os marcadores no chão usam a cor exata.
Config.Colors = {
    vermelho = { r = 224, g = 50,  b = 50  },
    verde    = { r = 114, g = 204, b = 114 },
    azul     = { r = 93,  g = 182, b = 229 },
    amarelo  = { r = 240, g = 200, b = 80  },
    laranja  = { r = 255, g = 133, b = 85  },
    roxo     = { r = 190, g = 120, b = 255 },
    rosa     = { r = 255, g = 102, b = 178 },
    cinza    = { r = 155, g = 155, b = 155 },
}

-- Cor de cada gang.
--
-- O servidor não guarda cor de gang em lugar nenhum: nem o `qbx_core/shared/gangs.lua` nem o
-- `noir_gangs` têm esse campo. Então ela mora aqui, e segue as cores clássicas de cada uma —
-- as mesmas dos atalhos de cor do noir_graffiti.
--
-- Gang que não estiver nesta lista ganha uma cor estável tirada do próprio nome: nada quebra
-- quando uma gang nova é criada, ela só cai onde calhar até alguém escolher aqui.
Config.GangColors = {
    ballas    = 'roxo',
    families  = 'verde',
    vagos     = 'amarelo',
    lostmc    = 'cinza',
    cartel    = 'laranja',
    triads    = 'vermelho',
    marabunta = 'azul',
}

-- ---------------------------------------------------------------------------
-- Projeção do mapa
-- ---------------------------------------------------------------------------
-- Onde o (0,0) do jogo cai na pirâmide de tiles. Os números vêm do PolyZoneCreator e não
-- são ajustáveis a olho: são eles que fazem o polígono cair em cima da rua certa.
--
-- Moram aqui, e não no JavaScript da página, porque já existe mais de uma tela desenhando
-- este mesmo mapa — o `/territorymap` e o menu do `noir_gangs`. Duas cópias das constantes
-- divergiriam no dia em que os tiles fossem trocados, e a que divergisse desenharia a
-- fronteira certa sobre a rua errada, sem erro nenhum no console.
--
-- Quem consome de fora não lê esta tabela: pede `GetTerritoryMap`, que já devolve o
-- caminho dos tiles resolvido para o nome real do resource.
Config.Map = {
    tilesPath = 'web/tiles/{z}/{x}/{y}.png',
    maxZoom = 7,
    maxNativeZoom = 4,
    maxResolution = 0.25,
    centerLat = -5525,
    centerLng = 3755,
    offset = 0.66,
}
