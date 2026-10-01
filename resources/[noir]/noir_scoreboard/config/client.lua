return {
    -- Tecla padrão. O nome do atalho é `scoreboard`, o mesmo do qbx_scoreboard: quem já
    -- tinha trocado a tecla nas configurações do FiveM continua com a dele.
    openKey = 'HOME',
    -- true: abre e fecha no toque. false: fica aberto enquanto a tecla estiver segurada.
    toggle = true,

    -- Distância dos números acima da cabeça dos jogadores próximos.
    visibilityDistance = 10,

    -- Quem vê o número acima da cabeça:
    --   'all'            todos veem o de todos;
    --   'admin_only'     só admin em serviço (opt-in) vê;
    --   'admin_excluded' todos veem, menos o número de admin em serviço.
    idVisibility = 'admin_only',
}
