# noir_multichar — Estado atual

> Resource 1.0.0 instalado. Esta documentação descreve o código runtime e a NUI que existem hoje.

## Função

noir_multichar controla entrada na sessão, lista de personagens, preview, criação, exclusão, cenas, foto de perfil, slots administrativos e logout. No servidor atual ele detecta qbx_core e usa o adapter Qbox.

O manifest ainda contém adapters QB e ESX e declara provide esx_multicharacter, mas eles ficam inativos quando Config.framework é qbx.

## Dependências usadas

- ox_lib: callbacks, cache e carregamento de models/animações;
- qbx_core: listar, criar, carregar, excluir e deslogar personagens;
- oxmysql: slots extras e leitura de skins/personagens;
- illenium-appearance: aplicar a aparência salva;
- qbx_spawn: seletor de spawn atualmente habilitado.

A NUI é React 18 + Redux Toolkit + Vite, com CSS/Tailwind e styled-components. O runtime carrega ui/dist/index.html.

## Entrada na seleção

Quando NetworkIsSessionStarted fica verdadeiro:

1. encerra as telas de loading;
2. esconde o radar;
3. move o jogador para bucket aleatório entre 1000 e 10000;
4. obtém os personagens do Qbox;
5. monta os slots;
6. cria cena, câmera, ped local e veículo opcional;
7. mostra a NUI e entrega foco a ela.

Clima do mundo é desativado durante o preview. A cena pode impor clima/horário e usa câmera com profundidade de campo.

## Slots e dados exibidos

Config.Maxslots é 4. GetPlayerMaxSlots soma esse valor ao adicional salvo em multicharacter_slots.

Para cada slot, a interface recebe:

- ID do slot;
- nome e sobrenome;
- citizen ID;
- sexo;
- indicador de slot vazio;
- URL da foto;
- dinheiro em espécie;
- label do emprego;
- última localização.

Última localização é calculada a partir de players.position. O client tenta resolver zona do GTA, depois rua; se falhar mostra DESCONHECIDO.

Slots vazios aparecem como NOVO PERSONAGEM e CRIE UMA NOVA HISTÓRIA.

## Interface de seleção

A tela atual possui:

- marca NOIR STATE ROLEPLAY;
- nome e número do slot;
- DINHEIRO, EMPREGO e ÚLTIMA LOCALIZAÇÃO;
- botão JOGAR COM PERSONAGEM ou CRIAR PERSONAGEM;
- carrossel de slots;
- configurações de cena;
- exclusão;
- contador de posição.

Controles: clique, setas esquerda/direita e Enter. Hover/clique disparam sons frontend do GTA.

Ao mudar de slot, PreviewCharacter reaplica model/skin ao PlayerPedId na cena atual.

## Cenas

A escolha é salva localmente no KVP IV:Multicharacter. Se não existir, usa a primeira cena. Configuração atual:

| ID | Horário | Clima | Veículo |
|---|---:|---|---|
| casino | 07:00 | EXTRASUNNY | banshee2 |
| zancudo | 20:00 | EXTRASUNNY | banshee2 |
| sinner | 12:00 | EXTRASUNNY | akuma |
| confine | 12:00 | EXTRASUNNY | nenhum |
| xmas | 20:00 | XMAS | nenhum |

Cada cena também define posição do ped, animação, câmera, FOV e possível veículo. Config.uniqueweathertime está true.

O menu Configurações exibe cards de cena; Escape volta à seleção.

## Carregar personagem existente

Ao jogar com slot ocupado:

1. fecha foco e interface;
2. faz fade out e destrói câmera/preview;
3. chama qbx_core:server:loadCharacter com citizen ID;
4. volta o jogador ao bucket Config.Routingbucket, atualmente 0;
5. como Config.SpawnSelector é true, abre qbx_spawn.

O caminho alternativo de última posição existe, mas não é usado enquanto SpawnSelector estiver true.

## Criar personagem

Ao escolher slot vazio, a câmera aproxima o ped e abre formulário com:

- nome;
- sobrenome;
- data de nascimento;
- nacionalidade;
- altura;
- gênero.

O callback Lua exige nome, sobrenome, data e nacionalidade não vazios. A NUI limita ano entre 1970 e 2005. O payload enviado ao Qbox contém nome, sobrenome, nacionalidade, nascimento, gênero e número do slot.

