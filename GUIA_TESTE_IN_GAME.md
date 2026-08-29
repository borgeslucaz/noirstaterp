# Cipher — guia de teste in game

Este roteiro cobre a implementação que está ativa neste servidor. Faça os testes na ordem indicada, pois gangue, notoriedade, permissões e progressão liberam as funções seguintes.

## 1. Preparação

Use preferencialmente dois jogadores:

- **Jogador A:** administrador e futuro Boss.
- **Jogador B:** jogador comum, usado para convites, permissões, chat e co-op.

Comandos disponíveis:

| Comando | Uso |
|---|---|
| `/gangops` | Abre o Cipher sem precisar do item; ideal para testes. |
| `/admintablet` | Abre a administração; exige a ACE `cipher.admin`. |
| `/citizenid` ou `/cid` | Mostra o Citizen ID do personagem. |
| `/selldrug` | Tenta vender droga ao NPC mais próximo (até 4 m). |
| `/testmodel <modelo> [ped]` | Valida e exibe um modelo por 6 segundos; exige acesso admin. |

Checklist antes de entrar:

- O console deve mostrar `cipher` iniciado, sem erro de SQL ou dependência.
- `ox_lib`, `oxmysql`, `qbx_core`, `ox_inventory`, `ox_target` e `qbx_vehiclekeys` devem estar iniciados antes do Cipher.
- O banco deve ter recebido `resources/[standalone]/cipher/sql/cipher.sql`.
- O admin atual já herda `cipher.admin` pelo `group.admin` configurado no servidor.
- O item `cipher_tablet` já está registrado no `ox_inventory`; também é possível testar tudo com `/gangops`.

## 2. Teste básico do tablet e do admin

1. No Jogador A, use `/gangops`.
2. Confirme que o tablet abre, o personagem executa a animação e o foco do mouse funciona.
3. Feche pelo botão da interface e confirme que movimento/teclado voltam ao normal.
4. Abra `/admintablet` com o Jogador A. Deve abrir o painel com Dashboard, Gangs, Zones, Boosting, Blackmarket e Dealer.
5. Tente `/admintablet` no Jogador B. Deve aparecer uma mensagem de não autorizado.
6. No inventário, use um `Cipher Tablet` e confirme que ele abre a mesma interface sem consumir o item.

Resultado esperado sem gangue: o jogador comum vê somente o app **Boosting**. **Gang Ops** e **Blackmarket** aparecem apenas para membros de gangue.

## 3. Criar a gangue e testar membros

1. Jogador A: use `/cid` e anote seu Citizen ID.
2. Em `/admintablet` > **Gangs**, crie uma gangue e defina o Citizen ID do Jogador A como Boss.
3. Reabra `/gangops` no Jogador A. Confirme que aparecem os apps Gang Ops, Boosting e Blackmarket.
4. Deixe o Jogador B próximo e anote o ID de sessão dele (o número visto na lista de jogadores, não o Citizen ID).
5. Em **Gang Ops** > membros/roster, convide o Jogador B usando o ID de sessão.
6. No Jogador B, aceite o convite recebido.
7. Reabra o tablet do Jogador B e confirme gangue, rank `Prospect`, membros online e os novos apps.

Teste de permissões:

- Prospect não deve conseguir convidar, expulsar, promover, sacar, posicionar objetos ou comprar perks da gangue.
- Pelo Boss, promova B para `Soldier`: ele ganha acesso ao cofre, mas não a convite/banco.
- Promova para `Lieutenant`: ele também deve poder convidar.
- Promova para `Underboss`: ele deve poder expulsar/promover e sacar do banco.
- Volte-o para uma patente segura antes de testar a expulsão.

Também confira no roster: rep pessoal, status online, última atividade e ranking de contribuidores. A marca de inatividade só aparece após 7 dias sem abrir o tablet.

## 4. Banco da gangue

1. Com dinheiro na conta bancária do Jogador B, faça um depósito pequeno. Todo membro pode depositar.
2. Confira atualização do saldo e a entrada no extrato.
3. Como Prospect/Soldier, tente sacar: deve ser negado.
4. Como Boss ou Underboss, saque parte do valor: deve atualizar saldo, dinheiro do jogador e extrato.
5. No admin tablet, altere o saldo da gangue e confirme a atualização ao reabrir o Cipher.

Teste negativo: tente valor zero, negativo e maior que o saldo disponível. Nenhuma dessas operações deve alterar dinheiro ou saldo.

## 5. Territórios, notoriedade e níveis

Em `/admintablet` > **Zones**:

1. Atribua `Grove Street`, `Elysian Docks` ou `Vinewood Hills` à gangue.
2. Confirme a zona no mapa do tablet e o círculo/blip no mapa do jogo.
3. Renomeie uma zona, mova-a para a posição atual do admin e confirme a atualização.
4. Limpe o dono da zona e confirme que ela deixa de aparecer como território da gangue.

