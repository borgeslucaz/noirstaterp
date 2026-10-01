# Plano de testes da polícia: `noir_police` (out/2026)

> Roteiro para o primeiro teste em jogo do `noir_police` e do que foi religado a ele. O que foi construído está no [Plano da polícia](Plano%20da%20polícia%20(noir_police).md), e o uso em `resources/[noir]/noir_police/README.md`. Cada caso diz o que fazer e o que tem que acontecer. Marque `[x]` quando passar; quando falhar, anote o que apareceu e a linha do console.

## 0. Preparação

**Pessoas:**
- **A**: policial LSPD (`police`), grade 4, admin.
- **B**: civil, sem job.
- **C** (opcional): BCSO (`bcso`) grade 0, para os testes de departamento.

**Antes de entrar:**
- [ ] Reiniciar o servidor inteiro. Restart só do resource não serve: o `qbx_police` saiu, o `server.cfg` mudou e o bgrz_core também.
- [ ] No console, sem erro de `noir_police`, `bgrz_core`, `Renewed-Banking`, `ox_inventory` ou `noir_shops`. Procurar por:
  - migration aplicada (tabelas `noir_police_seizures`, `noir_police_deposits`, `noir_police_flagged_plates`, `noir_police_layout`);
  - nenhum `Duplicate entry` do Renewed-Banking (a correção da conta bancária);
  - nenhum `falha ao carregar server.modules.*`.
- [ ] `SHOW TABLES LIKE 'noir_police%'` devolve as 4 tabelas.
- [ ] Nenhum resource parado por dependência: `noir_police`, `noir_shops`, `qbx_radialmenu`, `xt-prison`, `ps-mdt`.

**Itens de teste para A** (pelo arsenal, seção 3):
- `handcuffs`, `handcuffkey`, `zipties`, `cutters`
- `evidence_case` (bolsa de evidências), `seized_box` x2
- `spikestrip` x2, `shield`
- `WEAPON_COMBATPISTOL` com munição

**Itens para B** (admin give):
- `money` 5000, `black_money` 3000
- uma arma qualquer com munição
- `lockpick` x3, `zipties` x2

## 1. Boot e contratos

- [ ] **1.1** F8 de A e B sem erro de script do `noir_police` ao entrar.
- [ ] **1.2** Blips de Mission Row e Paleto no mapa.
- [ ] **1.3** Contagem de policiais: o assalto a banco (qbx_bankrobbery) mostra o número certo de policiais com A em serviço e 0 com A fora.
- [ ] **1.4** Tecla X de B: levanta as mãos **uma vez só**, toda vez (tocar e segurar). Se ainda houver duas animações brigando, o handsup do scully não desligou (`setr scully_emotemenu:handsUpKey ""`); o "cancelar emote" do scully agora vem no Backspace por padrão. Com as mãos para cima ou ajoelhado, apertar ESC e voltar do menu de pausa: a pose volta sozinha.

## 2. Serviço e blips

- [ ] **2.1** A no ponto de serviço de Mission Row, "Entrar/sair de serviço": o aviso muda de estado.
- [ ] **2.2** Fora do ponto (a mais de 4 m), tentar pelo radial ou por comando: recusado com "Longe demais".
- [ ] **2.3** Com A e C em serviço, cada um vê o blip do outro com a cor do departamento. Um EMS em serviço também vê os dois.
- [ ] **2.4** A sai de serviço: o blip some para os outros em até ~3 s.
- [ ] **2.5** C (BCSO) não tem a opção de serviço em Mission Row, que é LSPD e SASP. Tem em Paleto.

## 3. Arsenal (noir_shops)

