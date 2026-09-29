# sandyshoresreborn_enhanced

SandyShoresReborn 3.5 (SantosMods.dev), adaptado para o Enhanced. Original em `README.original.md`.

## Ativo (stream_enhanced/)

Os 13 `included.*.ymap`. Todos usam só props do jogo base e o formato de ymap
é o mesmo no Legacy e no Enhanced, então não precisam de conversão.

Removido do pacote original:
- `server.lua`: só checava versão no site do autor.
- `dependency '/assetpacks'`: os arquivos não são criptografados.
- `Props/pnwsigns` (81 modelos): nenhum ymap do pacote usa.

## Opcional (opcional/, não carrega)

Para ativar, mover o arquivo para `stream_enhanced/`.

- `extras/*.ymap`: variações do autor. Não misturar `food-circle.NoCars`
  com o `included.alhambra.food-circle.WithCars` (são o mesmo lugar, com e sem carros).
- `extras/optional.sandy-ev-chargers.ymap`: usa o prop `ld_v2_ev_charger`, que
  está no formato Legacy em `extras/ev_charger_legacy/`. Antes de ativar:
  converter o `.ydr` para Enhanced, pôr `.ydr` e `.ytyp` em `stream_enhanced/`
  e adicionar no fxmanifest:
  `data_file 'DLC_ITYP_REQUEST' 'stream_enhanced/ld_v2_ev_charger.ytyp'`.
  Prop ausente ou no formato errado derruba o cliente.
- `substitui_mapa_original/lr_cs4_roads_*.ymap`: substituem ymaps do jogo. Foram
  feitos em cima do Legacy; no Enhanced podem apagar coisa que existe. Testar sozinho.
- `nodes/*.ynd`: caminhos de trânsito da IA. Substituem os do jogo; mesmo cuidado.
