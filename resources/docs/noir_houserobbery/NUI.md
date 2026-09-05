# Implementar Checklist NUI + Atualizar Noise Bar — `noir_houserobbery`

## 1. Objetivo

Com base no sistema atual de loot do `noir_houserobbery`, implementar uma **Checklist de objetivos do roubo** exibida através de uma NUI discreta no lado esquerdo da tela.

A checklist deve mostrar todo o progresso necessário para concluir aquela sessão de roubo.

Exemplo:

```text
CHECKLIST

0/3 Vasculhar
Roubar Rolex
Roubar Notebook
```

Conforme os objetivos forem concluídos:

```text
CHECKLIST

✓ 3/3 Vasculhar
✓ Roubar Rolex
Roubar Notebook
```

Os objetivos concluídos devem permanecer visíveis, porém visualmente marcados como concluídos.

Preferencialmente:

* texto riscado;
* opacidade reduzida;
* check discreto;
* pequena transição visual.

Não remover imediatamente os objetivos concluídos da lista.

O jogador deve conseguir visualizar claramente tudo que:

* já foi feito;
* ainda falta fazer;
* pertence àquela sessão específica de roubo.

---

# 2. Posicionamento da Checklist

A checklist deve ficar no **lado esquerdo da tela, centralizada verticalmente**, com um pequeno offset horizontal em relação à borda.

Referência aproximada:

```text
┌───────────────────────────────────────────────┐
│                                               │
│                                               │
│   CHECKLIST                                   │
│   1/3 Vasculhar                               │
│   ✓ Roubar Rolex                              │
│   Roubar Notebook                             │
│                                               │
│                                               │
└───────────────────────────────────────────────┘
```

O posicionamento pode seguir como referência:

```css
position: fixed;
left: 24px;
top: 50%;
transform: translateY(-50%);
```

O valor de:

```text
24px
```

é apenas uma referência inicial.

Pode ser ajustado aproximadamente entre:

```text
20px - 40px
```

de acordo com o resultado visual e com o padrão definido em:

```text
docs/DESIGN.md
```

Requisitos:

* ficar no lado esquerdo;
* centralizada verticalmente;
* possuir pequeno offset da borda;
* não ficar encostada na lateral da tela;
* não ficar centralizada horizontalmente;
* não depender de uma resolução específica;
* permanecer visualmente estável conforme itens forem concluídos;
* suportar diferentes aspect ratios.

Deve funcionar corretamente em:

```text
16:9
16:10
21:9
32:9
ultrawide
```

Evitar posicionamento calculado manualmente com base em resolução fixa.

Utilizar CSS responsivo baseado em viewport.

---

# 3. Comportamento do tamanho da checklist

A checklist pode possuir quantidades diferentes de objetivos dependendo da residência.

Por exemplo:

```text
CHECKLIST

0/2 Vasculhar
Roubar Rolex
```

ou:

```text
CHECKLIST

0/6 Vasculhar
Roubar TV
Roubar Notebook
Roubar Câmera
Roubar Xbox
Roubar Guitarra
Roubar Rolex
```

A interface deve continuar visualmente centralizada.

Ao aumentar a quantidade de elementos, o container deve crescer preferencialmente ao redor do seu centro vertical.

Evitar o comportamento em que:

```text
a lista começa no centro
↓
novos itens fazem toda a UI descer
```

O centro visual da checklist deve continuar aproximadamente preso a:

```css
top: 50%;
transform: translateY(-50%);
```

---

# 4. Exibição da Checklist

A checklist deve aparecer somente enquanto o jogador estiver participando de uma sessão ativa de roubo.

Ela deve funcionar apenas como um tracker de objetivos.

Não criar uma interface grande semelhante a:

* menu;
* tablet;
* painel;
* janela;
* modal.

A ideia é ser uma UI pequena e discreta.

Estrutura aproximada:

```text
CHECKLIST

0/3 Vasculhar

Roubar Rolex
Roubar Notebook
Roubar Câmera
```

A interface não deve competir visualmente com:

* HUD;
* inventory;
* notifications;
* ox_target;
* demais elementos importantes da tela.

---

# 5. Toggle com tecla `J`

Adicionar suporte à tecla:

```text
J
```

para esconder ou mostrar a checklist.

Comportamento:

```text
J pressionado
    ↓
Checklist escondida
```

Depois:

```text
J pressionado novamente
    ↓
Checklist exibida
```

Esse toggle deve afetar apenas a visualização local daquele jogador.

Não deve modificar:

* estado da robbery session;
* progresso;
* loot;
* pickups;
* estado de outros jogadores;
* conclusão dos objetivos.

Exemplo:

```text
Player A esconde a checklist
Player B continua vendo normalmente
```

Se o jogador esconder a checklist e outro jogador concluir um objetivo:

```text
Checklist escondida

Player B pega Rolex

Estado:
Rolex = completed
```

Quando o Player A apertar `J` novamente:

```text
✓ Roubar Rolex
```

deve aparecer imediatamente atualizado.

---

# 6. Key Mapping

Não depender apenas de loops contendo:

```lua
IsControlJustPressed
```

para implementar o toggle.

Registrar corretamente um comando e utilizar:

```lua
RegisterKeyMapping
```

ou a abstração já utilizada atualmente pelo projeto.

Exemplo conceitual:

```text
command:
toggleRobberyChecklist

default key:
J
```

Isso permite que o jogador altere o bind através das configurações do FiveM.

---

# 7. Objetivo "Vasculhar"

O sistema atual possui pontos de interação usados para vasculhar objetos/localizações dentro da residência.

Esses pontos devem gerar um objetivo agregado:

```text
0/X Vasculhar
```

Onde:

```text
X = quantidade total de pontos pesquisáveis daquela residência
```

Exemplo:

```text
3 pontos configurados
```

Checklist inicial:

```text
0/3 Vasculhar
```

Depois que um for concluído:

```text
1/3 Vasculhar
```

Depois:

```text
2/3 Vasculhar
```

Quando todos forem concluídos:

```text
✓ 3/3 Vasculhar
```

O objetivo deve então possuir estado:

```lua
completed = true
```

---

# 8. Quantidade dinâmica de "Vasculhar"

Não hardcodar:

```text
3
```

O total deve ser derivado automaticamente da configuração daquela residência ou shell.

Exemplos válidos:

```text
0/1 Vasculhar
0/2 Vasculhar
0/3 Vasculhar
0/5 Vasculhar
0/8 Vasculhar
```

Se uma residência não possuir nenhum ponto do tipo vasculhar:

```text
total = 0
```

não adicionar a linha:

```text
0/0 Vasculhar
```

à checklist.

Nesse caso, simplesmente não criar esse objetivo.

---

# 9. Loot carregável

As props configuradas como loot carregável/pickup devem gerar objetivos individuais na checklist.

Adicionar suporte a um atributo amigável:

```lua
name
```

na configuração de cada pickup.

Exemplo:

```lua
{
    id = 'bedroom_watch_01',
    model = `p_watch_03`,
    name = 'Rolex',
}
```

A checklist deve mostrar:

```text
Roubar Rolex
```

Outro exemplo:

```lua
{
    id = 'livingroom_laptop_01',
    model = `prop_laptop_01a`,
    name = 'Notebook',
}
```

gera:

```text
Roubar Notebook
```

---

# 10. Nunca mostrar nome técnico da prop

A interface nunca deve utilizar diretamente:

```text
p_watch_03
prop_laptop_01a
prop_tv_flat_02
```

como label para o usuário.

Não mostrar:

```text
Roubar p_watch_03
```

Mostrar:

```text
Roubar Rolex
```

Não mostrar:

```text
Roubar prop_laptop_01a
```

