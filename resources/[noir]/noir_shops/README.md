# noir_shops

Lojas de NPC da Noir State: 24/7, bebidas, ferramentas e Ammu-Nation. Substitui as
lojas `General`, `Liquor`, `YouTool` e `Ammunation` do `ox_inventory/data/shops.lua`.

- Atendente por loja, criado só quando o jogador chega perto (`lib.points`,
  `Config.PedSpawnDistance`) e aberto pelo `ox_target`.
- Interface: Janela de Compra do `docs/DESIGN_v4.md` (§JC) — catálogo com busca e
  categorias, carrinho e pagamento em dinheiro ou cartão. Imagens dos itens vêm do
  `ox_inventory/web/images`.
- O cliente só monta o carrinho. Loja, distância do balcão, quantidade inteira,
  máximo por item, cargo, licença, forma de pagamento e dinheiro são conferidos no
  servidor.
- Item com `license` só aparece para quem tem a licença (`metadata.licences` do
  Qbox ou o item da licença no inventário); a arma sai registrada no nome do jogador.

Fork do [mizu_smartshop](https://github.com/1337Mizu/mizu_smartshop) 1.4.3 (GPL-3.0,
ver `LICENSE`).

## Instalação

- `ensure [noir]` no `server.cfg`, depois do `ox_inventory`, `ox_target` e `qbx_core`
  (as dependências estão no `fxmanifest.lua`).
- Não deixar as mesmas lojas no `ox_inventory/data/shops.lua`, senão o balcão fica
  com duas lojas.

## Config (`config.lua`)

- `Catalog`: itens por tipo de loja (`general`, `liquor`, `hardware`, `ammunation`).
- `Kinds`: nome, modelo e animação do atendente e blip de cada tipo.
- `Config.Shops`: cada loja é `Shop(tipo, posição do atendente, direção)`.
- `Config.Licenses`: licenças que um item pode exigir.
- `Config.MaxCheckoutDistance` e `Config.PaymentTypes`: travas do checkout no servidor.

## Admin no jogo

`/smartshopedit` abre o painel (ACE `command.smartshopedit`; o `group.admin` já tem
todos os comandos). Lista as lojas, edita nome, acesso por emprego/gangue, posição,
atendente, blip, preço dinâmico e itens; cria loja nova na posição do admin e apaga as
criadas no jogo.

- Loja da config editada vira "alterada"; "Voltar à config" descarta a alteração no
  próximo restart.
- O que é feito no painel fica em `saved_shops.json` (fora do git).
- `/smartshopcreate <id> [novoId]` copia uma loja para a posição do admin;
  `/smartshoplist` lista as lojas no F8.

## Preview no navegador

`dev/` (fora do `fxmanifest`) monta a `html/ui.html` real e faz o papel do Lua:

```bash
__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=shops.noirstate.com.br ../noir_garage/web/node_modules/.bin/vite --config dev/vite.config.mjs --host 127.0.0.1 --port 9100
```

Abrir `/` com `?preset=general|liquor|hardware|ammuPorte|ammuSemPorte|dez|admin`
(`?res=1920x1080` simula outra resolução). Não há build: a NUI é HTML, CSS e JS puros
em `html/`.
