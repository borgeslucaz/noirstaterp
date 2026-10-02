# noir_missions — guia de testes da Fase 1

Roteiro para validar no jogo o que os testes em Lua não provam: IA, posicionamento, carga na
mão, alvos, HUD e NUI no CEF. Cada teste diz o que fazer e o que deve acontecer. Anote o número
do teste que falhar.

**Quando algo falhar, junte:**
- linhas `[noir_missions]` do F8 (cliente) e do console do servidor;
- print com `/noirmissionsdebug` ligado (passo, variáveis, grupos, carga);
- se o jogo fechar: **em que momento** fechou (ao pegar o tambor, ao abrir o hack...).
  No Enhanced, crash na hora de um objeto ou animação aparecer costuma ser prop/anim que não
  existe no build.

---

## 0. Preparação

| # | Fazer | Esperado |
|---|---|---|
| 0.1 | `restart ox_inventory` (item novo `chemical_precursor`) | sobe sem erro |
| 0.2 | `exec permissions.cfg` (ou reiniciar o servidor) para a ACE `noir.missions` | — |
| 0.3 | `ensure noir_missions` | console: `N missões carregadas` e `pronto (ACE de admin: noir.missions)`; **nenhum** `passo sem handler` / `ação sem handler` |
| 0.4 | F8 do cliente | nenhum erro de `noir_missions` ao entrar |

Para os testes de grupo (seção 6) você precisa de **2 jogadores na mesma gang** (e um terceiro
de outra gang, se der).

---

## 1. Editor — abrir, navegar, salvar

| # | Fazer | Esperado |
|---|---|---|
| 1.1 | Jogador **sem** a ACE roda `/noirmissions` | aviso "Sem permissão.", nada abre |
| 1.2 | Admin roda `/noirmissions` | painel à direita, lista com "Elysian Chemical Shipment", RASCUNHO, 2–6, 5 passos, sem erros |
| 1.3 | Esc | fecha e devolve o mouse/controle |
| 1.4 | Abrir de novo → EDITAR a Elysian → passar por todas as seções da esquerda | todas abrem, contagens batem (7 variáveis, 2 zonas, 3 NPCs, 1 veículo, 1 carga, 1 interação...) |
| 1.5 | Em Geral, mudar a descrição → Ctrl+S | "NÃO SALVO" some; `missions/meth_elysian_precursors.json` muda no disco |
| 1.6 | `restart noir_missions` → abrir de novo | a descrição alterada continua lá (persistência) |
| 1.7 | Mudar algo e apertar VOLTAR sem salvar | pede confirmação para descartar |
| 1.8 | CRIAR MISSÃO com id `teste_fase1`, nome "Teste" | abre a missão nova, vazia, com a variável `alarm_active` |
| 1.9 | Na lista: DUPLICAR `teste_fase1` como `teste_fase1_b`, depois APAGAR `teste_fase1_b` | aparece e some; o apagar pede confirmação com foco em CANCELAR |
| 1.10 | Em Passos: arrastar um passo pela alça, e testar Alt+↑/↓ | ordem muda; numeração 01..05 acompanha |
| 1.11 | Desligar o toggle de um passo, salvar, religar e salvar | estado salva |

## 2. Posicionamento

Na `teste_fase1`, em **Zonas** → ADICIONAR.

| # | Fazer | Esperado |
|---|---|---|
| 2.1 | DEFINIR POSIÇÃO | NUI some, pílulas embaixo: E Confirmar / G Minha posição / Shift+Roda Altura / Backspace Cancelar; marcador branco segue a mira |
| 2.2 | E num ponto do chão | NUI volta com X/Y/Z preenchidos |
| 2.3 | DEFINIR POSIÇÃO → Backspace | volta sem mudar o valor |
| 2.4 | DEFINIR POSIÇÃO → G | grava onde você está |
| 2.5 | Em **NPCs**: novo grupo, novo NPC (modelo `g_m_y_mexgoon_01`) → DEFINIR POSIÇÃO | prévia do ped meio transparente na mira; **roda gira** e a seta verde mostra a direção |
| 2.6 | Confirmar e clicar PRÉVIA | ped aparece no lugar por ~15 s, com os pés no chão |
| 2.7 | TELEPORTAR | você vai até a posição |
| 2.8 | Em **Veículos**: modelo `speedo` → DEFINIR POSIÇÃO | prévia da van apoiada no chão; entrar num carro e apertar G grava a posição do carro |
| 2.9 | Digitar um modelo inexistente (`abc_nao_existe`) e sair do campo | marcador de inválido; PRÉVIA não cria nada (e o jogo **não** fecha) |
| 2.10 | Em **Teste**, ligar "Desenhar zonas e pontos no mundo" | marcadores e nomes das zonas, NPCs, tambores, rota do reforço e entregas aparecem no mundo |