- [ ] **3.1** A fora de serviço: o arsenal recusa com "Você precisa estar em serviço".
- [ ] **3.2** A em serviço retira pistola, munição, algema e caixa: tudo a $0.
- [ ] **3.3** A tenta retirar uma segunda pistola: recusa com "já carrega o máximo".
- [ ] **3.4** A pistola sai com `registered = LSPD` e o serial **contém** `POL` no meio (formato do ox_inventory: `123456POL654321`). Duas pistolas têm seriais diferentes.
- [ ] **3.5** Grades do LSPD: 0 = Recruit, 3 = Lieutenant, 4 = Chief. Com `/setjob <id> police 0`, a carabina (grade 3) **não** aparece. Com grade 3 ou 4, aparece.
- [ ] **3.6** B **vê** o NPC do arsenal, mas não tem a opção de abrir a loja.
- [ ] **3.7** C retira no arsenal de Paleto: a arma sai `BCSO`/`BCS`.
- [ ] **3.8** Log da retirada chegou ao fivemanage (`noir_shops`).

## 4. Mãos para cima e algema

- [ ] **4.1** Vale para qualquer um (civil, bandido ou policial):
  - toque no X levanta as mãos, e outro toque abaixa;
  - segurar o X por ~0,7 s ajoelha, de pé ou já de mãos para cima;
  - ajoelhado fica travado: não anda, e o X não faz nada;
  - aparece a pílula **J Levantar**, e só o J levanta, com a animação de ficar de pé;
  - ESC ou menu de pausa não desfaz a pose: ela volta sozinha em até 0,5 s.
- [ ] **4.2** **Algema normal:** B em pé de mãos para cima. A usa "Algemar" no target:
  - B fica algemado, com a animação certa (frente ou costas conforme o lado de A);
  - aparece a **algema do ND** (`police_cuffs`, convertida), presa nos pulsos, e o cliente de A e de B não cai;
  - com zip tie, aparece o **zip tie do ND** (`police_zip_tie_positioned`);
  - soltar: o prop some dos dois lados (nada fica flutuando).
  - uma algema sai do inventário de A.
- [ ] **4.3** **Algema agressiva:** B sem as mãos para cima, A algema:
  - aparece o minigame de fuga para B;
  - B **acerta**: escapa, e A leva "A pessoa escapou!";
  - A tenta de novo em até 2 min: B **não** recebe o minigame.
- [ ] **4.4** B **ajoelhado**: a algemação é agressiva, com minigame. É intencional, como no ND.
- [ ] **4.5** Enquanto algemado, B não consegue:
  - correr, atacar, sacar arma ou entrar num carro sozinho;
  - abrir o inventário;
  - usar item pela hotbar.
- [ ] **4.6** B algemado **sai e entra de novo**: volta algemado.
- [ ] **4.7** A tira a algema com a chave: B solto e a algema volta para A.
- [ ] **4.8** **Zip tie de civil:** B põe zip tie em outro civil (ou em A) rendido (mãos para cima, ajoelhado ou caído). Funciona. Sem estar rendido: "A pessoa precisa estar rendida".
- [ ] **4.9** **Algema de civil:** B com `handcuffs` algema alguém **rendido**: funciona. Alguém **não** rendido: a opção não aparece, e pelo item é recusado com "A pessoa precisa estar rendida". Só o policial em serviço algema quem não se rendeu (algemação agressiva, 4.3).
- [ ] **4.10** Zip tie cortado com `cutters`: solto, e o zip tie não volta.
- [ ] **4.11** **Arrombar algema:** alguém algemado com `handcuffs`; B (civil) com lockpick arromba:
  - aparecem a barra de progresso e o minigame;
  - acertou: solta;
  - errou: às vezes o lockpick quebra (~35%);
  - A (policial) não tem essa opção.
- [ ] **4.12** Admin menu, "algemar a si mesmo": alterna a algema.
- [ ] **4.13** Com o prop do jogo (`customProps = false`), nada derruba o cliente. Se cair, anotar: prop inexistente derruba o Enhanced.
- [ ] **4.14** Repetir várias vezes seguidas algemar, tirar algema, zip tie, pôr e tirar do carro, carregar e soltar. No fim, B **consegue mirar e atirar**.

## 5. Escolta, ombro e viatura

- [ ] **5.1** A escolta B algemado:
  - B vai grudado, com a animação de andar e correr;
  - "Soltar" solta.