Gênero Male vira 0; qualquer outro valor vira 1. O campo altura existe na interface, mas não é repassado ao qbx_core na implementação atual.

Após criar, o jogador não recebe escolha de apartamento nem abre o qbx_spawn. O resource usa spawnmanager para colocá-lo diretamente em vector4(-1041.13, -2734.80, -0.20, 357.71), conclui os eventos de carregamento Qbox, aguarda os listeners estabilizarem e só então dispara qb-clothes:client:CreateFirstCharacter para abrir a aparência.

Config.SpawnSelector continua valendo para personagens existentes. A coordenada direta do personagem novo fica em Config.NewCharacterLocation.

Escape cancela o formulário e retorna a câmera para a seleção.

## Excluir personagem

A opção aparece apenas em slot ocupado. Após confirmação:

1. localiza o personagem pelo ID do slot;
2. chama qbx_core:server:deleteCharacter;
3. faz fade;
4. consulta novamente os personagens;
5. reconstrói a cena e a lista.

A exclusão é permanente conforme o comportamento do callback do Qbox. Não há lixeira/restore dentro deste resource.

## Fotos de perfil

Comando /editprofile:

- lista somente slots ocupados;
- permite informar uma URL;
- mostra preview;
- salva a URL no KVP local slotimgN.

Consequência: a foto pertence ao armazenamento local do cliente, não ao banco nem ao citizen ID. Outro computador/perfil pode não possuir a mesma foto, e reutilizar um slot pode reutilizar a chave desse slot.

## Painel administrativo

Comando /profiles. A abertura exige IsPlayerAceAllowed(source, command).

O painel:

- consulta todos os registros da tabela players;
- permite buscar pelo primeiro nome;
- mostra dados de perfil;
- consulta e altera slots extras por identifier.

IV:UpdateSlot valida tabela, número entre 0 e 20 e ACE command. O SQL noir_multichar.sql cria multicharacter_slots, com identifier como chave primária.

Config.AdminGroup = admin existe, porém no adapter Qbox a autorização efetiva é ACE command.

## Logout

/Logout chama qbx:Logout, aguarda e reconstrói a seleção. Canlogout está true e não é alterado por outro trecho deste resource.

## Configuração atual

Arquivo [bgrz]/noir_multichar/shared.lua:

- framework detectado automaticamente;
- ox_inventory habilitado;
- illenium detectado automaticamente;
- itens iniciais declarados: phone, id_card, driver_license;
- AdminCommand: profiles;
- ProfilEditorCommand: editprofile;
- apartamento inicial desativado também no qbx_core;
- spawn selector: true;
- máximo base: 4;
- identifier: license;
- routing bucket final: 0;
- idioma da NUI parcialmente em português.

No adapter Qbox atual, a criação usa diretamente callbacks do qbx_core. A lista Config.StarterItems não é consumida pelo adapter Qbox deste resource; entrega de itens depende do fluxo do Qbox/outros resources.

## Callbacks NUI ativos

~~~text
playcharacter
PreviewCharacter
CreateCharacter
DeleteCharacter
exitcharactercreator
UpdateScene
getcurrentscene
updateslot
GetSlots
saveprofilepicture
exit
hover
click
SOUND2
GetCharacters
GetAllCharacters
getConfig
~~~

Os callbacks OPTIONS, CREDIT, EXITGAME e algumas rotas antigas de confirmação estão comentados e não são funções ativas.

## Persistência

| Dado | Local |
|---|---|
| personagens | tabelas do qbx_core |
| aparência | playerskins |
| slots extras | multicharacter_slots |
| cena escolhida | KVP local IV:Multicharacter |
| foto do slot | KVP local slotimgN |

## Limitações observáveis

- não existe restore após exclusão;
- foto e cena são locais por cliente;
- altura preenchida não chega ao Qbox;
- Config.StarterItems não é usada pelo adapter Qbox;
- label de cena pode ficar vazia porque as entradas atuais não definem label;
- integrações QB/ESX estão presentes, mas não são o caminho ativo auditado;
- nomes internos IV e uma mensagem antiga afterlife permanecem por compatibilidade/histórico.