## 3. Validação

| # | Fazer | Esperado |
|---|---|---|
| 3.1 | Na `teste_fase1`, criar um passo **Interação** sem escolher interação → salvar | contador de erros aparece; clicar no erro leva ao campo |
| 3.2 | Com erro, tentar PUBLICAR ou TESTAR | recusado mostrando os erros |
| 3.3 | Renomear o id de uma zona usada num gatilho | o gatilho passa a apontar para o id novo |

## 4. Elysian — teste solo pelo editor

Antes: **reposicione** no editor tudo da Elysian (as coordenadas da semente são aproximadas):
centro do passo "Ir até", zonas, os 3 grupos de NPC, o notebook (Interações), os 8 tambores, a
van, e os pontos de entrega. Salve. TESTAR MISSÃO ignora gang, mínimo de jogadores, cooldown e
não paga recompensa.

| # | Fazer | Esperado |
|---|---|---|
| 4.1 | Teste → TESTAR MISSÃO | aviso "Missão iniciada"; HUD à direita "Vá até o galpão em Elysian Island."; blip + rota no GPS |
| 4.2 | Ir até a van antes da ilha | van existe, **com chave** (liga e dirige) |
| 4.3 | Chegar a ~220 m | seguranças nascem nos lugares (guardas parados, um fumando, um patrulhando) |
| 4.4 | Chegar a ~100 m do centro | objetivo muda para "Encontre informações sobre o carregamento." |
| 4.5 | Andar até perto de um guarda externo (15 m) **sem** entrar no galpão | ele vira, aponta a arma, balão "Ei! Área restrita..."; depois de ~6 s volta ao posto; **não atira** |
| 4.6 | Mirar sem atirar | continua sem atirar |
| 4.7 | Ir até o notebook → alvo "Hackear computador" | barra de progresso com animação, depois o minigame Circuito |
| 4.8 | Passar no minigame | cartão "MANIFESTO DE CARGA" com carga, lote e armazenamento; objetivo "Carregue os tambores químicos na van." com 0 / 4 |
| 4.9 | Num tambor: "Ver etiqueta" | aviso com "Lote X — ..."; o alvo passa a mostrar "Pegar (Lote X — ...)" |
| 4.10 | Pegar um tambor de **outro** lote | "Esse não é o lote certo." |
| 4.11 | Pegar um tambor certo | tambor sai do chão e vai para as mãos; anda devagar, **não corre, não pula, não atira, não entra em veículo**; pílula "G Largar" |
| 4.12 | G | tambor cai no chão onde você está; dá para pegar de novo |
| 4.13 | Levar até a van → "Colocar carga" | tambor some; HUD 1 / 4 |
| 4.14 | Na van: "Tirar carga" e depois colocar de novo | volta para a mão e depois volta para a van |
| 4.15 | Carregar os 4 | objetivo "Saia de Elysian Island com a carga."; área vermelha no mapa |
| 4.16 | Sair da área **a pé**, sem a van | nada acontece (precisa ser a van com os 4) |
| 4.17 | Sair dirigindo a van | SMS "Bom trabalho..." no telefone (sem telefone, vira aviso); objetivo "Entregue os tambores em <local>."; rota para a entrega |
| 4.18 | Chegar à entrega com a van | NPC esperando fala "Coloca os tambores atrás..."; após ~3 s parado: "Missão concluída"; HUD e blips somem; "Teste concluído. Recompensa não entregue." |
| 4.19 | Voltar ao galpão | guardas, tambores e notebook sumiram |

## 5. Elysian — caminhos alternativos (solo)

