# noir_handledeath

Tela de morte em NUI e médico NPC, sobre o `qbx_medical`, integrados via `bgrz_core`.

Os minijogos são de terceiros e mantêm as licenças nas próprias pastas (`web/public/games/*`):
2048 (MIT, Gabriele Cirulli) e Clumsy Bird (GPL-3), com os ajustes de embed vindos do
EMY Digital Death Screen (MIT).

Quem decide caído, morto e os tempos continua sendo o `qbx_medical`. Este resource só mostra e
oferece as saídas.

## Tela

Abre quando o jogador cai (`isDead` no state bag, que o `qbx_medical` liga no last stand e na
morte) e fecha quando ele levanta. Enquanto aberta, **mouse e teclado ficam só na NUI**: chat,
voz, celular, menu de pausa e qualquer tecla do jogo não agem, e a tela não tem atalhos:
as ações são só os botões, com o mouse (as teclas só valem dentro dos jogos). O foco é retomado a cada segundo
se outro resource soltar.

| Botão | Quando |
|---|---|
| Chamar EMS (dispatch pelo `bgrz_core`) | há paramédico em serviço; intervalo de 60 s |
| Chamar médico NPC | nenhum paramédico em serviço; custa `price` |
| Desistir (acordar no hospital) | morto; com EMS em serviço, só quando o tempo acaba |
| Jogos | sempre |

O "segure E" e os textos de caído/morto do `qbx_ambulancejob` ficam desligados
(`showDownedText = false` no config dele). O respawn passa por `RequestRespawn` do `bgrz_core`.

Depois do respawn o jogador vai para a cama do hospital ainda com `isDead`; a tela não reabre até
ele levantar e cair de novo.

## Médico NPC

Uma ambulância nasce a ~80 m com sirene, vem até o jogador, o médico desce, faz a massagem
cardíaca (20 s) e o jogador levanta. A tela mostra cada etapa. Ambulância e médico são
**locais**: só o jogador atendido os vê.

Regras no servidor:

- só atende caído/morto e com EMS em serviço ≤ `maxEmsOnDuty`;
- só pode ser chamado depois de 3 minutos caído;
- confere o saldo na chamada e cobra no fim (dinheiro vivo, depois banco); se a reanimação
  falhar, devolve;
- exige o tempo mínimo de viagem e o tempo da massagem entre a chegada e a reanimação;
- uma chamada por vez, intervalo de 15 s, validade de 3 min;
- se o jogador levantar por outro caminho (EMS, hospital, admin), o médico vai embora sem cobrar.

Ambulância presa por mais de 60 s é colocada na rua mais próxima; médico travado por 20 s
aparece ao lado do jogador.

## Config

- `config/shared.lua`: preço, espera para chamar, tempos do médico, models e intervalo do chamado de EMS.
- `config/server.lua`: job de EMS, limite de EMS para o médico, intervalos, texto do chamado.

## NUI

`web/` (Vite + React). Preview no navegador com `npx vite` e os botões do canto inferior
esquerdo, ou direto por `?preset=Caído`, `?preset=Morto`, `?preset=Morto com EMS`. O jogo carrega
`web/build`: rode `npm run build` depois de mexer na interface.