Mostrar:

```text
Roubar Notebook
```

O atributo:

```lua
name
```

deve ser responsável pelo label apresentado ao jogador.

---

# 11. Identificador único para cada pickup

Cada pickup deve possuir um identificador único dentro da residência/sessão.

Exemplo:

```lua
{
    id = 'bedroom_watch_01',
    model = `p_watch_03`,
    name = 'Rolex',
}
```

Não utilizar apenas:

```text
model
```

ou:

```text
name
```

como identificador.

Isso é necessário porque uma residência pode possuir:

```text
2 notebooks
2 TVs
2 relógios
```

Exemplo:

```lua
{
    id = 'bedroom_laptop_01',
    model = `prop_laptop_01a`,
    name = 'Notebook',
}

{
    id = 'office_laptop_01',
    model = `prop_laptop_01a`,
    name = 'Notebook',
}
```

A checklist pode mostrar:

```text
Roubar Notebook
Roubar Notebook
```

mas internamente são objetivos diferentes.

---

# 12. Estado dos pickups

Cada pickup carregável deve gerar um objetivo próprio.

Exemplo de residência:

```text
3 pontos de Vasculhar

1 Rolex
1 Notebook
1 Câmera
```

Checklist:

```text
CHECKLIST

0/3 Vasculhar
Roubar Rolex
Roubar Notebook
Roubar Câmera
```

Depois:

```text
CHECKLIST

1/3 Vasculhar
✓ Roubar Rolex
Roubar Notebook
Roubar Câmera
```

---

# 13. Quando considerar um pickup concluído

Um pickup não deve ser concluído simplesmente quando o jogador:

* olha para ele;
* entra na área do target;
* abre o target;
* pressiona a interação;
* inicia uma animação que ainda pode falhar.

O objetivo deve ser marcado como concluído somente quando o sistema atual considerar que aquele objeto foi efetivamente:

```text
retirado da sua posição original
```

e entrou no fluxo de:

```text
carregado / roubado
```

A integração deve utilizar o evento ou transição de estado já existente no sistema de carry.

Não criar uma segunda lógica de detecção.

---

# 14. Checklist como apresentação, não fonte de verdade

A NUI nunca deve possuir a responsabilidade de determinar o progresso do roubo.

A NUI apenas renderiza dados.

A fonte de verdade deve continuar sendo a lógica do:

```text
noir_houserobbery
```

Estrutura conceitual:

```lua
checklist = {
    search = {
        current = 1,
        total = 3,
        completed = false,
    },

    pickups = {
        {
            id = 'watch_01',
            name = 'Rolex',
            completed = true,
        },

        {
            id = 'laptop_01',
            name = 'Notebook',
            completed = false,
        },
    }
}
```

A NUI deve receber apenas o estado necessário para renderizar.

---

# 15. Atualização orientada a eventos

Não implementar polling constante para verificar progresso.

Evitar:

```lua
CreateThread(function()
    while true do
        Wait(0)

        -- verificar todos os objetivos
    end
end)
```

Preferir:

```text
ação concluída
      ↓
estado da robbery atualizado
      ↓
checklist recalculada
      ↓
SendNUIMessage
```

Exemplo:

```text
loot pesquisado
↓
search.current += 1
↓
broadcast session update
↓
atualizar checklist
```

Outro:

```text
Rolex pego
↓
pickup watch_01 = completed
↓
broadcast session update
↓
atualizar checklist
```

---

# 16. Estado compartilhado da sessão

A checklist deve refletir o estado da **robbery session**, e não somente ações feitas pelo player local.

Isso é especialmente importante porque uma residência pode ser roubada por:

```text
2+ jogadores
```

participando da mesma sessão.

Exemplo:

```text
Player A
Player B

mesma robbery session
```

Player A vasculha uma gaveta:

```text
0/3
↓
1/3
```

Player B deve receber:

```text
1/3 Vasculhar
```

