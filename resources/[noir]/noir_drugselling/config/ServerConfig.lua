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