- [ ] **5.2** B (civil) tenta escoltar alguém **não** algemado e em pé: recusado.
- [ ] **5.3** Um EMS em serviço escolta alguém em pé: permitido, como no qbx.
- [ ] **5.4** "Carregar no ombro" em alguém algemado ou caído: anima dos dois lados. Aparece a pílula **J Colocar no chão**, e o J solta. Escoltando, aparece **J Soltar**.
- [ ] **5.5** Com B sendo escoltado, A usa "Colocar no veículo" numa viatura: B senta no banco de trás mais perto, e a escolta termina.
- [ ] **5.6** "Tirar do veículo" pelo banco de trás: B sai já escoltado por A.
- [ ] **5.7** A carregando B no ombro mira o porta-malas de um carro (target) e escolhe "Colocar no porta-malas": B vai para o porta-malas, **sem precisar abrir antes**, com a câmera do porta-malas. Um segundo carregado no mesmo porta-malas: "Já tem alguém nesse porta-malas".
- [ ] **5.10** **Tirar do porta-malas:** A (ou qualquer um) mira o porta-malas com B dentro e escolhe "Tirar do porta-malas": B sai atrás do carro, ainda algemado.
- [ ] **5.8** A se desconecta escoltando B: B fica solto e desanexado.
- [ ] **5.9** B morre algemado e renasce no hospital: renasce **sem** algema.

## 6. Revista e apreensão

- [ ] **6.1** A em serviço revista B (mãos para cima): abre o inventário de B.
- [ ] **6.2** A arrasta `black_money` e a arma de B para o **próprio** inventário: permitido.
- [ ] **6.3** "Minhas pendências" na sala de evidências: aparecem o dinheiro sujo e a arma.
- [ ] **6.4** A **reorganiza** itens dentro do inventário de B, sem tirar nada: **não** gera pendência.
- [ ] **6.5** A arrasta um item seu para cima de um item de B (troca): o item de B que veio para A gera pendência.
- [ ] **6.6** A **fora de serviço** tenta tirar item de B: recusado com "Você está fora de serviço".
- [ ] **6.7** Civil rouba civil de mãos para cima ("Roubar" no radial): abre o inventário, e o dinheiro sai como item.
- [ ] **6.8** A põe tudo numa `seized_box`, abre e tira de volta: a caixa é container comum.
- [ ] **6.9** Depósito na sala de evidências de Mission Row, com **duas caixas** no inventário:
  - no inventário, botão "Colocar etiqueta" em cada caixa: o nome vira "Caixa: <etiqueta>";
  - cada caixa tem conteúdo próprio (o que entra numa não aparece na outra);
  - no depósito, a lista mostra as duas pela etiqueta e pela quantidade de itens;
  - escolhe caixa, alvo (B aparece na lista) e motivo;
  - a caixa some;
  - um `filled_evidence_bag` "Apreensão #N" aparece na gaveta;
  - as pendências somem de "Minhas pendências".
- [ ] **6.10** Depósito com dinheiro **limpo** sem motivo: recusado com "Informe o motivo".
- [ ] **6.11** Caixa vazia: recusado.
- [ ] **6.12** Depositar em Paleto sendo LSPD: a opção não aparece.
- [ ] **6.13** **Destino** (grade 2 ou mais):
  - "Destruir": o saco some da gaveta;
  - "Devolver" **não** põe nada no bolso de B. B recebe um **SMS do 911 (Los Santos Police Department)** no app Mensagens, que fica salvo na conversa; com B **offline**, o SMS está lá quando ele entrar. B retira no balcão da **recepção** de Mission Row ("Retirar pertences apreendidos"). Vêm os itens, menos o dinheiro sujo, e o saco some da gaveta;
  - no `/policiaeditor`, a delegacia tem o ponto **"Recepção (retirada de pertences)"**; movido, o target vai junto. Delegacia sem recepção usa o ponto de serviço;
  - outro jogador na recepção não vê os pertences de B ("Você não tem pertences para retirar aqui");
  - "Incorporar" com dinheiro limpo: entra na conta `police` (conferir no app do banco), e o saco some.
- [ ] **6.14** **Pendência vencida:** para testar, baixar `seizure.pendingDeadlineHours` para 0 no config. Tirar um item de B sem depositar: em até 10 min aparece `seizure_missing` no log.