automaticamente.

---

# 17. Sincronização dos pickups

O mesmo vale para objetos carregáveis.

Exemplo:

```text
Player B pega o Rolex
```

Estado da sessão:

```lua
watch_01.completed = true
```

Todos os membros da sessão devem visualizar:

```text
✓ Roubar Rolex
```

Não criar uma checklist diferente para cada jogador em relação aos objetivos.

Apenas o estado de:

```text
hidden / visible
```

controlado pelo `J` deve ser local.

---

# 18. Jogador entrando depois na sessão

Caso a arquitetura atual permita que um jogador entre em uma sessão já iniciada, ele deve receber imediatamente o estado atual.

Exemplo:

Sessão já está em:

```text
2/3 Vasculhar
✓ Roubar Rolex
Roubar Notebook
```

O novo jogador não deve receber:

```text
0/3 Vasculhar
Roubar Rolex
Roubar Notebook
```

Ele deve receber:

```text
2/3 Vasculhar
✓ Roubar Rolex
Roubar Notebook
```

A interface deve ser construída a partir do estado atual da sessão.

---

# 19. Checklist completa

A checklist é considerada completa quando:

```text
todos os pontos Vasculhar foram concluídos
```

e:

```text
todos os pickups obrigatórios foram roubados
```

Exemplo:

```text
✓ 3/3 Vasculhar
✓ Roubar Rolex
✓ Roubar Notebook
✓ Roubar Câmera
```

Nesse momento:

```lua
checklistCompleted = true
```

---

# 20. Não finalizar imediatamente ao completar

Completar a checklist dentro da residência não deve imediatamente encerrar o roubo.

Fluxo correto:

```text
último objetivo concluído
        ↓
checklistCompleted = true
        ↓
jogadores continuam dentro da casa
        ↓
jogador sai da residência
        ↓
robbery pode ser finalizada
```

Isso é necessário porque o último objetivo pode ser um item carregável.

Exemplo:

```text
Player pega TV
↓
Checklist completa
↓
Player ainda precisa carregar TV até a saída
```

Não remover o shell ou finalizar a sessão enquanto ele ainda estiver realizando esse fluxo.

---

# 21. Finalização ao sair da casa

A nova condição de conclusão do roubo deve ser:

```text
Checklist completa
        +
saída válida da residência
        ↓
finalizar roubo
```

Ou conceitualmente:

```lua
if robbery.checklistCompleted and playerExitedHouse then
    finishRobbery()
end
```

Integrar isso ao lifecycle já existente.

Não criar um segundo fluxo independente de finalização.

---

# 22. Multiplayer e finalização

Como existem sessões compartilhadas entre múltiplos jogadores, a finalização precisa respeitar o comportamento atual da robbery session.

Não introduzir regras que possam causar:

```text
Player A sai
↓
shell deletado
↓
Player B ainda estava dentro
```

A checklist completa deve sinalizar que os objetivos foram concluídos.

O encerramento físico da instância deve continuar respeitando:

* players ativos na sessão;
* players ainda dentro do interior;
* lifecycle atual;
* cleanup seguro;
* routing bucket;
* entidades da sessão.

A nova checklist não deve quebrar a lógica multiplayer existente.

---

# 23. Saída com checklist incompleta

Caso o jogador saia da residência com objetivos restantes:

```text
1/3 Vasculhar
✓ Roubar Rolex
Roubar Notebook
```

isso não deve automaticamente resultar em:

```text
roubo concluído
```

Preservar a semântica atual para:

* abandono;
* cancelamento;
* saída antecipada;
* timeout;
* failure.

Não adicionar automaticamente recompensas ou sucesso parcial caso isso ainda não exista no projeto.

---

# 24. Objetivos obrigatórios

Inicialmente considerar todos os objetivos presentes na checklist como obrigatórios.

Ou seja:

```text
Vasculhar
Pickup 1
Pickup 2
Pickup 3
```

