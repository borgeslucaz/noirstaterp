Config = Config or {}

-- Ferramenta de ajuste, não de jogo: desenha no mundo o círculo no chão e o pino no centro
-- exato de cada tag. Nada disso vai para o mapa — território se olha pelo /territorymap.
-- O comando /territorydebug liga e desliga sem reiniciar.
Config.DebugTerritories = false

-- Quantas tags uma gang precisa ter dentro de um bairro para ser dona dele.
--
-- É fixo de propósito. Chegou a ser calculado pela área do polígono — bairro grande pedia
-- mais —, e a conta funcionava, mas a diferença entre o maior e o menor bairro mapeado é de
-- só 11x e o modelo não vale a complexidade. Consequência conhecida: bairro pequeno é barato
-- de virar, bairro grande é barato também. Se a periferia ficar instável demais, é aqui que
-- se mexe.
--
-- Este número mora aqui, e não no noir_graffiti: quem picha não decide o que é domínio.
Config.RequiredGraffiti = 5

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
-- Pintura dos bairros no mapa
-- ---------------------------------------------------------------------------
