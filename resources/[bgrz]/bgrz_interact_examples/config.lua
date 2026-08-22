Config = {}

Config.ShowBlip = true
Config.TestLocation = vector4(210.50, -812.50, 30.78, 67.0)

-- All examples are intentionally grouped around Legion Square's parking lot.
-- Set enabled = false on an entry to hide that NPC without editing client code.
Config.NPCs = {
    { id = 'guide', title = 'Guia da Praca', model = 'a_f_y_business_04', coords = vector4(215.76, -810.12, 30.73, 157.0), scenario = 'WORLD_HUMAN_CLIPBOARD', greeting = 'GENERIC_HI', speech = 'Bem-vindo a area de testes. Posso explicar o que cada pessoa demonstra.', example = 'guide' },
    { id = 'receptionist', title = 'Recepcionista', model = 's_f_y_shop_mid', coords = vector4(218.32, -808.83, 30.71, 157.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', greeting = 'GENERIC_HOWS_IT_GOING', speech = 'Este e um dialogo simples com respostas e reacoes diferentes.', example = 'simple' },
    { id = 'mechanic', title = 'Mecanico', model = 's_m_y_xmech_02', coords = vector4(220.89, -807.48, 30.68, 157.0), scenario = 'WORLD_HUMAN_HAMMERING', greeting = 'GENERIC_HI', speech = 'Quer um diagnostico demonstrativo do veiculo?', example = 'progress' },
    { id = 'vendor', title = 'Vendedora', model = 'a_f_y_business_01', coords = vector4(223.45, -806.13, 30.65, 157.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT', greeting = 'GENERIC_HI', speech = 'Escolha um valor no slider. Esta negociacao e apenas visual.', example = 'slider' },
    { id = 'recruiter', title = 'Recrutador', model = 's_m_m_highsec_01', coords = vector4(226.02, -804.78, 30.62, 157.0), scenario = 'WORLD_HUMAN_GUARD_STAND', greeting = 'GENERIC_HI', speech = 'Posso apresentar algumas carreiras em um menu com varias etapas.', example = 'nested' },
    { id = 'doctor', title = 'Paramedica', model = 's_f_y_scrubs_01', coords = vector4(228.59, -803.43, 30.59, 157.0), scenario = 'WORLD_HUMAN_CLIPBOARD', greeting = 'GENERIC_HI', speech = 'Posso fazer uma triagem ficticia e atualizar o texto desta conversa.', example = 'speech' },
    { id = 'officer', title = 'Oficial de Policia', model = 's_m_y_cop_01', coords = vector4(212.88, -808.72, 30.77, 337.0), scenario = 'WORLD_HUMAN_COP_IDLES', greeting = 'GENERIC_HI', speech = 'Area de demonstracao segura. O que deseja consultar?', example = 'police' },
    { id = 'taxi', title = 'Taxista', model = 's_m_m_gentransport', coords = vector4(215.45, -807.37, 30.74, 337.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', greeting = 'GENERIC_HOWS_IT_GOING', speech = 'Escolha um destino para simular um orcamento de corrida.', example = 'taxi' },
    { id = 'reporter', title = 'Reporter', model = 'a_f_y_business_02', coords = vector4(218.02, -806.02, 30.70, 337.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', greeting = 'GENERIC_HI', speech = 'Estamos testando entrevistas. Qual resposta combina com seu personagem?', example = 'reporter' },
    { id = 'bartender', title = 'Bartender', model = 's_m_y_barman_01', coords = vector4(220.59, -804.67, 30.67, 337.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT', greeting = 'GENERIC_HI', speech = 'O cardapio e demonstrativo: nada sera cobrado ou entregue.', example = 'bartender' },
    { id = 'instructor', title = 'Instrutor de Direcao', model = 'a_m_m_business_01', coords = vector4(223.16, -803.32, 30.64, 337.0), scenario = 'WORLD_HUMAN_CLIPBOARD', greeting = 'GENERIC_HI', speech = 'Vamos testar uma pequena prova teorica de multipla escolha.', example = 'quiz' },
    { id = 'mysterious', title = 'Desconhecido', model = 'a_m_m_og_boss_01', coords = vector4(225.73, -801.97, 30.61, 337.0), scenario = 'WORLD_HUMAN_SMOKING', greeting = 'GENERIC_CURSE_MED', speech = 'Este exemplo mostra respostas condicionais e mudanca de humor local.', example = 'relationship' }
}
