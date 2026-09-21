# noir_busjob

Sistema de carreira de transporte publico para o Noir State. Substitui o `qbx_busjob` legado.

## Instalação

1. O resource executa automaticamente as instruções seguras de `migrations/001_initial.sql` ao iniciar.
2. Garanta que `bgrz_core`, `ox_lib`, `ox_target` e `oxmysql` iniciem antes de `[bgrz]`.
3. Qualquer jogador pode falar com o atendente da Central de Transporte pelo `ox_target`; nível e XP pertencem exclusivamente às tabelas deste resource.

## Fluxo

`IDLE -> DEADHEAD -> DOCKED -> BOARDING -> DEPARTING -> RETURNING_DEPOT -> PARKING -> COMPLETING -> SUMMARY`

O servidor cria, valida e finaliza cada sessão. O browser e o client enviam somente intenções. Dinheiro e XP são concedidos somente após o estacionamento no depot.

A Central usa `ox_target`. Se o jogador retornar ao atendente durante uma linha, a NUI oferece a devolução do ônibus; confirmar cancela a sessão sem recompensa e remove o veículo. As linhas são apresentadas do menor para o maior nível exigido.

O atendente recebe um blip curto no mapa, configurado em `Config.Depot.blip`. Ele some enquanto uma linha está em serviço, porque nesse período o objetivo da vez (próxima parada ou garagem) já é marcado pelo blip de rota; volta ao encerrar ou cancelar a linha. Remover a chave `blip` da config desliga o marcador.

## Interface

A NUI segue o `resources/docs/DESIGN_v3.md`, na mesma aplicação feita no `noir_taxijob`: janela de comando com rail vertical expansível à esquerda, cabeçalho com identidade e perfil, e conteúdo separado por aba.

- **Central** — saudação, métricas, progressão compacta, linha em serviço e uma prévia de até três linhas;
- **Linhas** — catálogo completo com a lista à esquerda e o detalhe (itinerário e ação) à direita;
- **Progressão** — anel de nível, barra de XP e a tabela de níveis da carreira;
- **Ranking** — `SUA POSIÇÃO` fixa acima da lista rolável.

O tema do serviço é definido em `[data-service="bus"]`, dentro de `html/main.css`. Só o acento muda entre resources; posição, largura e comportamento do rail permanecem iguais. A fonte Poppins é empacotada em `html/fonts`, sem CDN, e a barra de rolagem é estilizada uma única vez pelos pseudo-elementos `::-webkit-scrollbar` (v3 §6.5).
