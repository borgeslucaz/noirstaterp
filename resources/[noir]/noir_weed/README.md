# noir_weed

Plantio de maconha em vaso. Fork do [uniq-weedsystem](https://github.com/uniqscripts/uniq-weedsystem)
(GPL-3.0, ver `LICENSE`), reescrito sobre o `bgrz_core`. Substitui o `qbx_weed`, que
está em `disabled_resources/`.

## Como funciona

1. O jogador usa uma semente (`weed_*_seed`) no inventário. Aparece o vaso fantasma:
   mira posiciona, roda do mouse gira, Enter confirma, Backspace cancela.
2. Plantar consome a semente e um `weed_pot`, e exige `garden_shovel`.
3. A planta perde água, fertilizante e saúde a cada ciclo e só cresce enquanto os três
   estão acima de zero. O dono cuida pelo menu (alvo "Ver planta"): `water`,
   `weed_nutrition` e `herbicide` repõem cada um.
4. Com 100% de crescimento, colher (exige a pá) entrega o produto da variedade
   (`weed_og-kush`, `weed_skunk`...). A quantidade vai de `reward.min` a `reward.max`
   conforme a saúde da planta.
5. O dono pode mudar o vaso de lugar ou destruir. Polícia em serviço queima planta alheia.

Não tem loja: os itens entram pela loja do servidor.

## Diferenças para o upstream

- **Sem loja** integrada.
- **Sem vaso vazio**: a semente já planta. O `weed_empty_pot.ydr` do upstream é RSC7
  v165 e o servidor espera v159 (mesmo problema dos props do sky_phone).
- **Sem gizmo**: no Enhanced o object_gizmo não pega o clique. Posicionamento por mira,
  como no editor do noir_garage.
- **Sem NUI**: o status é um menu de contexto do ox_lib, com barra de progresso.
- **Prop local**: cada client cria a planta só quando chega perto (`renderDistance`), em
  vez de uma entidade de rede por planta criada pelo servidor.
- **Servidor decide tudo**: a loja do upstream aceitava preço e item do client, colher
  não conferia o crescimento, destruir e mover não conferiam nada. Aqui toda ação passa
  por `begin`/`finish`, com dono, distância, item e tempo da animação conferidos no
  servidor (§7, §17.4).
- Tabela própria `noir_weed_plants` (o banco já tem `weed_plants` com o schema do qbx_weed).

## Configuração

- `config/shared.lua` — itens, variedades, estágios, durações, animações. Vai para o client.
- `config/server.lua` — recompensa, taxas do ciclo, limite de vasos, zonas proibidas.

## Testes

```
cd resources/[noir]/noir_weed
for f in tests/unit/*_spec.lua; do lua5.4 "$f" || break; done
```