todos devem ser concluídos antes de:

```lua
checklistCompleted = true
```

Entretanto, estruturar o código de maneira que futuramente seja possível adicionar algo como:

```lua
required = true
```

sem precisar reescrever todo o sistema.

Exemplo futuro:

```lua
{
    id = 'cheap_radio',
    name = 'Rádio',
    required = false,
}
```

Não é necessário implementar loot opcional agora, apenas evitar arquitetura que impeça essa evolução.

---

# 25. Design da NUI

Antes de criar a NUI, verificar se existe alguma solução adequada no:

```text
ox_lib
```

que possa ser reutilizada.

Prioridade:

```text
1. ox_lib
2. componentes já existentes no projeto
3. NUI customizada
```

Caso não exista no `ox_lib` um componente que ofereça corretamente esse formato de checklist persistente, implementar NUI própria.

---

# 26. `docs/DESIGN.md`

Caso seja criada NUI customizada, o design deve obrigatoriamente seguir:

```text
docs/DESIGN.md
```

Utilizar o documento como referência para:

* tipografia;
* font weights;
* cores;
* transparência;
* spacing;
* backgrounds;
* bordas;
* border radius;
* sombras;
* animações;
* hierarquia visual;
* identidade visual.

Não criar um visual genérico que ignore os componentes e padrões existentes do servidor.

---

# 27. Visual da checklist

A checklist deve possuir um visual minimalista.

Exemplo aproximado:

```text
CHECKLIST

1/3 Vasculhar

✓ Roubar Rolex
  Roubar Notebook
✓ Roubar Câmera
```

Evitar elementos como:

* cards enormes;
* fundo sólido muito pesado;
* bordas chamativas;
* gradients fortes;
* glow;
* neon;
* animações arcade.

Ela deve parecer integrada à HUD do servidor.

---

# 28. Itens concluídos

Quando um objetivo for concluído, aplicar uma pequena transição.

Exemplo:

```text
Roubar Rolex
```

torna-se:

```text
✓ Roubar Rolex
```

com:

```text
line-through
opacidade reduzida
check
```

Algo conceitualmente como:

```css
.completed {
    text-decoration: line-through;
    opacity: 0.5;
}
```

Os valores finais devem seguir o `DESIGN.md`.

---

# 29. Animações

Utilizar animações muito discretas.

Exemplo:

```text
objective complete
↓
check fade-in
↓
texto recebe line-through
↓
opacity reduzida
```

Duração curta.

Evitar:

* bounce;
* zoom exagerado;
* pulse infinito;
* flash;
* shake;
* glow;
* efeitos sonoros desnecessários.

A proposta deve continuar imersiva.

---

# 30. Mostrar e esconder a NUI

Ao iniciar/entrar em uma robbery session:

```text
receber estado da sessão
↓
montar checklist
↓
mostrar checklist
```

Ao finalizar:

```text
finalizar sessão
↓
esconder checklist
↓
limpar estado local
```

Também remover corretamente a UI quando ocorrer:

* cancelamento;
* failure;
* player removed from session;
* resource stop;
* cleanup da robbery;
* erro que force encerramento da sessão.

Não permitir checklist presa na tela após o roubo terminar.

---

# 31. Toggle deve ser resetado adequadamente

Caso o jogador esconda a checklist:

```text
J
↓
hidden = true
```

e depois aquela robbery session termine, o estado local deve ser limpo.

Ao entrar em um novo roubo, seguir o comportamento definido pelo projeto.

Preferencialmente:

```text
nova robbery
↓
checklist visível novamente
```

para evitar que o jogador entre em outro roubo sem perceber que a UI continua escondida por uma configuração da sessão anterior.

Se houver sistema global de preferências locais já existente, pode ser integrado a ele.

---

# 32. Noise Bar

Substituir a implementação visual atual da barra de ruído.

A nova barra deve utilizar:

