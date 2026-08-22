# Noir State RP — Manual Geral

> Documento consolidado do estado atual do servidor. Atualizado em 22 de agosto de 2026. Não é um roadmap: mudanças futuras serão documentadas somente depois de implementadas.

Este manual explica o que o Noir State RP já possui, como os jogadores usam cada sistema e onde a equipe técnica deve configurar ou manter cada parte. Ele foi produzido a partir dos resources e das configurações presentes no projeto, não apenas dos documentos de planejamento.

## 1. Visão geral

O Noir State RP roda sobre FiveM GTA V Enhanced e Qbox/QBX. A base está organizada em camadas:

```text
FiveM / FXServer
├── Qbox (personagens, empregos, veículos e gameplay)
├── OX (biblioteca, banco de dados, inventário, target, combustível e portas)
├── BGRZ/Noir (core próprio, multichar, chat e exemplos de interação)
├── sistemas standalone (telefone, aparência, banco, MDT, prisão etc.)
└── assets/mapas (Pillbox, IPLs e mapa)
```

Configuração principal:

```text
txData/Qbox_87A6E4.base/server.cfg
```

Resources:

```text
txData/Qbox_87A6E4.base/resources/
```

O servidor está configurado para até 48 jogadores, idioma `pt-BR` e game build 3258.

## 2. Primeiros passos do jogador

O fluxo normal é:

1. Conectar ao Noir State RP.
2. Aguardar a tela de carregamento personalizada.
3. Escolher um personagem no `noir_multichar` ou criar um novo.
4. Conferir nome, dinheiro, emprego e última localização na seleção.
5. Escolher a cena de apresentação, quando disponível.
6. Entrar com o personagem.
7. Em um personagem novo, nascer diretamente no ponto inicial e concluir a aparência pelo `illenium-appearance`.
8. Em personagens existentes, usar o seletor de spawn para entrar no mundo.

Cada conta possui até quatro slots por padrão. Slots extras também são suportados pelo banco de dados do multichar.

Itens iniciais configurados para novos personagens:

- telefone;
- documento de identidade;
- carteira de motorista.

As datas de nascimento aceitas pelo multichar estão atualmente entre 1970 e 2005.

## 3. Controles principais

As teclas podem ser alteradas pelo jogador nas configurações de keybind do FiveM. Os padrões configurados no servidor são:

| Ação | Tecla padrão | Sistema |
|---|---:|---|
| Abrir chat | `T` | `noir_chat` |
| Enviar mensagem | `Enter` | `noir_chat` |
| Fechar o chat | `Esc` | `noir_chat` |
| Abrir inventário | `Tab` | `ox_inventory` |
| Inventário secundário | `K` | `ox_inventory` |
| Hotbar | `F1` | `ox_inventory` |
| Interagir/target | `Alt esquerdo` | `ox_target` / `envi-interact` |
| Falar no rádio | `Alt esquerdo` | `pma-voice` |
| Alterar alcance da voz | acento grave (`GRAVE`) | `pma-voice` |

O chat não registra nenhuma ação na tecla `L`. Ela permanece livre para sistemas como trava de veículos. O comando `/toggleChat` continua disponível para alterar manualmente o estado visual do chat.

## 4. Sistemas próprios Noir/BGRZ

### 4.1 `bgrz_core`

Camada própria sobre o `qbx_core`. Centraliza uma visão normalizada dos dados do personagem e evita que novos resources BGRZ dependam diretamente da estrutura interna do Qbox.

Dados disponíveis pela API:

- source e citizen ID;
- nome completo, nascimento, nacionalidade e telefone;
- emprego, cargo, serviço e permissão de chefe;
- gangue e graduação;
- dinheiro em espécie e banco;
- estado de morte, algemas e prisão;
- licenças e impressão digital.

Uso server-side:

```lua
local character, err = exports.bgrz_core:GetCharacter(source)

if not character then
    print(('Erro ao carregar personagem: %s'):format(err))
    return
end

print(character.citizenId)
print(character.name.full)
print(character.job.name)
print(character.money.bank)
```

Erros possíveis: `invalid_source`, `player_not_found` e `invalid_player_data`.

O comando `/bgrztest` valida a integração e mostra uma notificação com o nome e citizen ID. Ele só funciona quando `BGRZConfig.Debug = true` em:

```text
[bgrz]/bgrz_core/shared/config.lua
```

