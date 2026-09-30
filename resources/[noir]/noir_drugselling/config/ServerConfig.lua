ServerConfig = {}
ServerConfig.LogsWebhook = "" -- Discord webhook.
-- Grau da droga (noir_weed grava `grade` no metadata do saquinho). O grau multiplica o
-- preço da venda; a venda sai do slot de melhor grau. Droga sem grau conta como `default`.
ServerConfig.Grades = {
    multiplier = { C = 0.8, B = 1.0, A = 1.25, S = 1.5 },
    default = 'B',
}

-- Distância máxima, vista pelo servidor, entre o vendedor e o ped da venda. Não é o alcance
-- da negociação (esse é `Config.DealLimits.MaxDistance`, conferido no cliente): no Enhanced o
-- servidor fica com a posição velha do ped de rua, a de onde ele surgiu (medido: 65–88 m para
-- um ped encostado no vendedor). Aqui só se barra ped fora da área, do outro lado do mapa.
ServerConfig.CustomerMaxDistance = 200.0
