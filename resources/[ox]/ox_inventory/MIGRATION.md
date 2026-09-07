# Migração para ox_inventory

Baseline limpo do upstream `overextended/ox_inventory` na tag `v2.47.9`
(`952c128fdff056fd7506d924faa6c07fb80892e9`).

Este é o recurso ativo em `resources/[ox]/ox_inventory`. O fork anterior foi
preservado, desativado, em `resources/[disabled]/ox_inventory_old`.

Estado atual da migração:

- Os arquivos de dados do servidor (itens, lojas, crafting, stashes, armas,
  veículos, animações, evidências e licenças) foram copiados do recurso atual.
- As imagens dos itens também foram copiadas para a NUI padrão.
- As propriedades exclusivas do fork atual (`grid` e `clothing`) foram
  removidas de `data/items.lua` neste recurso novo.
- As mochilas e duffel bags usam containers nativos do upstream em
  `modules/items/containers.lua`. Elas não são equipamento, não abrem painel
  auxiliar e não alteram slots/transferências do inventário.
- A base visual da NUI foi portada e compilada para `web/build`. A execução
  usa somente o layout convencional de slots e a hotbar nativa do upstream.
  Painéis/callbacks exclusivos do fork anterior (roupas, grade espacial,
  mochila equipada, hotbar persistente e configurações persistentes) não são
  renderizados nem solicitados pelo fluxo normal.

Próximas etapas de homologação:

1. Validar todos os fluxos de inventário em jogo.
2. Reaplicar evoluções de design exclusivamente pela NUI, sem alterar
   contratos do core.
3. Acompanhar atualizações futuras do upstream e aplicar somente os patches
   necessários sobre esta base.