## 7. Evidência

- [ ] **7.1** B atira numa parede perto de A (em serviço): aparecem pontos de cápsula no chão e de projétil na parede.
- [ ] **7.2** A com a **bolsa de evidências** (`evidence_case`, arsenal) coleta: `casing`/`projectile` entram **dentro da bolsa** (não no bolso), com o calibre certo e o **serial da arma de B**. Não gasta nenhum item. Abrir a bolsa pelo inventário mostra o conteúdo.
- [ ] **7.3** Sem a bolsa: "Você precisa da bolsa de evidências". Bolsa cheia: "A bolsa de evidências está cheia" e o ponto continua no chão. A bolsa não aceita item comum arrastado (só evidência).
- [ ] **7.4** B (civil) não vê os pontos de evidência.
- [ ] **7.5** **GSR** logo depois do tiro: POSITIVO. Depois de B ficar 1 min nadando: negativo. Depois de 15 min sem atirar: negativo.
- [ ] **7.6** **Sangue no chão** (o ponto fica no chão, não na altura do corpo): B leva um tiro e sangra (qbx_medical). A vê o ponto e coleta: o saco vai para a bolsa com o DNA e o tipo sanguíneo de B.
- [ ] **7.15** **Sangue da pessoa:** B algemado, rendido ou caído; A usa "Colher amostra de sangue": a "Amostra de sangue" vai para a bolsa com DNA e tipo sanguíneo. B em pé e livre: a opção não aparece.
- [ ] **7.7** **Digital:** o ponto fica no chão, onde B estava, e continua lá depois que B sai. B tenta arrombar o caixa de uma loja **sem luva** (dando certo ou não). A vê o ponto de digital no caixa, coleta, e a digital bate com a de B no leitor. Com luva: nenhum ponto.
- [ ] **7.8** **Leitor de digital:** B no leitor da delegacia, e A usa "Ler digital": mostra a digital. B fora do leitor: "A pessoa precisa estar no leitor de digital".
- [ ] **7.9** **DNA:** A (grade 1 ou mais) coleta DNA de B: o saco vai para a bolsa com o DNA.
- [ ] **7.10** **Examinar:** B toma **uma** cerveja e fuma baseado (qbx_consumables). A examina: aparecem "Cheiro de álcool" e "Cheiro de maconha".
- [ ] **7.11** "Limpar evidências da área" (menu F6) apaga os pontos num raio de 10 m. O F6 abre o menu da polícia, e não o ShadowForge DevTools, que agora abre só por `/sfdev` e só para admin.
- [ ] **7.13** **Código de DNA:** o saco de sangue de B e o saco de DNA coletado de B mostram o **mesmo** código de 16 caracteres, e o código não é o citizenid de B.
- [ ] **7.14** **Bancada de DNA** (sala de evidências, ponto "Analisar DNA"):
  - comparar o saco de sangue com o de DNA de B: "mesmo DNA";
  - comparar com o DNA de outra pessoa: "DNA diferente";
  - sangue de B no banco de DNA **antes** de coletar DNA dele: "sem correspondência";
  - depois de coletar o DNA de B, a mesma consulta mostra o nome de B;
  - as amostras aparecem mesmo estando **dentro da bolsa**;
  - sem saco com DNA no bolso nem na bolsa: "Você não tem sacos de evidência com DNA".
- [ ] **7.12** **Shotspotter:** B atira sem supressor perto de um sensor. Em ~2 s a polícia recebe o alerta (MDT ou fallback). Com supressor, ou com policial atirando: não recebe.

## 8. Frota