```text
ox_lib
```

sempre que houver um componente adequado.

Não colocar a nova noise bar dentro da NUI da checklist.

Checklist e Noise Bar devem continuar sendo responsabilidades visuais separadas.

---

# 33. Preservar lógica atual de Noise

A troca deve ocorrer prioritariamente na camada visual.

Preservar toda a lógica já existente relacionada a:

```text
noise value
increase
decrease
thresholds
warnings
alerts
NPC reactions
police chances
robbery consequences
```

Não modificar gameplay de noise sem necessidade.

Fluxo desejado:

```text
noise system atual
      ↓
noise state
      ↓
ox_lib UI
```

---

# 34. Escolha do componente ox_lib

Consultar a versão do `ox_lib` atualmente instalada no projeto.

Não assumir uma API inexistente.

Utilizar o componente disponível que mais se aproxime de uma barra de status/progresso persistente.

Caso o `ox_lib` não possua uma solução adequada para uma barra persistente de noise, reutilizar componentes existentes do projeto antes de criar algo novo.

Não adaptar de maneira artificial um componente projetado para outro propósito se isso gerar UX ruim.

---

# 35. Arquitetura

Preferir separar responsabilidades aproximadamente assim:

```text
Robbery Session
│
├── Search State
├── Pickup State
├── Noise State
└── Completion State
        │
        ↓
Client Session State
        │
        ├── Checklist UI
        └── Noise UI
```

A NUI não deve conhecer regras internas de gameplay.

Ela deve apenas receber algo semelhante a:

```lua
SendNUIMessage({
    action = 'updateChecklist',
    data = checklistState
})
```

---

# 36. Evitar múltiplas fontes de estado

Não manter simultaneamente:

```text
server checklist state
client checklist state
JS checklist state
```

como três estados independentes.

A lógica deve possuir uma fonte clara de verdade.

Preferencialmente:

```text
robbery session
```

mantém o estado compartilhado.

Client:

```text
recebe atualização
```

NUI:

```text
renderiza atualização
```

---

# 37. Eventos sugeridos

Não é obrigatório utilizar exatamente estes nomes, mas a arquitetura pode possuir eventos equivalentes:

```text
robbery:checklist:init
robbery:checklist:update
robbery:checklist:hide
robbery:checklist:show
robbery:search:completed
robbery:pickup:completed
robbery:session:completed
```

Antes de criar novos eventos, verificar os eventos já existentes no resource.

Reutilizar eventos existentes quando fizer sentido.

---

# 38. Estrutura conceitual da sessão

Uma robbery session pode possuir algo semelhante a:

```lua
session = {
    id = robberySessionId,

    search = {
        completed = 1,
        total = 3,
    },

    pickups = {
        ['watch_01'] = {
            name = 'Rolex',
            completed = true,
        },

        ['laptop_01'] = {
            name = 'Notebook',
            completed = false,
        },
    },

    checklistCompleted = false,
}
```

Não é necessário seguir exatamente esse schema se já existir uma estrutura melhor no projeto.

Adaptar à arquitetura existente.

---

# 39. Exemplo de configuração do loot

Exemplo conceitual:

```lua
loot = {
    search = {
        {
            id = 'bedroom_drawer_01',
            coords = vec3(...),
        },

        {
            id = 'kitchen_drawer_01',
            coords = vec3(...),
        },

        {
            id = 'wardrobe_01',
            coords = vec3(...),
        },
    },

    pickups = {
        {
            id = 'bedroom_watch_01',
            model = `p_watch_03`,
            name = 'Rolex',
            coords = vec4(...),
        },

        {
            id = 'office_laptop_01',
            model = `prop_laptop_01a`,
            name = 'Notebook',
            coords = vec4(...),
        },
    },
}
```

Geraria:

```text
CHECKLIST

0/3 Vasculhar
Roubar Rolex
Roubar Notebook
```

---