| # | Fazer | Esperado |
|---|---|---|
| 5.1 | TESTAR MISSÃO, chegar, **falhar** o minigame | aviso "O alarme disparou... lote X"; guardas ficam hostis e atacam; objetivo segue para carregar |
| 5.2 | (continuação) pegar o primeiro tambor | 30 s depois uma SUV vem **dirigindo** até o galpão, a equipe desce e ataca; vem **só uma** |
| 5.3 | Novo teste: chegar e dar um tiro para o alto perto dos guardas | grupo próximo fica hostil e liga o alarme |
| 5.4 | Novo teste: atirar num guarda | o grupo dele fica hostil |
| 5.5 | Matar todos os guardas | eles não renascem; no debug, `vivos=0` |
| 5.6 | Novo teste: entrar no galpão (zona restrita) | todos os grupos ficam hostis |
| 5.7 | Teste → TESTAR A PARTIR DO PASSO "Carregar a van" | começa direto em 0 / 4, tambores já com alvo, guardas criados |
| 5.8 | Teste → TELEPORTAR PARA O PASSO | teleporta para o local do passo escolhido |
| 5.9 | Teste → TESTAR ENTREGA | começa no passo de entrega |
| 5.10 | Com um teste rodando: ENCERRAR TESTE | tudo some na hora (NPCs, van, tambores, blips, HUD) |
| 5.11 | Carregar um tambor e morrer (ou cair) | tambor cai no chão onde você estava |
| 5.12 | `restart noir_missions` com teste rodando | tudo some, NUI não fica com o mouse preso, nada fica na mão |

## 6. Grupo (2+ jogadores) — Elysian publicada

Publique a Elysian (PUBLICAR). Jogadores A e B na mesma gang, juntos; C de outra gang perto.

| # | Fazer | Esperado |
|---|---|---|
| 6.1 | `/nmoffer meth_elysian_precursors <id de A>` | A recebe a tela CHAMADA com RECUSAR (foco) e ACEITAR, contagem de 30 s |
| 6.2 | A recusa (ou Esc) | fecha, nada acontece |
| 6.3 | Oferecer de novo e A aceita | A e B entram (aviso "Missão iniciada" nos dois, mesmo objetivo e blip); C não entra |
| 6.4 | Oferecer para C | recusado por cooldown ("Esse trabalho não está disponível agora.") |
| 6.5 | A e B veem os mesmos guardas, tambores, van e contagem | sim, nos dois |
| 6.6 | A e B tentam pegar o **mesmo** tambor ao mesmo tempo | só um pega; o outro recebe "Isso já foi levado." |
| 6.7 | B vê o tambor na mão de A (e vice-versa) | sim, com animação |
| 6.8 | A carregando, A desconecta | tambor reaparece no chão onde A estava; B continua a missão |
| 6.9 | Guardas hostis brigando perto de A; A se afasta 300+ m enquanto B fica | guardas continuam atacando B (troca de dono de rede não trava a IA) |
| 6.10 | Concluir a entrega | **cada** participante recebe 2 `chemical_precursor` |
| 6.11 | Em outra rodada (`/nmcooldown meth_elysian_precursors`), os dois saem do servidor | missão falha e tudo é apagado |
| 6.12 | Só 1 jogador da gang aceita (mínimo é 2) | recusado: "Precisa de mais gente da gang por perto." |
| 6.13 | Jogador sem gang aceita | recusado: "Esse trabalho é só para gang." |

## 7. Debug e desempenho

| # | Fazer | Esperado |
|---|---|---|
| 7.1 | `/noirmissionsdebug` durante uma missão | painel à esquerda com instância, passo, variáveis, grupos, carga, veículos; atualiza a cada segundo |
| 7.2 | `resmon 1` sem missão | `noir_missions` perto de 0.00 ms |
| 7.3 | `resmon 1` com missão, longe dos NPCs | baixo (≤ 0.05 ms) |
| 7.4 | Carregando tambor | sobe um pouco (laço por frame só enquanto carrega) e volta ao soltar |

---

A perseguição (60% de chance depois da fuga, com segunda onda de motos) e o reforço fazem
parte da Fase 2, mas aparecem na Elysian. Se atrapalharem o teste da Fase 1, desligue no editor:
passo "Sair de Elysian" → Ao concluir → ação Chance → 0%.
