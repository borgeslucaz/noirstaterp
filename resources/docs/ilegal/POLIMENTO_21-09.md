# Polimento do ilegal — 21/09

Checklist dos recursos ligados ao ilegal, organizado pela ordem recomendada de
polimento. Os recursos desativados ficam fora da prioridade enquanto seus
substitutos atuais estiverem em uso.

## Base do ilegal

- `noir_gangs` — organizações, cargos, membros, permissões, produtos e reputação.
- `noir_territories` — domínio de bairros.
- `noir_graffiti` — pichações e reivindicação territorial.
- `noir_illegal_core` — reputação, heat, níveis, cooldowns e unlocks.
- `noir_skills` — tráfico, arrombamento e outras habilidades.
- `noir_burnerphone` — contatos e contratos clandestinos.

## Crimes de entrada

- `noir_prettycrimes` — smash & grab e parquímetros.
- `noir_houserobbery` — contratos de invasão residencial.
- `qbx_storerobbery` — caixas e cofres de lojas.
- `qbx_pawnshop` — venda e derretimento de produtos roubados.

## Drogas

- `qbx_weed` — plantio, crescimento, nutrição e colheita de maconha.
- `noir_drugselling` — venda para NPCs, esquina, XP e alertas territoriais.
- `noir_outposts` — domínio, estoque, dealers, venda passiva e assalto de corredores.

## Armas

- `noir_guncraft` — bancadas, blueprints, armas, munições e attachments.
- Mercado negro do `ox_inventory` — armas e munições compradas com dinheiro sujo,
  configurado em `resources/[ox]/ox_inventory/data/shops.lua`.

## Roubos maiores

- `qbx_truckrobbery` — carro-forte.
- `qbx_bankrobbery` — Fleecas, Paleto, Pacific e estações elétricas.

## Dependências importantes

Não são crimes diretamente, mas precisam entrar nos testes de integração:

- `bgrz_core` — bridge de inventário, telefone, dispatch, target e gangs.
- `noir_shell` — interiores de outposts e casas.
- `peuren_minigames` — minigames.
- `sd-phone` — alertas e mensagens clandestinas.
- `qbx_police` — dispatch, evidências e resposta policial.
- `ps-mdt` — ocorrências e investigação.
- `xt-prison` — consequência criminal.

## Desativados — não priorizar agora

- `qbx_drugs`
- `qbx_houserobbery`
- `XS-CriminalTablet`

## Ordem recomendada de polimento

1. `noir_gangs`
2. `noir_territories` + `noir_graffiti`
3. `noir_illegal_core` + `noir_skills`
4. `noir_burnerphone`
5. `noir_prettycrimes`
6. `noir_houserobbery`
7. `qbx_storerobbery`
8. `qbx_weed`
9. `noir_drugselling`
10. `noir_outposts`
11. `qbx_truckrobbery`
12. `qbx_bankrobbery`
13. `noir_guncraft`
14. `qbx_pawnshop` e mercado negro do `ox_inventory`
15. Integração final com polícia, MDT, evidências e prisão
