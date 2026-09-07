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
