ServerConfig = {}
ServerConfig.LogsWebhook = "" -- Discord webhook.
-- Distância máxima, vista pelo servidor, entre o vendedor e o ped da venda. Não é o alcance
-- da negociação (esse é `Config.DealLimits.MaxDistance`, conferido no cliente): no Enhanced o
-- servidor fica com a posição velha do ped de rua, a de onde ele surgiu (medido: 65–88 m para
-- um ped encostado no vendedor). Aqui só se barra ped fora da área, do outro lado do mapa.
ServerConfig.CustomerMaxDistance = 200.0
