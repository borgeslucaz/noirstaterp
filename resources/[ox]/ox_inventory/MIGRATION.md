# Migração para ox_inventory

Baseline limpo do upstream `overextended/ox_inventory` na tag `v2.47.9`
(`952c128fdff056fd7506d924faa6c07fb80892e9`), incluindo a NUI original.

O fork anterior está desativado em `resources/[disabled]/ox_inventory_old`.
A NUI redesenhada que foi portada dele (painel de roupas, grade espacial,
temas, filtros) e os slots de roupa em `playerslots + 1..10` foram removidos
em 2026-09-24: os slots dependiam do tamanho da grade e quebravam ao aumentá-la.

O que é nosso sobre o upstream:

- `data/*.lua`: itens, armas, crafting etc. do servidor.
- `web/images/`: imagens dos itens.
- `modules/items/containers.lua`: mochilas e duffel bags como containers nativos.
- `web/build/`: gerado com `npm install --legacy-peer-deps && npm run build`
  (o upstream usa bun) e versionado com `git add -f`, já que o
  `web/.gitignore` do upstream ignora o build.

Pendente: slots de equipamento (roupas e corpo) numa faixa fixa de slots,
independente de `inv.slots`. Itens de roupa salvos hoje nos slots 21–30 dos
jogadores continuam no banco, mas não aparecem na grade até essa migração.

Para atualizar o upstream: diff de conteúdo contra a nova tag e reaplicar só
o que está listado acima.
