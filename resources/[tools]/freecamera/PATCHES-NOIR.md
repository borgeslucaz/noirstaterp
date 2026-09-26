# Alterações locais no freecamera

Upstream: https://github.com/LemonsDropsLemon/FiveM-Free-Camera, commit `806dcf1`
(2026-06-02, "updated freecam"). Ao atualizar o resource, reaplicar o que está aqui.

## 1. `/freecam` liberado para todos (como no upstream)

Chegou a ser restrito por ACE (`restricted = true`), mas o comando não aparecia em jogo e a
decisão foi deixar aberto. Risco conhecido e aceito: câmera livre de 400 m atravessa parede e
interior, e dentro dela há direção automática do carro (`TaskVehicleDriveWander`). Para fechar
de novo: `RegisterCommand(..., true)` em `client.lua` e o ACE `command.freecam`.

## 2. `/capturarcena` (`noir_capturarcena.lua`, arquivo nosso)

Monta o bloco de uma cena nova para `Config.CharacterSelection` do noir_multichar: posição e
heading do ped, câmera que está na tela (posição, rotação, FOV), clima, hora e o último carro
se estiver a menos de 20 m. Imprime no F8 e copia para a área de transferência.

Mora aqui e não no noir_multichar porque é com o freecam que a cena é enquadrada, e reiniciar
este resource é mais leve. Liberado para todos (só lê coordenadas). Por causa dele o manifest
ganhou `@ox_lib/init.lua` (clipboard e notify).
