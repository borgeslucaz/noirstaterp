# Hotfixes pendentes

## FiveM Enhanced: crash ao finalizar consumíveis com prop

- **Status:** pendente — não aplicar sem nova validação no Enhanced.
- **Impacto:** o cliente pode encerrar aleatoriamente ao consumir itens que
  usam `lib.progressBar` com prop, como `burger` e `water`.
- **Evidência:** o dump `25e58078-4798-4bc9-ad95-456ec1281952.dmp` registrou
  `0xc0000005` (leitura de ponteiro inválido) dentro de `GTA5_Enhanced.exe`.
  O FiveM Enhanced tem um bug triado para crashes quando `DeleteEntity` é
  chamado dentro de um callback de state bag.
- **Caminho atual:** `ox_inventory` inicia a barra de progresso; `ox_lib`
  replica `lib:progressProps` por state bag e remove o prop com `DeleteEntity`
  em `resources/[ox]/ox_lib/resource/interface/client/progress.lua`.
- **Hotfix proposto:** no handler de `lib:progressProps`, retirar o prop da
  tabela imediatamente, mas executar o `DeleteEntity` no frame seguinte
  (`CreateThread` + `Wait(0)`). A lista de props deve ser capturada antes da
  espera para que um novo prop do mesmo jogador não seja removido por engano.
- **Não fazer:** remover animações/props dos alimentos ou modificar a lógica
  do `ox_inventory`; o problema é uma falha nativa do Enhanced, não uma receita
  específica.
- **Referência:** https://github.com/citizenfx/rfc/discussions/489