- [ ] **8.1** A no target **"Garagem da frota"** de Mission Row (ao lado da garagem, 454.6, -1017.4; **não** é a garagem do noir_garage/`/garagem`): aparecem só as viaturas liberadas para LSPD e para a grade dele.
- [ ] **8.2** A retira a viatura: nasce na vaga com placa `LSPDxxxx`, A entra, a chave funciona (mri) e há combustível.
- [ ] **8.3** Segunda viatura: "Você já tem uma viatura retirada".
- [ ] **8.4** Vaga ocupada por outro carro: usa a próxima vaga livre, ou "A vaga está ocupada".
- [ ] **8.5** "Guardar viatura" perto da garagem: some. Longe da garagem: recusado.
- [ ] **8.6** Target **"Heliponto"** no telhado de Mission Row (grade 2): retira o `polmav`.
- [ ] **8.7** C (BCSO) não vê as viaturas LSPD. Em Paleto, vê o `sheriff`.

## 9. Armário

- [ ] **9.1** A abre o armário e veste "Patrulha": a roupa muda.
- [ ] **9.2** "Roupa civil": volta para a roupa salva do personagem.
- [ ] **9.3** "Tático (SWAT)" desabilitado para grade abaixo de 3.
- [ ] **9.4** `/noir_police_outfit` copia a roupa atual para a área de transferência.

## 10. Campo (menu F6 e targets)

- [ ] **10.1** **Multa** de $500 em B: o saldo de B **não muda**; B vê o aviso com o motivo e o push no celular; a multa aparece na aba **Faturas** do banco e no app Faturas.
- [ ] **10.2** Multa acima de $25.000: "Valor inválido". B sem saldo **também recebe** a multa (fica pendente).
- [ ] **10.3** **Licença** (grade 2 ou mais): conceder e revogar "Porte de arma" em B. Conferir no metadata `licences`, e no Ammu-Nation a pistola passa a vender ou deixa de vender.
- [ ] **10.4** **Prender** B algemado (target ou radial): B vai para o xt-prison **sem a algema**, sem `SCRIPT ERROR` de audio bank no F8 (toca o som da cela ou um som do jogo).
- [ ] **10.20** **Prisão (MLOs novos) e saída** (os MLOs derrubaram o cliente no login e foram removidos; testar a saída sem eles até achar MLOs que funcionem): pena de 2 meses em B:
  - B aparece dentro do bloco principal, sem cair no chão nem ficar preso na parede; o cozinheiro fica na cantina e o médico no lugar dele (conferir que não estão dentro de parede);
  - o inventário de B some (confiscado), e o aviso de entrada vem em português;
  - `/jailtime` mostra o tempo descendo 1 por minuto;
  - zerado, chega "faça o checkout"; B vai ao balcão da recepção ("Verificar tempo"): sai do lado de fora, com a roupa normal e os itens de volta;
  - tentar o checkout antes de zerar: mostra o tempo que falta e não solta.
- [ ] **10.5** **Tornozeleira** em B algemado: aparece o acessório no pescoço/tornozelo e o ID de B. `/ankletlocation <citizenid>` põe o blip de B por 60 s. Tirar a tornozeleira: a roupa volta.
- [ ] **10.6** `/callsign 1A-12`: aparece no blip dos colegas e no 10-99.
- [ ] **10.7** **10-99** (menu, radial ou morto no radial): chega para polícia e EMS com o nome e o callsign.
- [ ] **10.8** **Área interditada** de 50 m por 1 min: todos, inclusive B, veem o círculo e o aviso. Some sozinha depois do tempo. "Liberar área" também tira.
- [ ] **10.9** **Status da unidade:** o aviso chega só para colegas do mesmo departamento (C, do BCSO, não recebe o de A).
- [ ] **10.10** **Reunião** (grade 2 ou mais): chega para o departamento.
- [ ] **10.11** **Multa trava o banco:** com a multa de 10.1 aberta, B tenta sacar e transferir na agência: recusa com "multas pendentes"; depositar funciona. Na aba Contas aparece o aviso vermelho.
- [ ] **10.12** B tenta transferir pelo app Banco do celular: recusa com "multas em aberto".
- [ ] **10.13** B **paga na agência** (aba Faturas, "Pagar" e confirmar): sai do banco de B, entra na conta `police`, os dois extratos mostram o lançamento, o contador da aba some e saque volta a funcionar.
- [ ] **10.14** Outra multa; B paga pelo **app Faturas** do celular: mesmo resultado de 10.13, e a aba Faturas do banco aberta depois já não mostra a multa.
- [ ] **10.15** Outra multa; B paga no **caixa eletrônico** (faixa de multas acima das operações).
- [ ] **10.16** B sem saldo tenta pagar: "Saldo insuficiente", a multa continua aberta.
- [ ] **10.17** No app Faturas, "Contestar" numa multa: não aparece ou é recusado.
- [ ] **10.18** **MDT:** multa pelo relatório (ou citação) em B: vira fatura na conta do departamento do policial, sem tirar saldo. Com B **offline**: a multa aparece quando B entra.
- [ ] **10.19** **Registro de arma:** B compra uma pistola no Ammu-Nation: no MDT, a arma aparece em nome de B com o serial do item. Arma retirada no arsenal da polícia **não** entra.