Não mantenha o debug habilitado em produção.

### 4.2 `noir_multichar`

Sistema de seleção, criação, pré-visualização e exclusão de personagens com interface Noir. Integra-se ao Qbox, `ox_lib`, `oxmysql` e `illenium-appearance`.

Já implementado:

- até quatro personagens por conta por padrão;
- slots extras persistidos no banco;
- criação e exclusão de personagem;
- preview do ped e aplicação da aparência salva;
- dinheiro, emprego e última localização na seleção;
- foto de perfil;
- painel administrativo de slots;
- seletor de cenas com clima, horário, animação e veículo próprios;
- fluxo de logout e retorno à seleção;
- seletor de spawn após entrar;
- isolamento do jogador durante a seleção por routing bucket.

Cenas disponíveis atualmente:

- `casino`;
- `zancudo`;
- `sinner`;
- `confine`;
- `xmas`.

Comandos:

| Comando | Uso | Acesso |
|---|---|---|
| `/Logout` | Sai do personagem atual e retorna à seleção | jogador |
| `/editprofile` | Abre a edição da foto de perfil | jogador |
| `/profiles` | Gerencia slots de personagens | grupo `admin` |

Configuração principal:

```text
[bgrz]/noir_multichar/shared.lua
```

Alterações de slots, cenas, datas, spawn, itens iniciais ou comandos devem ser feitas nesse arquivo e seguidas de `restart noir_multichar` em ambiente de manutenção. Não reinicie o multichar com jogadores no fluxo de seleção/criação.

### 4.3 `noir_chat`

Substituição compatível do chat CFX. O manifest declara `provide 'chat'`, portanto resources que usam a API padrão continuam funcionando sem o chat original.

Uso pelo jogador:

- `T` abre a entrada;
- `Enter` envia;
- `Esc` cancela/fecha;
- mensagens iniciadas por `/` executam comandos permitidos;
- `L` não controla o chat;
- `/toggleChat visible`, `/toggleChat hidden` e `/toggleChat whenactive` alteram o estado manualmente.

Compatibilidade mantida:

```text
chat:addMessage
chat:addSuggestion
chat:addSuggestions
chat:removeSuggestion
chat:addTemplate
chat:addMode
chat:removeMode
chat:clear
chatMessage
__cfx_internal:serverPrint
```

Exemplo server-side:

```lua
TriggerClientEvent('chat:addMessage', source, {
    color = { 255, 255, 255 },
    args = { 'NOIR', 'Mensagem do sistema' }
})
```

Configuração:

```text
[standalone]/noir_chat/config.lua
```

O limite padrão é 500 caracteres e `Config.ToggleChatKey = false`. Não inicie o chat CFX original junto com o `noir_chat`.

### 4.4 `bgrz_interact_examples`

Showcase de `envi-interact` localizado no estacionamento da Legion Square. Serve como laboratório para criação de NPCs e diálogos, não como sistema econômico definitivo.

Use `/npctest` para teleportar até a área. Há um blip habilitado por padrão.

Os doze NPCs demonstram:

- guia e navegação entre exemplos;
- diálogo simples;
- barra de progresso;
- slider;
- menus encadeados;
- atualização dinâmica de fala;
- opções policiais;
- orçamento de táxi;
- entrevista;
- cardápio;
- quiz;
- respostas condicionais/relacionamento.

As ações são demonstrativas: não cobram, não entregam itens e não devem ser tratadas como gameplay final. Configure NPCs e o blip em:

```text
[bgrz]/bgrz_interact_examples/config.lua
```

## 5. Sistemas de gameplay instalados

### Personagem e interface

- `illenium-appearance`: aparência, roupas, cabelo, acessórios e persistência visual.
- `afterlife_mafiahud`: HUD ativo no lugar do `qbx_hud`.
- `loadscreen`: tela de carregamento personalizada.
- `qbx_spawn`: seleção de local de nascimento/spawn.
- `qbx_radialmenu`: menu radial de ações contextuais.
- `qbx_scoreboard`: placar/lista de jogadores.
- `qbx_idcard`: documentos de identificação.
- `scully_emotemenu`: animações e emotes.
- `neen-atlasmap-en2`: mapa/atlas customizado.

### Comunicação

- `pma-voice`: voz de proximidade, chamadas e rádio com áudio nativo e submix.
- `mm_radio`: interface e uso do rádio.
- `sd-phone`: telefone, aplicativos e chamadas.
- `noir_chat`: mensagens e comandos por texto.