# 40. Exemplo de progresso

Estado inicial:

```text
CHECKLIST

0/3 Vasculhar
Roubar Rolex
Roubar Notebook
Roubar Câmera
```

Depois de vasculhar uma área:

```text
CHECKLIST

1/3 Vasculhar
Roubar Rolex
Roubar Notebook
Roubar Câmera
```

Depois de roubar Rolex:

```text
CHECKLIST

1/3 Vasculhar
✓ Roubar Rolex
Roubar Notebook
Roubar Câmera
```

Depois:

```text
CHECKLIST

3/3 Vasculhar
✓ Roubar Rolex
✓ Roubar Notebook
Roubar Câmera
```

Quando tudo terminar:

```text
CHECKLIST

✓ 3/3 Vasculhar
✓ Roubar Rolex
✓ Roubar Notebook
✓ Roubar Câmera
```

Nesse momento:

```text
checklistCompleted = true
```

---

# 41. Fluxo completo esperado

```text
Player inicia robbery
        ↓
Session é criada
        ↓
Loot da residência é definido
        ↓
Checklist é construída
        ↓
NUI aparece centralizada na esquerda
        ↓
Player vasculha local
        ↓
Checklist atualiza
        ↓
Player pega Rolex
        ↓
Checklist atualiza
        ↓
Outro player pega Notebook
        ↓
Checklist atualiza para todos
        ↓
Todos os objetivos são concluídos
        ↓
checklistCompleted = true
        ↓
Player(s) saem da residência
        ↓
Fluxo atual valida encerramento
        ↓
Session termina
        ↓
Cleanup
        ↓
Checklist desaparece
```

---

# 42. Performance

A implementação deve ser orientada a eventos.

Evitar:

```text
loops por frame
polling constante de loot
polling constante da checklist
reenvio constante do mesmo estado para NUI
```

Somente enviar atualização quando ocorrer uma alteração relevante.

Exemplo:

```text
0/3 -> 1/3
```

gera update.

Permanecer:

```text
1/3
```

não deve gerar mensagens repetidas constantemente.

---

# 43. Compatibilidade com multiplayer

Preservar integralmente:

* shared robbery sessions;
* 2+ jogadores dentro da mesma residência;
* routing buckets;
* sincronização de props;
* carry system;
* loot compartilhado;
* vehicle storage;
* disconnect;
* cleanup;
* session lifecycle.

A implementação da checklist não pode assumir que:

```text
1 robbery = 1 player
```

---

# 44. Compatibilidade com shells

Não alterar desnecessariamente:

```text
noir_shell
```

ou a arquitetura utilizada para criação dos interiores.

A checklist deve apenas consumir informações da robbery session.

Ela não deve ficar responsável por:

* criar shell;
* destruir shell;
* definir routing bucket;
* teleportar player;
* controlar entidades do shell.

---

# 45. Cleanup

Ao finalizar uma robbery session, garantir cleanup de:

```text
checklist state
NUI visibility
local session references
pickup objective state
search objective state
noise visual state
```

No caso de:

```text
onResourceStop
```

também garantir que:

```text
Checklist desapareça
Noise Bar desapareça
```

---

# 46. Critérios de aceite

A implementação só deve ser considerada concluída quando todos os seguintes cenários funcionarem.

### Cenário 1 — início

Residência possui:

```text
3 searches
Rolex
Notebook
```

Ao entrar:

```text
CHECKLIST

0/3 Vasculhar
Roubar Rolex
Roubar Notebook
```

---

### Cenário 2 — search

Player vasculha uma área:

```text
1/3 Vasculhar
```

---

### Cenário 3 — completar searches

Ao completar todos:

```text
✓ 3/3 Vasculhar
```

---

### Cenário 4 — pickup

Player pega Rolex:

```text
✓ Roubar Rolex
```

---

### Cenário 5 — objetos repetidos

Existem:

```text
Notebook #1
Notebook #2
```