## 11. Equipamento

- [ ] **11.1** "Objetos da viatura" no porta-malas da viatura da frota: escolher cone ou barreira abre o **posicionamento pela mira** (igual ao vaso do noir_weed): o objeto fantasma segue a mira, a roda do mouse gira (Shift = rápido), Enter confirma e Backspace cancela. Longe demais (mais de ~5,5 m), o fantasma fica apagado e não confirma. Num carro qualquer, a opção não aparece.
- [ ] **11.2** "Recolher objeto": some. Passar de 12 objetos: "Você já posicionou objetos demais".
- [ ] **11.3** **Spike** com 2 no inventário: pergunta a quantidade, abre, e 2 saem do inventário. B passa de carro por cima: estoura pneu. A recolhe: o item volta.
- [ ] **11.4** **Escudo:**
  - com o escudo no inventário, ele aparece nas costas e A **corre normal**;
  - usar com pistola na mão: escudo no braço esquerdo, na frente do corpo, andando agachado e sem correr;
  - mirar com o escudo: a pistola vai **numa mão só** (estilo gangster) e o escudo continua na frente, sem ficar torto ao lado do corpo;
  - Ctrl ou trocar de arma: abaixa, o escudo volta para as costas e a mira volta ao normal (duas mãos);
  - B vê o escudo em A;
  - A sai de perto de B: nada fica flutuando na tela de B.
- [ ] **11.5** **Animações de arma (ND_GunAnims)**, menu `/testanims` (admin):
  - "Mira: Gang", "Hillbilly" e "Padrão": segurando o botão direito, a pose muda; B vê a mesma pose;
  - "Sacar"/"Guardar" de cada conjunto (gang, mele, police) toca sem travar o personagem;
  - sacar e guardar a pistola pelo inventário toca a animação do ND **uma vez só** (a do ox_inventory está desligada por `inventory:weaponanims 0`);
  - levantar o escudo põe a mira em Gang, e abaixar volta para a mira que estava antes.

## 12. Vigilância

- [ ] **12.1** **Radar:** B passa a 100 km/h num radar de 60 com carro próprio: multa pela faixa vira fatura (velocidade, limite e placa na descrição) e aviso. Viatura da frota passa: sem multa.
- [ ] **12.2** O mesmo radar de novo em menos de 60 s: sem segunda multa.
- [ ] **12.3** **ANPR:** `/flagplate <placa de B> teste`. B passa num radar: a polícia recebe "ANPR: placa marcada". `/plateinfo` mostra a marcação. `/unflagplate` tira.
- [ ] **12.4** **Câmeras:** A na mesa de câmeras de Mission Row abre a lista e vê uma câmera; setas trocam e Backspace sai. A câmera da Vangelico gira com WASD.
- [ ] **12.5** Assalto a banco com apagão (qbx_bankrobbery): as câmeras ficam "SEM SINAL". Quando a luz volta, voltam.
- [ ] **12.6** **Helicóptero** (passageiro, a mais de 1,5 m do chão):
  - E abre a câmera, e ela **não** fecha no mesmo frame;
  - clique direito troca visão noturna e térmica;
  - espaço trava num veículo, com modelo, placa, velocidade e rua;
  - E fecha.
- [ ] **12.7** H (piloto ou copiloto) liga o holofote, e B vê a luz.

