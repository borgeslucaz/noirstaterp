Config = {}

Config.AdminAce = 'noir.graffitiadmin'

-- Desliga o desenho das tags, mantendo os DUIs nascendo, recebendo conteúdo e sendo
-- reaproveitados. Serve para separar "o crash é a nossa textura" de "o crash é de outro
-- lugar", e o /graffitidraw liga e desliga em jogo sem reiniciar nada.
Config.Debug = {
    noDraw = false,
}

Config.Items = {
    spray = 'spraycan',
    remover = 'sprayremover',
    uses = 5, -- Usos por lata, guardados em metadata.uses.
}

Config.Text = {
    minLength = 2,
    -- Conta caracteres visíveis, sem as quebras. Curto de propósito: fonte larga estoura
    -- a parede muito antes de encher a textura, e quem quiser texto longo empilha linhas.
    maxLength = 12,
    maxLines = 3,
}

-- `id` é o nome da família tipográfica declarada nos @font-face de web/ui.html e de
-- web/scene.html, e é o que vai para a coluna `font` do banco. Mudar um id sem mudar os
-- dois CSS derruba a fonte no fallback (Arial) e quebra os graffitis já gravados.
-- `label` é só o que o jogador lê no botão.
Config.Fonts = {
    { id = 'Mostwasted', label = 'Mostwasted' },
    { id = 'Drippin', label = 'Drippin' },
    { id = 'Wreckin', label = 'Wreckin' },
    { id = 'Ghang', label = 'Ghang' },
    { id = 'Ghang Plain', label = 'Ghang Plain' },
    { id = 'Bubble', label = 'Bubble' },
    { id = 'Whoa', label = 'Whoa' },
    { id = 'Marsneveneksk', label = 'Marsneveneksk' },
    { id = 'Urban Calligraphy', label = 'Urban Calligraphy' },
    { id = 'Creepster', label = 'Creepster' },
    { id = 'Help Me', label = 'Help Me' },
    { id = 'Quantico', label = 'Quantico' },
    { id = 'Geist', label = 'Geist' },
}

-- Espessura do traço, escolhida pelo jogador. É desenhada como contorno na cor do próprio
-- texto, e não como font-weight: a maioria destas fontes tem um peso só, e pedir negrito
-- a elas faz o CEF fabricar um falso-negrito borrado. O contorno engorda a letra de forma
-- contínua e funciona igual em todas.
Config.Thickness = {
    min = 0,
    max = 24,
    default = 0,
    step = 1,
}

-- Atalhos de cor na NUI. Não são uma restrição: o picker aceita qualquer hex.
Config.ColorPresets = {
    { label = 'Ballas', color = '#74449A' },
    { label = 'Families', color = '#3E8B52' },
    { label = 'Vagos', color = '#D4C22F' },
    { label = 'Marabunta', color = '#5096D2' },
    { label = 'Lost MC', color = '#B4B4B4' },
    { label = 'Sangue', color = '#B02020' },
    { label = 'Branco', color = '#FFFFFF' },
    { label = 'Preto', color = '#101010' },
}
Config.DefaultColor = '#FFFFFF'

Config.Placement = {
    maxDistance = 4.0,
    wallOffset = 0.005, -- Afastamento da parede, para o sprite não brigar com a textura.
    -- Quanto a superfície sob cada canto pode divergir do plano onde o graffiti está,
    -- como produto escalar entre as normais: 0.95 são ~18 graus. Abaixo disso a sonda
    -- está encostando em outra face — quina interna, pilar redondo, parede curva.
    minSurfaceAlignment = 0.95,
    maxWallNormalZ = 0.75, -- |normal.z| acima disso é chão ou teto, não parede.
    minScale = 0.5,
    maxScale = 2.5,
    defaultScale = 1.0,
    scaleStep = 0.1, -- Por clique da roda do mouse.
    rotationSpeed = 60.0, -- Graus por segundo segurando Q/E.
    moveSpeed = 0.6, -- Metros por segundo segurando as setas.
    maxSide = 0.5, -- Quanto o graffiti desliza para cada lado do ponto mirado.
    -- Altura medida a partir do personagem, não do ponto mirado: é isso que impede
    -- pichar o alto do prédio mirando lá de baixo. A referência é a posição do ped, que
    -- fica nos pés, e a faixa é assimétrica de propósito — graffiti de parede vive acima
    -- da cintura, então sobra mais espaço para cima do que para baixo.
    maxHeightUp = 1.3,
    maxHeightDown = 0.8,
    -- Distância máxima entre o jogador e o centro do graffiti. É esta regra, e não o
    -- limite por eixo, que impede pichar uma parede a 20m de altura a partir do chão:
    -- mirar longe já gasta quase todo o alcance, então sobra pouco para deslizar.
    -- Fica acima do maxDistance para ainda dar folga de ajuste em quem mirou no limite.
    maxReach = 5.0,
    cooldownSeconds = 30,
    minimumDistance = 2.0, -- Distância mínima entre dois graffitis.
    duration = 5000,
}

Config.Render = {
    distance = 60.0,
    unloadDistance = 75.0,
    -- Teto de instâncias de CEF vivas, e também o tamanho do pool: renderer pronto não é
    -- mais destruído, só devolvido para reuso. Nascer e morrer é o caro, ficar vivo não é.
    -- A prévia do posicionamento entra no mesmo teto, tomando emprestado o renderer do
    -- graffiti mais distante quando não sobra vaga.
    --
    -- Cada instância é um navegador inteiro. O upstream roda 25 destas sem reclamar, então o
    -- gargalo nunca foi a quantidade — era criar a textura antes de o CEF entregar a
    -- superfície.
    --
    -- É este número que decide quantas tags aparecem de uma vez num mesmo lugar: com menos
    -- vagas que tags na área, as mais distantes ficam sem desenhar até o jogador chegar
    -- perto. Se uma parede cheia estiver aparecendo pela metade, é aqui que se mexe.
    maxActive = 16,
    width = 1024,
    height = 512,
    worldWidth = 2.5, -- Largura do graffiti no mundo, em metros.
}

Config.Remove = {
    useDistance = 2.5, -- Alcance do removedor: pega o graffiti mais próximo dentro disto.
    serverDistance = 3.0,
    duration = 5000,
}

---Proporção largura/altura do quad no mundo. É a mesma da textura, e é justamente isso que
---impede o texto de sair distorcido: a página encaixa a letra dentro da textura sem esticar
---nada, e o quad mostra a textura inteira na proporção em que ela foi desenhada. A sobra em
---volta da letra é transparente, então o jogador não vê diferença — e nada precisa ser
---medido, confirmado ou estimado para o formato sair certo.
Config.Render.aspect = Config.Render.width / Config.Render.height