Roubar um deles deve concluir apenas o objetivo correspondente.

---

### Cenário 6 — multiplayer

Player A vasculha um ponto.

Player B deve visualizar o novo progresso.

Player B pega Notebook.

Player A deve visualizar Notebook concluído.

---

### Cenário 7 — toggle

Player pressiona:

```text
J
```

A checklist desaparece.

Pressiona novamente:

```text
J
```

A checklist reaparece com o estado atual.

---

### Cenário 8 — checklist completa dentro da casa

Todos os objetivos são concluídos.

O roubo não termina imediatamente.

---

### Cenário 9 — saída depois da conclusão

Checklist está completa.

Player executa o fluxo normal de saída.

A robbery session pode então entrar no fluxo normal de finalização.

---

### Cenário 10 — saída incompleta

Checklist ainda possui objetivos pendentes.

Sair não deve ser interpretado automaticamente como sucesso.

---

### Cenário 11 — posição

Em resolução 1920x1080:

```text
Checklist centralizada verticalmente
Checklist no lado esquerdo
Checklist afastada alguns pixels da borda
```

---

### Cenário 12 — ultrawide

Em 21:9:

```text
Checklist continua centralizada verticalmente
Checklist continua próxima à lateral esquerda
```

Não deve migrar visualmente para o centro da tela.

---

### Cenário 13 — lista grande

Ao possuir vários pickups, o crescimento do container não deve fazer com que a interface simplesmente desça progressivamente.

Manter o centro vertical estável.

---

### Cenário 14 — cleanup

Finalizar/cancelar a session deve remover completamente:

```text
Checklist
Noise UI
estado local relacionado
```

---

# 47. Restrições

Não:

* reescrever todo o `noir_houserobbery`;
* criar nova arquitetura paralela de robbery;
* colocar regra de gameplay dentro do JavaScript;
* utilizar polling por frame para checklist;
* hardcodar quantidade de searches;
* identificar loot apenas pelo nome;
* identificar loot apenas pelo model;
* finalizar shell imediatamente quando checklist completar;
* quebrar multiplayer;
* criar UI incompatível com `docs/DESIGN.md`;
* duplicar a Noise Bar na NUI se o `ox_lib` atender;
* mostrar nomes técnicos de props para o jogador.

---

# 48. Prioridades da implementação

Seguir esta ordem:

```text
1. Analisar a estrutura atual do noir_houserobbery
2. Identificar fonte de verdade da robbery session
3. Identificar eventos atuais de search
4. Identificar eventos atuais de pickup/carry
5. Adicionar IDs e Names necessários aos pickups
6. Implementar estado agregado da checklist
7. Implementar sincronização multiplayer
8. Implementar lifecycle da checklist
9. Implementar NUI
10. Posicionar NUI centralizada verticalmente à esquerda
11. Implementar toggle via J / RegisterKeyMapping
12. Integrar conclusão ao fluxo existente de saída
13. Migrar Noise Bar para ox_lib
14. Implementar cleanup
15. Testar multiplayer e cenários de edge case
```

---

# 49. Resultado final esperado

O objetivo é transformar o roubo em uma atividade com objetivos claros sem quebrar a imersão.

Visualmente:

```text
          GAMEPLAY

   CHECKLIST

   2/3 Vasculhar

   ✓ Roubar Rolex
     Roubar Notebook
   ✓ Roubar Câmera
```

A checklist deve permanecer:

```text
lado esquerdo
+
centro vertical
+
pequeno offset horizontal
```

e funcionar como representação visual do estado real e sincronizado da robbery session.

A arquitetura final deve continuar permitindo expansão futura para:

* loot opcional;
* diferentes tiers de residência;
* objetivos especiais;
* cofres;
* chaves;
* alarmes;
* objetivos secretos;
* loot raro;
* diferentes requisitos de conclusão;

sem precisar reescrever o sistema de checklist.