O rádio está habilitado, com volume padrão 60; chamadas usam volume padrão 80. O modo inicial da voz é normal. Como target e rádio compartilham `Alt esquerdo`, conflitos de keybind devem ser resolvidos nas configurações do FiveM se atrapalharem o jogador.

### Inventário, itens e mundo

- `ox_inventory`: inventário de 50 slots e capacidade de 85 kg.
- `ox_target`: interações com entidades e zonas.
- `envi-interact`: diálogos e interações avançadas com NPCs.
- `ox_fuel`: abastecimento e consumo de combustível.
- `ox_doorlock`: controle de portas e permissões.
- `Renewed-Banking`: contas, saldos, depósitos, saques e transferências.
- `Renewed-Weathersync`: sincronização de clima e horário.
- `vehiclehandler`: suporte a comportamento de veículos.
- `qbx_vehiclekeys`: chaves e travas de veículos.
- `qbx_garages`, `qbx_vehicles`, `qbx_vehicleshop`, `qbx_vehiclesales`: persistência, garagem, loja e venda de veículos.
- `qbx_customs`, `qbx_carwash`: customização e lavagem.

O inventário possui loot aleatório em veículos e lixeiras, notificações de item/arma, props para drops e integração por target. Policiais dos empregos `police`, `bcso` e `sasp` têm integração com arsenal/evidências; a retirada de evidências requer grade mínima 2.

### Serviços e profissões

Estão instalados recursos para:

- polícia e atividades policiais (`qbx_police`);
- ambulância/medicina (`qbx_ambulancejob`, `qbx_medical`);
- mecânica (`qbx_mechanicjob`);
- administração de empresas e chefias (`qbx_management`);
- prefeitura/empregos (`qbx_cityhall`);
- taxista, motorista de ônibus, caminhoneiro, guincho e coleta de lixo;
- reciclagem, ferro-velho, vinhedo e jornalismo;
- propriedades (`qbx_properties`).

O trabalho disponível a cada jogador, seus pontos e permissões dependem da configuração do respectivo resource Qbox. O servidor limita o jogador a um emprego e uma gangue principais por vez.

Apartamentos iniciais estão desativados no Qbox. Personagens novos nascem no ponto configurado pelo `noir_multichar` e seguem diretamente para a aparência.

### Crime e atividades ilegais

Recursos instalados incluem:

- roubo a banco, joalheria, loja, residência e caminhão;
- drogas e cultivo de maconha;
- corridas de rua e corridas em circuito;
- prisão (`xt-prison`);
- penhor (`qbx_pawnshop`);
- minigames `mhacking`, `safecracker` e `ultra-voltlab`.

Esses resources fornecem a infraestrutura; disponibilidade, recompensas, exigência policial, cooldowns e locais são definidos nas configurações individuais.

### Polícia, saúde e administração

- `ps-mdt`: terminal policial/médico, ocorrências, pessoas, veículos, evidências e câmeras conforme permissões configuradas.
- `MugShotBase64` e `screencapture`: suporte a fotos e capturas usadas por outros sistemas.
- `qbx_adminmenu`: administração do servidor.
- `qbx_management`: gerenciamento de funcionários/organizações.
- `xt-prison`: fluxo de prisão.
- `pillbox`: asset/mapa do hospital.

As integrações opcionais FiveManage do MDT estão sem chave e, portanto, uploads/logs externos dependentes desse serviço não estão ativos.

## 6. Administração e operação

### Ordem de inicialização

A ordem relevante no `server.cfg` é:

```text
noir_chat
ox_lib
oxmysql
qbx_core
illenium-appearance
ox_inventory / ox_target / ox_fuel / ox_doorlock
envi-interact
[bgrz]
ps_lib / ps-mdt
[qbx]
[voice]
[standalone]
[assets]
```

O `qbx_hud` é parado intencionalmente porque foi substituído pelo `afterlife_mafiahud`.

### Comandos de manutenção

No console do servidor:

```text
refresh
ensure nome_do_resource
restart nome_do_resource
stop nome_do_resource
```

Exemplos:

```text
restart noir_chat
restart bgrz_core
restart bgrz_interact_examples
```

Use `restart noir_multichar` somente sem jogadores criando ou escolhendo personagens. Reinícios de `qbx_core`, `ox_inventory`, `oxmysql` ou resources de persistência devem ocorrer em manutenção, preferencialmente com o servidor vazio.