## 13. Editor em jogo (`/policiaeditor`)

- [ ] **13.1** B e A sem admin: "Só administrador".
- [ ] **13.2** "Mostrar marcadores": aparecem os pontos com nome perto de A.
- [ ] **13.3** **Mover o ponto de serviço** de Mission Row por mira:
  - salva;
  - **sem restart**, a zona antiga some e a nova funciona para C (outro jogador).
- [ ] **13.4** **Nova garagem em Paleto:** ponto e vaga com viatura fantasma. Retirar viatura por ela nasce na vaga.
- [ ] **13.5** **Sala de evidências:** mudar o raio para 3 m; o depósito passa a funcionar mais longe.
- [ ] **13.6** **Radar:** adicionar com direção e limite, passar nele, e a multa usa o limite novo.
- [ ] **13.7** **Câmera:** "Adicionar câmera" parado olhando para um ponto. "Ver pela câmera" mostra o mesmo ângulo. Aparece na mesa de câmeras.
- [ ] **13.8** **Shotspotter:** adicionar um sensor e atirar perto dele: alerta.
- [ ] **13.9** Delegacia sem departamento: recusado com "Escolha ao menos um departamento válido", e o rascunho volta.
- [ ] **13.10** "Voltar ao config" em radares: voltam os do config, e a linha de `noir_police_layout` some.
- [ ] **13.11** Restart do servidor: as posições editadas continuam.
- [ ] **13.12** Arsenal de Paleto reposicionado pelo `/smartshopedit`: continua exigindo serviço e com limite de posse (teste 3.1 e 3.3 de novo).

## 14. Segurança (tentativas de abuso)

Com o F8 do cliente de B, ou por um executor de teste:
- [ ] **14.1** `TriggerServerEvent('noir_police:server:shot', {points = {{kind='casing', coords={0,0,0}}}})` longe da origem: nenhum ponto criado.
- [ ] **14.2** `LocalPlayer.state:set('isCuffed', false, true)` estando algemado: o servidor regrava para `true` (log `statebag_tamper`), e B continua preso.
- [ ] **14.3** `TriggerServerEvent('noir_police:server:alert', 'x')` 10 vezes seguidas: sai um alerta só por 30 s.
- [ ] **14.4** Callback de multa chamado por B (civil): "Só polícia em serviço".
- [ ] **14.5** `noir_police:server:bloodDrop` com coords a 500 m: ignorado.
- [ ] **14.6** Depositar a mesma caixa duas vezes (duplo clique): a segunda é recusada, e só um saco vai para a gaveta.

## 15. Desempenho

- [ ] **15.1** `resmon` com 2 policiais em serviço, parados: `noir_police` abaixo de 0,1 ms no cliente e no servidor.
- [ ] **15.2** Com a arma na mão atirando: o cliente não passa de ~0,3 ms.
- [ ] **15.3** Com o editor mostrando marcadores: o custo só existe enquanto está ligado.

## 16. Pendências fora deste roteiro

Não bloqueiam o teste; ficam anotadas:
- Áudio do ND (`assets/pending_audio`): o arquivo não mudou na conversão. Testar à parte com `customSound = true`; o áudio próprio do xt-prison não carregou no Enhanced.
- Fuga da prisão (hack dos portões): desligada até os portões da prisão serem cadastrados no ox_doorlock.
- O 911 do sky_phone ainda é só LSPD.
- Portas do ox_doorlock para BCSO e SASP.
- A sentença do ps-mdt (`police:client:SendToJail`) segue sem ouvinte, como antes.
- Rever o guarda-roupa do armário (nota do 9.2): como as roupas de serviço e a civil devem funcionar.
- Coldre na roupa (ND_GunAnims): os números do ND são de um pacote EUP; desligado em `data/holster.lua` e `data/animations.lua` até haver coldre de verdade.
- Rever a frota (nota do 8.1): talvez incorporar as viaturas da polícia no noir_garage.
- MLOs da prisão (Meetingroomprison, Prisoncanteen, Prisonmainblock) derrubaram o cliente no login: conferir antes de voltar com eles.