Em `/admintablet` > **Gangs**, use ajustes de notoriedade para testar rapidamente:

| Notoriedade | Tier | O que validar |
|---:|---|---|
| 0 | Unknown | Sem bancada liberada. |
| 1.000 | Local | Libera colocação da Crafting Bench. |
| 3.500 | Feared | Tier e raio visual da zona aumentam. |
| 7.000 | Notorious | Libera a receita avançada. |
| 10.000 | Notorious / nível 8 | Título `Untouchable` e progressão máxima. |

Confira também títulos de nível em 250, 750, 1.500, 3.000, 5.000 e 7.500 de notoriedade. Ao cruzar níveis, a gangue recebe pontos de perk.

Teste de fogo amigo: com A e B na mesma gangue, B mata A. A gangue deve perder 100 de notoriedade uma única vez.

## 6. Perks da gangue

Com pontos liberados pelo ajuste de notoriedade, abra **Perks** como Boss:

1. Compre o primeiro nível de Vault, Recruitment ou Workshop.
2. Confirme que não é possível comprar o nível 2 da mesma árvore antes do nível 1.
3. Confirme o desconto dos pontos e a persistência após fechar/reabrir o tablet.
4. Tente comprar com o Jogador B sem `manage_perks`: deve ser negado.

Efeitos fáceis de validar:

- `Reinforced Vault`: +25 slots e +25% de peso no cofre.
- `Open Doors`: aumenta o limite base de 30 membros em 10.
- `Quality Tools`: reduz o tempo de craft em 20%.
- `Bulk Production`: dá 25% de chance de saída em dobro; exige várias tentativas para observar.

## 7. Bancada, cofre e crafting

Use notoriedade 1.000 ou superior e entre como Boss:

1. Em **Unlocks**, posicione a Crafting Bench. Use scroll para distância, `Q/E` para girar e `Enter` para confirmar.
2. Posicione o Gang Vault pelo mesmo fluxo.
3. Interaja via `ox_target`; se ele não estiver iniciado, aproxime-se e use o prompt `[E]`.
4. Abra o cofre como Soldier ou superior e mova um item para dentro e para fora.
5. Tente abrir como Prospect: deve ser negado.
6. Remova/recoloque os objetos pelo tablet e confirme que o alvo antigo desaparece.

Crafts prontos para teste:

- **Lockpick (Local):** 5 `metalscrap` + 2 `plastic` -> 1 `lockpick`, em 5 s antes de perks.
- **Advanced Lockpick (Notorious):** 8 `metalscrap` + 4 `plastic` -> 3 `lockpick`, em 7 s antes de perks.

Teste negativo: inicie sem materiais e confirme que nada é produzido. A receita **Rope** não deve ser usada como teste positivo ainda, pois o item de saída `rope` não está registrado no inventário atual.

## 8. Tarefas

No app **Gang Ops** > **Tasks**, comece no rank `Rookie`.

### Package Run e Briefcase Run (nível 1)

1. Aceite a tarefa; uma `Speedo` e um encarregado devem surgir no ponto marcado.
2. Fale com o encarregado para carregar o pacote.
3. Dirija a van ao destino dentro de 10 minutos.
4. No destino, abra o porta-malas da própria van e retire o pacote.
5. Entregue-o ao NPC.
6. Leve a van de volta ao ponto inicial. A tarefa só termina depois da devolução.
7. Confira pagamento de rep/XP, atividade e progresso de conquista.

O Package Run tem 25% de chance de emboscada e paga 35 rep/25 XP. O Briefcase Run tem 40% de chance, paga 50 rep/35 XP. Como a chance é aleatória, ausência de emboscada não é falha.

### Tarefas liberadas por rank

- Nível 2 (150 XP): **Hit Contract** e **VIP Escort**.
- Nível 3 (400 XP): **Safehouse Job**.
- Co-op: **Crew Hit**, disponível somente por equipe.

Valide cancelamento, limite de tempo, morte do VIP e tentativa de concluir longe do objetivo. Hit Contract só aceita a morte após no mínimo 5 segundos. Safehouse Job segue `Infiltrate` (segurar 6 s) -> `Grab` -> `Escape`.

Observação: os pontos de Hit Contract, VIP Escort e Safehouse Job estão marcados no código como placeholders; erros de terreno nesses três casos são problema de configuração do mapa, não necessariamente da lógica da tarefa.

### Co-op de tarefas

1. Líder convida o Jogador B próximo e B aceita.
2. Confirme a equipe no tablet e aceite `Crew Hit`.
3. Somente o líder deve criar o alvo; os dois devem receber orientação/estado da tarefa.
4. Ao concluir, cada membro recebe XP completo; a recompensa ganha bônus de 25% e é dividida pela equipe.
5. Teste cancelar a equipe e convite acima do limite de 3 membros.

## 9. Boosting

Boosting funciona até para jogador sem gangue e está sem cooldown nesta configuração.