### Configurações importantes

| Área | Arquivo |
|---|---|
| Servidor e ordem de resources | `txData/Qbox_87A6E4.base/server.cfg` |
| Permissões/ACE | `txData/Qbox_87A6E4.base/permissions.cfg` |
| Voz | `txData/Qbox_87A6E4.base/voice.cfg` |
| OX/inventário/target | `txData/Qbox_87A6E4.base/ox.cfg` |
| Core BGRZ | `[bgrz]/bgrz_core/shared/config.lua` |
| Multichar | `[bgrz]/noir_multichar/shared.lua` |
| Chat | `[standalone]/noir_chat/config.lua` |
| NPCs demonstrativos | `[bgrz]/bgrz_interact_examples/config.lua` |

Nunca publique `server.cfg`, credenciais do banco, license key, webhooks ou tokens em documentação pública.

## 7. Desenvolvimento de novos resources BGRZ

Novos recursos devem preferir a API de `bgrz_core` para dados de personagem e validar no servidor qualquer informação recebida do cliente.

Manifest mínimo:

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Noir State'
description 'Descrição do sistema'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'qbx_core',
    'bgrz_core',
    'ox_lib'
}
```

Boas práticas do projeto:

- use o namespace BGRZ/Noir nos recursos próprios;
- não altere o `qbx_core` quando exports, eventos ou hooks resolverem;
- mantenha regras e validações importantes no servidor;
- não confie em valores monetários, itens, permissões ou IDs enviados pela NUI;
- use URLs NUI no formato `https://${GetParentResourceName()}/callback`;
- mantenha callbacks NUI com resposta (`cb`) em todos os caminhos;
- não hardcode o nome do resource em chamadas NUI;
- preserve contratos públicos ao substituir resources existentes;
- documente novas configurações e migrações SQL.

## 8. Sistemas que não estão instalados

Não existe atualmente uma pasta/resource `bgrz_identity` nem uma NUI BGRZ independente de criação visual.

No funcionamento atual:

- `noir_multichar` coleta os dados básicos e chama o Qbox;
- `qbx_core` cria, persiste, carrega e exclui o personagem;
- `illenium-appearance` fornece a aparência;
- `bgrz_core` oferece leitura normalizada dos dados já carregados.

`IDENTITY.MD` e `NUI.md` detalham exatamente essa divisão atual e indicam explicitamente o que não existe no código.

## 9. Diagnóstico rápido

### O chat não abre ou não envia

1. Confirme que `noir_chat` está iniciado.
2. Confirme que o chat CFX original não está rodando em paralelo.
3. Execute `restart noir_chat`.
4. Verifique se as callbacks usam HTTPS e o resource pai dinâmico.

### A tecla `L` ainda altera o chat

É provável que exista um keybind antigo salvo no perfil local do FiveM. Revise os keybinds do cliente. Não remova globalmente a tecla `L`, pois ela pode ser usada pela trava do veículo.

### Personagem não aparece na seleção

Verifique `qbx_core`, `oxmysql`, a tabela `players`, a tabela de slots do multichar e os erros do callback no console. Confirme também que `noir_multichar` iniciou após suas dependências.

### Aparência não carrega

Confirme que `illenium-appearance` está iniciado e que existe aparência persistida para o citizen ID. Verifique os callbacks de skin no adapter Qbox do multichar.

### Inventário ou target não abre

Confirme `ox_lib`, `qbx_core`, `ox_inventory` e `ox_target`, nessa ordem. Depois revise os keybinds locais, especialmente `Tab`, `K`, `F1` e `Alt esquerdo`.

### Voz ou rádio não funciona

Confirme `pma-voice`, `mm_radio`, permissões de microfone e conexão Mumble. Revise `voice.cfg` e possíveis conflitos de `Alt esquerdo`.

## 10. Documentação complementar

- `CORE.md`: arquitetura e API do `bgrz_core`.
- `CHAT.md`: requisitos e compatibilidade do `noir_chat`.
- `MULTICHAR.md`: especificação visual e funcional do `noir_multichar`.
- `IDENTITY.MD`: planejamento do domínio de identidade.
- `NUI.md`: planejamento da interface própria de criação.

Ao adicionar ou remover um sistema, atualize este arquivo e o documento específico correspondente.
