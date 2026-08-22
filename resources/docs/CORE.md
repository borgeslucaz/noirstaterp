# bgrz_core — Estado atual

> Resource 0.1.0 instalado. Este texto descreve apenas o comportamento existente.

## Função

bgrz_core é uma camada exclusivamente server-side sobre qbx_core. Hoje ele busca um jogador carregado no Qbox e apresenta os dados do personagem em formato normalizado para outros resources BGRZ.

Não substitui o Qbox e não controla login, inventário, economia ou persistência.

## Estrutura e inicialização

~~~text
bgrz_core/
├── fxmanifest.lua
├── shared/config.lua
└── server/
    ├── character.lua
    └── main.lua
~~~

A única dependência é qbx_core. Ao iniciar, consulta GetCoreVersion e imprime a versão do Qbox no console. server.cfg o inicia por ensure [bgrz], depois do Qbox.

## Configuração

shared/config.lua contém somente BGRZConfig.Debug. Atualmente está true e habilita o comando de teste. Não afeta outras funções.

## Export GetCharacter

Uso server-side:

~~~lua
local character, err = exports.bgrz_core:GetCharacter(source)
~~~

O export converte source para número, chama exports.qbx_core:GetPlayer(source) e normaliza PlayerData.

Retorno:

~~~text
character
├── source e citizenId
├── name: first, last, full
├── birthdate, nationality e phone
├── job: name, label, grade, gradeName, onDuty, isBoss
├── gang: name, label, grade, gradeName, isBoss
├── money: cash, bank
├── status: dead, handcuffed, jailTime
├── licenses
└── fingerprint
~~~

Dinheiro ausente vira 0. Estados booleanos só são verdadeiros quando o metadata é exatamente true. jailTime vem de metadata.injail.

| Erro | Causa |
|---|---|
| invalid_source | source inválido |
| player_not_found | jogador não carregado no Qbox |
| invalid_player_data | objeto sem PlayerData válido |

## Comando /bgrztest

Funciona apenas com debug ativo e deve ser executado por jogador. Chama GetCharacter, imprime o objeto no console e mostra nome/citizen ID em uma notificação. Não altera dados.

## Fora do escopo atual

Não existem API client-side, edição de personagem, validação própria de identidade, permissões/log externo ou APIs BGRZ de itens, empresas e reputação. Essas eram ideias futuras, não código ativo.

Veja também GENERAL.MD, IDENTITY.MD e SKILL.md.
