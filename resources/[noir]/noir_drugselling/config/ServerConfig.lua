ServerConfig = {}
ServerConfig.LogsWebhook = "" -- Discord webhook.
-- Distância máxima, vista pelo servidor, entre o vendedor e o ped da venda. Não é o alcance
-- da negociação (esse é `Config.DealLimits.MaxDistance`, conferido no cliente): no Enhanced o
-- servidor fica com a posição velha do ped de rua, a de onde ele surgiu (medido: 65–88 m para
-- um ped encostado no vendedor). Aqui só se barra ped fora da área, do outro lado do mapa.
ServerConfig.CustomerMaxDistance = 200.0
-- Preço pela polícia em serviço: vender sem polícia na rua é livre, mas paga bem menos.
-- Vale para toda droga, do saquinho ao tijolo. A faixa é a de maior `minimumPolice` que a
-- contagem alcança. A contagem é a do noir_police, a mesma do placar; sem resposta dele,
-- conta como zero.
ServerConfig.PolicePrice = {
    { minimumPolice = 0, multiplier = 0.5 },
    { minimumPolice = 1, multiplier = 1.0 },
    { minimumPolice = 3, multiplier = 1.2 },
}
-- Chamado da polícia na venda fechada, decidido no servidor (o cliente não escolhe se avisa).
-- A chance começa em `baseChance` e sobe `stepPerSale` a cada venda recente no mesmo ponto
-- (raio `radius`, últimos `windowSeconds`), até `maxChance`. Comprador cujo tipo tem
-- `dispatchCall = false` (Config.PedTypes) nunca chama. O chamado vai pelo bgrz_core: MDT
-- com código e prioridade, e aviso com blip para quem está na rua. A posição sai com um
-- desvio de até `jitter` metros: o 190 sabe o quarteirão, não o vendedor.
ServerConfig.StreetDispatch = {
    baseChance = 5,
    stepPerSale = 2.5,
    maxChance = 15,
    radius = 100.0,
    windowSeconds = 30 * 60,
    jitter = 25.0,
    code = '10-66',
    title = 'Venda de droga',
    message = 'Movimento suspeito de venda de droga na rua',
    priority = 3,
    duration = 300,
    jobs = { 'police', 'bcso', 'sasp' },
}
