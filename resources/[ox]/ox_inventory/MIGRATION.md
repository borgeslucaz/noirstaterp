# Migração para ox_inventory

Baseline limpo do upstream `overextended/ox_inventory` na tag `v2.47.9`
(`952c128fdff056fd7506d924faa6c07fb80892e9`), incluindo a NUI original.

O fork anterior está desativado em `resources/[disabled]/ox_inventory_old`.
A NUI redesenhada que foi portada dele e os slots de roupa em
`playerslots + 1..10` foram removidos em 2026-09-24: os slots dependiam do
tamanho da grade e quebravam ao aumentá-la.

## O que é nosso sobre o upstream

- `data/*.lua`: itens, armas, crafting etc. do servidor.
- `web/images/`: imagens dos itens.
- `modules/items/containers.lua`: mochilas, duffel bags e carteira como containers nativos.
- `modules/equipment/shared.lua`: slots de equipamento (abaixo).
- Patches no núcleo marcados com o comentário `equipment` (`grep -rn "equipment" --include=*.lua`):
  `client.lua`, `server.lua`, `modules/inventory/server.lua`.
- `web/src`: layout (coluna de equipamento, bolsos, atalhos, painel da direita,
  mochila equipada, peso total), tema e as regras de slot de equipamento.
- `web/build/`: gerado com `npm install --legacy-peer-deps && npm run build`
  (o upstream usa bun) e versionado com `git add -f`, já que o
  `web/.gitignore` do upstream ignora o build.

## Slots de equipamento

Corpo (celular, rádio, 2 chaves, carteira, mochila) e roupas (as 10 peças do
clothingmenu) ficam no inventário do próprio jogador, em números fixos
1001–1016, fora da grade `1..inv.slots`. A grade pode crescer (convar ou
`SetSlotCount`) sem colidir com eles. Cada slot só aceita os itens da sua lista;
o servidor valida em `SetSlot`, `AddItem` e `swapItems`.

- Os números ficam salvos no banco: não renumerar.
- `AddItem` põe o item primeiro no slot de equipamento vazio que o aceita.
- A mochila no slot 1016 abre ao lado do inventário (tipo `backpack` na NUI).
- Ao carregar o jogador, item fora da grade e fora de um slot que o aceite
  (roupas nos antigos slots 21–30, grade que diminuiu) é realocado.

Para atualizar o upstream: diff de conteúdo contra a nova tag e reaplicar só
o que está listado acima.
