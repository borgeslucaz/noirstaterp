# noir_weed

Maconha do plantio à venda: vaso, baseado e mesa de embalar. Fork do
[uniq-weedsystem](https://github.com/uniqscripts/uniq-weedsystem) e da lógica de mesas do
[it-drugs](https://github.com/it-scripts/it-drugs), ambos GPL-3.0 (ver `LICENSE`),
reescritos sobre o `bgrz_core`. Substitui o `qbx_weed`, que está em `disabled_resources/`.

## Plantio

1. O jogador usa uma semente (`weed_*_seed`). Aparece o vaso fantasma: mira posiciona,
   roda do mouse gira, Enter confirma, Backspace cancela.
2. Plantar consome a semente e um `weed_pot`, e exige `garden_shovel`.
3. A planta perde água, fertilizante e saúde a cada ciclo e só cresce enquanto os três
   estão acima de zero. O dono cuida pelo menu (alvo "Ver planta"): `water`,
   `weed_nutrition` e `herbicide` repõem cada um.
4. Com 100%, colher (exige a pá) entrega o bud da variedade (`weed_skunk`...). A
   quantidade vai de `reward.min` a `reward.max` conforme a saúde.
5. O dono pode mudar o vaso de lugar ou destruir. Polícia em serviço queima planta alheia.

Estágios: vaso (0%), pequena (10%), média (40%), grande (70%). Cada variedade usa um
conjunto de modelos (`look`): Purple Haze roxa, White Widow branca, Amnesia amarela,
Skunk azul; OG Kush e AK47 com a planta vanilla.

## Baseado (parte legal)

Usar um dixavador (`grinder_crank`, `_monster`, `_slime`, `_totem`, `_ufo`) no
inventário abre o menu com as variedades que o jogador tem. Um bud + duas sedas
(`rolling_paper`) = dois baseados (`joint`). Cada baseado bolado gasta 10% da qualidade
do dixavador (10 usos); em 0% ele fica gasto no inventário e para de funcionar.

Fumar é do `qbx_consumables`, que já registra o `joint`.

## Mesa de embalar (parte ilegal)

O item `weed_processing_table` é posicionado pela mira e salvo no banco. Na mesa, um bud
+ um `empty_weed_bag` = um saquinho da variedade (`weed_skunk_baggy`...), vendido no
`noir_drugselling`. Qualquer um usa a mesa; só o dono recolhe (volta o item); polícia em
serviço apreende (a mesa é destruída). Uma mesa por personagem (`maxTables`).

"Usar mesa" abre o minigame (NUI em `web/`): a tela lista só as variedades que o
jogador tem no bolso, ele escolhe a quantidade e arrasta cada bud até um saquinho vazio.
Errar o saquinho perde o bud (`wasteOnMiss`; desligado, o bud volta). Ajustes em
`packGame` (selagem, folga da mira, saquinhos na mesa, teto por rodada, volume inicial).
Sons CC0 da Kenney em `web/sounds/` (pegar, soltar, selar, errar); o jogador ajusta o
volume na própria tela (o ícone liga e desliga), e a escolha fica salva.

O servidor reserva o lote no início e, no fim, entrega o que foi embalado e tira os buds
perdidos, conferindo ingredientes e distância. A velocidade não corta a entrega: quem embala mais rápido que
`packSecondsPerUnit` (3,5 s por unidade) vira um registro `pack_fast` em
`server/logs.lua`, o ponto único que o sistema de logs vai usar. Burlar o minigame não
cria item: cada saquinho continua custando um bud e um saquinho vazio.

Para abrir a tela no navegador, sirva a pasta `resources/` e abra
`[noir]/noir_weed/web/index.html`: o botão "Abrir mesa" usa dados de exemplo.

As receitas ficam em `config/shared.lua` (`tables`), prontas para outras mesas: os
modelos de coca e meth já estão em `stream_enhanced/`.

## Validade

Do ox_inventory (`degrade` + `decay` no item): bud 5 dias, saquinho 10, baseado 15.
Corre em qualquer inventário, também com o jogador offline. O dixavador não tem validade.

## Diferenças para os upstreams

- **Sem loja** integrada: os itens legais estão na Head Shop (noir_shops).
- **Sem gizmo**: no Enhanced o object_gizmo não pega o clique. Posicionamento por mira.
- **NUI só na mesa**: status da planta e dixavador em menu de contexto do ox_lib; a mesa
  tem o minigame próprio, com as imagens do ox_inventory.
- **Prop local**: cada client cria planta e mesa só quando chega perto (`renderDistance`).
- **Servidor decide tudo**: toda ação passa por `begin`/`finish` com dono, distância, item
  e tempo da animação conferidos no servidor (§7, §17.4). O uniq aceitava preço da loja
  do client; a mesa do it-drugs não conferia o tempo nem a ferramenta.
- Modelos convertidos para o formato do Enhanced em `stream_enhanced/`.
- Tabelas próprias `noir_weed_plants` e `noir_weed_tables` (o banco já tem `weed_plants`
  com o schema do qbx_weed).

## Configuração

- `config/shared.lua` — itens, variedades, modelos, dixavadores, receitas, durações. Vai
  para o client.
- `config/server.lua` — recompensa, taxas do ciclo, limites de vaso e mesa, zonas proibidas.

## Testes

```
cd resources/[noir]/noir_weed
for f in tests/unit/*_spec.lua; do lua5.4 "$f" || break; done
```