1. Aceite um contrato normal no app **Boosting**.
2. Use o círculo de busca (150 m), modelo e placa para localizar o carro; não há waypoint exato.
3. Ao chegar a 20 m, devem aparecer 2 guardas armados.
4. Arrombe/faça hotwire usando o sistema do `qbx_core`; o Cipher avança quando o motor liga.
5. Leve o veículo ao comprador marcado, estacione dentro de 15 m, saia e venda ao NPC.
6. Confira dinheiro, XP, total de carros, atividade recente, leaderboard e badge da primeira entrega.

Teste negativo: vá ao comprador sem o carro, leve outro carro, exceda 8 minutos ou cancele. Não deve haver recompensa.

Progressão atual: nível 1 oferece Blista/Asea; nível 2 começa em 100 XP e inclui Sultan; nível 3 começa em 300 XP e inclui Sultan RS. Há 2 veículos Wanted ativos, rotacionados a cada 30 minutos.

Teste de perks: o nível 1 já concede 1 ponto. Compre `Fence Connections`, `Thin the Crowd` ou `Quick Fingers`, conclua outro job e confira o efeito. Dispatch está desabilitado, portanto `Signal Jammer` não produz diferença observável agora.

Teste co-op: convide B, aceite o Sultan RS co-op, confirme 4 guardas, limite de 5 minutos, bônus de 25% antes da divisão do dinheiro e XP completo para cada integrante. Só o cliente do líder deve criar carro, guardas e comprador.

## 10. Blackmarket

Com A e B dentro de uma gangue:

1. Abra **Blackmarket** nos dois jogadores.
2. Confirme a criação e persistência de um handle anônimo.
3. Troque o handle e reabra o tablet; o novo valor deve permanecer.
4. Publique no chat mundial e confirme entrega ao vivo no outro cliente.
5. Envie DM usando o handle de B; responda e confira as threads/histórico.
6. Teste mensagem vazia e acima de 280 caracteres.
7. No admin tablet, localize mensagens recentes, apague uma e resolva handle -> Citizen ID.

Remova B da gangue e reabra o tablet: Blackmarket e Gang Ops devem sumir, mas Boosting deve continuar disponível.

## 11. Venda de drogas

Itens positivos existentes no inventário atual: `weed_brick` e `coke_brick`.

1. Dê uma unidade de um deles ao jogador.
2. Aproxime-se até 4 m de um NPC civil e use o alvo **Sell Drugs** ou `/selldrug`.
3. Aguarde a barra de 5 s e confira remoção de 1 item, pagamento em dinheiro e rep da gangue.
4. Repita fora de uma gangue: deve pagar dinheiro, mas não rep.
5. Tente sem item, sem NPC próximo e cancelando a barra.

Valores: Weed Brick paga $150/+8 rep; Cocaine Brick paga $280/+12 rep. `meth_brick` está configurado no Cipher, mas não existe no inventário atual e não serve para teste positivo.

## 12. Dealer

O fluxo pode ser aberto em **Tasks** > **Call Dealer**, não por objeto colocado. O cooldown está em 0 e o NPC expira em 10 minutos.

No estado atual, `Config.Dealer.pool` está vazio. Portanto, o resultado esperado é estoque vazio/aviso de que não há nada disponível. Para testar compra, será necessário adicionar ao menos um item válido ao pool e reiniciar o resource. Depois disso:

1. Chame o Dealer, siga até um dos pontos aleatórios e interaja com o NPC.
2. Compre com dinheiro suficiente e confira item, débito e ledger/log.
3. Tente sem dinheiro e confirme que nada é entregue.
4. No admin tablet, teste reroll de estoque e limpeza do cooldown.

## 13. Testes administrativos e encerramento

No `/admintablet`, valide por último:

- Dashboard atualiza totais de gangues, zonas, banco, boosting, chat e dealer.
- Busca e edição de level/XP/total/cash/perk points do Boosting persistem.
- Reset do Boosting zera também os perks comprados.
- Ajustes de rep pessoal, notoriedade, banco, patente e Boss persistem.
- Renomear gangue atualiza o tablet; disband remove membros e acesso aos apps restritos.

Webhooks de Discord estão vazios e, portanto, nenhum log externo será enviado no teste atual. Finalize conferindo o console F8 e o console do servidor: qualquer erro Lua, NUI, SQL, modelo inválido ou callback desconhecido deve ser anotado junto com a etapa que o causou.

## Resumo das limitações atuais

- Nenhuma gangue vem semeada em `Config.Gangs`: crie a primeira pelo admin tablet.
- Dealer sem itens (`pool = {}`): contato/estado pode ser testado, compra não.
- `rope` e `meth_brick` não existem no `ox_inventory` atual.
- Dispatch do Boosting está desligado.
- Webhooks do Discord estão desligados.
- Alguns locais das tarefas avançadas estão explicitamente marcados como placeholders.
