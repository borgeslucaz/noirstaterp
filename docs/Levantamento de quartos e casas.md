# Levantamento de quartos de hotel e casas

Data: 2026-10-01. O levantamento olha o que está em `resources/` e sobe no servidor. O que está em `disabled_resources/` não entra.

## Resumo

Nenhum desses interiores está ligado a um sistema de moradia. Não existe script de motel, apartamento ou casa (aluguel, compra, chave ou baú). Hoje só o mapa existe. O único uso em gameplay é o shell `lev_apartment_shell` no `noir_houserobbery`.

## MLOs (lugar fixo no mapa)

| Local | Tipo | Resource | Unidades | Onde fica |
|---|---|---|---|---|
| Wiwang Hotel | Hotel | `map_wiwang_hotel_enh` | **380 quartos** (20 andares × 19), vazios | Little Seoul, `vec3(-823.6, -708.5, 42.4)` |
| Starlite Motel | Motel | `zydrec-starlitemotel_en` | **30 quartos** (3 andares × 10), vazios | East Vinewood, `vec3(960.0, -208.0, 72.5)` |
| The Emissary | Hotel | `emissary` + `emisarry_elevcontrol` | 5 andares de quartos + lobby; quantidade de quartos **a conferir no jogo** | Centro, elevador em `vec3(60.9, -945.2, 29.8)` |
| Mirror Park Houses | Casas | `mrp_house_en` | **11 casas** | Mirror Park |
| **Total** | | | **410 quartos de hotel/motel conhecidos + Emissary, 11 casas** | |

## Shells (interior instanciado, um modelo serve para várias portas)

Um shell não tem endereço próprio. Ele vira quantas casas ou quartos um script criar. Por isso não entra no total acima.

| Resource | Modelos | Uso hoje |
|---|---|---|
| `lev-apartments` | `lev_apartment_shell` (apartamento mobiliado) | `noir_houserobbery`: 1 casa ativa (`tier1_01`) |
| `shells` (k4mb1 starter) | 16: `standardmotel_shell`, `modernhotel_shell`, `furnitured_midapart`, `shell_v16low`, `shell_v16mid`, `shell_trailer`, `shell_frankaunt`, `shell_michael`, `shell_lester`, `shell_ranch`, `shell_garagem`, `shell_office1`, `shell_store1`, `shell_warehouse1`, `container_shell` | nenhum |
| `lynx_shells` | 6: `t1`/`t2`/`t3`, cada um mobiliado e vazio | nenhum (o ymap deles coloca os 6 fixos no subsolo) |

Desses, 10 servem para moradia: motel, hotel, apartamento médio, v16 low/mid, trailer, frankaunt, michael, lester e ranch.

## Fora da conta

- `interior_ballas`: esconderijo de gang, não é moradia.
- `bob74_ipl`: carrega os apartamentos vanilla do GTA Online. São interiores do jogo, não foram contados.

## Pendências

- Contar no jogo os quartos do Emissary. Os arquivos só mostram 5 drawables de andar (`room1`…`room5`), sem divisão por quarto.
- Starlite: o `zydrec-mapdata` (portas e áudio) não está instalado.
- `the_emissary_en` existe, mas está vazio.
