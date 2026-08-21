# bgrz_core

Core compartilhado do projeto **BGRZ**, desenvolvido sobre o **Qbox Framework** para centralizar regras, abstrações e APIs utilizadas pelos resources customizados do servidor.

O objetivo do `bgrz_core` não é substituir o `qbx_core`, mas criar uma camada própria entre o Qbox e os sistemas desenvolvidos para o servidor.

```text
qbx_core
    │
    ▼
bgrz_core
    │
    ├── bgrz_identity
    ├── bgrz_economy
    ├── bgrz_business
    ├── bgrz_contracts
    ├── bgrz_reputation
    ├── bgrz_crime
    ├── bgrz_doj
    └── ...
```

---

## Objetivos

O `bgrz_core` será responsável por:

* Criar uma abstração sobre o Qbox.
* Centralizar acesso aos dados dos personagens.
* Padronizar APIs utilizadas pelos resources BGRZ.
* Centralizar funções compartilhadas.
* Reduzir dependência direta dos resources com `qbx_core`.
* Facilitar futuras alterações de arquitetura.
* Centralizar validações server-side.
* Servir como base para economia, identidade, empresas e outros sistemas.

---

# Estrutura

```text
resources/
└── [bgrz]/
    └── bgrz_core/
        ├── fxmanifest.lua
        │
        ├── shared/
        │   └── config.lua
        │
        └── server/
            ├── character.lua
            └── main.lua
```

A estrutura será expandida conforme o projeto crescer.

Exemplo futuro:

```text
bgrz_core/
├── fxmanifest.lua
│
├── shared/
│   ├── config.lua
│   ├── constants.lua
│   └── utils.lua
│
├── server/
│   ├── main.lua
│   ├── character.lua
│   ├── validation.lua
│   ├── permissions.lua
│   └── logging.lua
│
└── client/
    └── main.lua
```

---

# Dependências

O resource depende inicialmente de:

```text
qbx_core
```

Outras dependências poderão ser adicionadas futuramente, como:

```text
ox_lib
oxmysql
```

---

# Instalação

Coloque o resource em:

```text
resources/[bgrz]/bgrz_core
```

Adicione ao `server.cfg`:

```cfg
ensure qbx_core
ensure bgrz_core
```

Ou, caso todos os resources BGRZ estejam dentro do mesmo diretório:

```cfg
ensure [bgrz]
```

O `qbx_core` deve iniciar antes do `bgrz_core`.

---

# fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'

author 'BGRZ'
description 'BGRZ Core - abstraction layer over Qbox'
version '0.1.0'

shared_scripts {
    'shared/config.lua'
}

server_scripts {
    'server/character.lua',
    'server/main.lua'
}

dependency 'qbx_core'
```

---

# Configuração

Arquivo:

```text
shared/config.lua
```

Configuração inicial:

```lua
BGRZConfig = {
    Debug = true
}
```

Durante desenvolvimento:

```lua
Debug = true
```

Em produção:

```lua
Debug = false
```

Posteriormente a configuração poderá ser dividida por sistema:

```lua
BGRZConfig = {
    Debug = false,

    Character = {},
    Security = {},
    Logging = {},
    Economy = {}
}
```

---

# Namespace

Todos os sistemas internos compartilhados pelo core utilizam o namespace:

```lua
BGRZ
```

Exemplo:

```lua
BGRZ = BGRZ or {}
```

Funções internas poderão ser acessadas como:

```lua
BGRZ.GetCharacter(source)
```

Para comunicação entre resources, devem ser utilizados exports.

Exemplo:

```lua
exports.bgrz_core:GetCharacter(source)
```

---

# Character API

O Qbox possui sua própria estrutura de `PlayerData`.

Por exemplo:

```lua
local player = exports.qbx_core:GetPlayer(source)

local citizenId = player.PlayerData.citizenid
local firstName = player.PlayerData.charinfo.firstname
local job = player.PlayerData.job.name
```

Resources BGRZ não devem depender dessa estrutura diretamente sempre que existir uma API correspondente no `bgrz_core`.

Em vez disso:

```lua
local character = exports.bgrz_core:GetCharacter(source)

print(character.citizenId)
print(character.name.first)
print(character.job.name)
```

---

# GetCharacter

Arquivo:

```text
server/character.lua
```

Implementação inicial:

```lua
BGRZ = BGRZ or {}

local function normalizeCharacter(player)
    if not player or not player.PlayerData then
        return nil
    end

    local data = player.PlayerData

    local charinfo = data.charinfo or {}
    local job = data.job or {}
    local jobGrade = job.grade or {}

    local gang = data.gang or {}
    local gangGrade = gang.grade or {}

    local metadata = data.metadata or {}
    local money = data.money or {}

    return {
        source = data.source,
        citizenId = data.citizenid,

        name = {
            first = charinfo.firstname,
            last = charinfo.lastname,

            full = string.format(
                '%s %s',
                charinfo.firstname or '',
                charinfo.lastname or ''
            )
        },

        birthdate = charinfo.birthdate,
        nationality = charinfo.nationality,
        phone = charinfo.phone,

        job = {
            name = job.name,
            label = job.label,
            grade = jobGrade.level,
            gradeName = jobGrade.name,
            onDuty = job.onduty == true,
            isBoss = job.isboss == true
        },

        gang = {
            name = gang.name,
            label = gang.label,
            grade = gangGrade.level,
            gradeName = gangGrade.name,
            isBoss = gang.isboss == true
        },

        money = {
            cash = money.cash or 0,
            bank = money.bank or 0
        },

        status = {
            dead = metadata.isdead == true,
            handcuffed = metadata.ishandcuffed == true,
            jailTime = metadata.injail or 0
        },

        licenses = metadata.licences or {},
        fingerprint = metadata.fingerprint
    }
end

function BGRZ.GetCharacter(source)
    source = tonumber(source)

    if not source then
        return nil, 'invalid_source'
    end

    local player = exports.qbx_core:GetPlayer(source)

    if not player then
        return nil, 'player_not_found'
    end

    local character = normalizeCharacter(player)

    if not character then
        return nil, 'invalid_player_data'
    end

    return character
end

exports('GetCharacter', BGRZ.GetCharacter)
```

---

# Retorno de GetCharacter

Exemplo:

```lua
{
    source = 1,

    citizenId = "ABC12345",

    name = {
        first = "John",
        last = "Smith",
        full = "John Smith"
    },

    birthdate = "01/01/1995",

    nationality = "American",

    phone = "555123456",

    job = {
        name = "unemployed",
        label = "Civilian",
        grade = 0,
        gradeName = "Freelancer",
        onDuty = false,
        isBoss = false
    },

    gang = {
        name = nil,
        label = nil,
        grade = nil,
        gradeName = nil,
        isBoss = false
    },

    money = {
        cash = 500,
        bank = 5000
    },

    status = {
        dead = false,
        handcuffed = false,
        jailTime = 0
    },

    licenses = {},

    fingerprint = "..."
}
```

---

# Utilizando em outros resources

Exemplo dentro do futuro `bgrz_business`:

```lua
RegisterNetEvent('bgrz_business:server:example', function()
    local src = source

    local character, err = exports.bgrz_core:GetCharacter(src)

    if not character then
        print(('Failed to load character: %s'):format(err))
        return
    end

    print(character.citizenId)
    print(character.name.full)
end)
```

Dessa forma o resource não precisa acessar diretamente:

```lua
exports.qbx_core:GetPlayer()
```

---

# Teste inicial

Arquivo:

```text
server/main.lua
```

```lua
BGRZ = BGRZ or {}

CreateThread(function()
    local version = exports.qbx_core:GetCoreVersion(
        GetCurrentResourceName()
    )

    print('-----------------------------------------')
    print('[BGRZ] bgrz_core started')
    print(('[BGRZ] Qbox version: %s'):format(version or 'unknown'))
    print('-----------------------------------------')
end)

RegisterCommand('bgrztest', function(source)
    if not BGRZConfig.Debug then
        return
    end

    if source == 0 then
        print('[BGRZ] /bgrztest precisa ser executado por um jogador.')
        return
    end

    local character, err = BGRZ.GetCharacter(source)

    if not character then
        print(
            ('[BGRZ] Failed getting character: %s')
                :format(err or 'unknown')
        )

        exports.qbx_core:Notify(
            source,
            'Não foi possível carregar seu personagem.',
            'error'
        )

        return
    end

    print('[BGRZ] Character loaded:')
    print(json.encode(character))

    exports.qbx_core:Notify(
        source,
        ('BGRZ Core OK | %s | %s'):format(
            character.name.full,
            character.citizenId
        ),
        'success',
        10000
    )
end, false)
```

---

# Testando

Após criar os arquivos:

```text
refresh
```

Depois:

```text
ensure bgrz_core
```

O console deve apresentar:

```text
-----------------------------------------
[BGRZ] bgrz_core started
[BGRZ] Qbox version: ...
-----------------------------------------
```

Entre no servidor com um personagem carregado e execute:

```text
/bgrztest
```

O jogador deve receber uma notificação semelhante a:

```text
BGRZ Core OK | John Smith | ABC12345
```

No console deverá aparecer o objeto normalizado do personagem.

---

# Regras de arquitetura

## 1. Não modificar o qbx_core

Evitar alterações diretas nos resources oficiais do Qbox.

```text
ERRADO

resources/[qbx]/qbx_core/
    ↳ código customizado BGRZ
```

Preferir:

```text
CERTO

qbx_core
    ↓
bgrz_core
    ↓
outros resources BGRZ
```

---

## 2. Client nunca deve decidir resultados importantes

Evitar eventos como:

```lua
TriggerServerEvent('bgrz_job:pay', 5000)
```

O client estaria dizendo ao servidor quanto deve receber.

Preferir:

```lua
TriggerServerEvent(
    'bgrz_contracts:server:finish',
    contractId
)
```

O servidor deve determinar:

```text
Contrato existe?
↓
Pertence ao personagem?
↓
Foi iniciado?
↓
Objetivos foram cumpridos?
↓
Localização é válida?
↓
Já foi pago?
↓
Calcular pagamento
↓
Pagar
```

---

## 3. Server authoritative

Dinheiro, itens, veículos, reputação, empresas e progressão devem sempre ser validados server-side.

O client deve ser utilizado principalmente para:

```text
UI
animações
interações
inputs
efeitos visuais
```

---

## 4. Utilizar citizenId

Dados persistentes relacionados ao personagem devem utilizar:

```text
citizenId
```

Evitar utilizar:

```text
source
```

como identificador persistente.

`source` existe apenas durante aquela conexão.

---

## 5. Resources pequenos e independentes

Evitar transformar `bgrz_core` em um resource gigante contendo toda a lógica do servidor.

Exemplo:

```text
bgrz_core
    → funções compartilhadas

bgrz_identity
    → identidade/documentos

bgrz_economy
    → economia/ledger

bgrz_business
    → empresas

bgrz_contracts
    → contratos

bgrz_reputation
    → reputação

bgrz_doj
    → justiça

bgrz_crime
    → progressão criminal
```

---

# Convenção de nomes

## Resources

```text
bgrz_core
bgrz_identity
bgrz_economy
bgrz_business
```

## Eventos

Utilizar:

```text
bgrz_resource:server:event
bgrz_resource:client:event
```

Exemplo:

```text
bgrz_business:server:createBusiness
bgrz_business:client:openManagement
```

## Exports

Utilizar PascalCase:

```lua
GetCharacter
GetBusiness
CreateTransaction
HasLicense
```

## Funções internas

Preferencialmente:

```lua
local function normalizeCharacter()
end
```

Quando precisarem ser compartilhadas internamente:

```lua
BGRZ.GetCharacter()
```

---

# O que NÃO pertence ao bgrz_core

O core não deve controlar diretamente:

```text
empresas
drogas
roubos
polícia
EMS
concessionária
propriedades
crafting
trabalhos
```

Esses sistemas devem possuir resources próprios.

---

# Roadmap do bgrz_core

## v0.1

* [x] Estrutura inicial.
* [x] Dependência com Qbox.
* [x] Namespace `BGRZ`.
* [x] `GetCharacter`.
* [x] Normalização do PlayerData.
* [x] Comando `/bgrztest`.

## v0.2

* [ ] Helpers compartilhados.
* [ ] Validação de `source`.
* [ ] Validação de personagem.
* [ ] Sistema padronizado de erros.
* [ ] Debug helpers.

## v0.3

* [ ] Sistema de logging.
* [ ] Audit API.
* [ ] Integração com `bgrz_audit`.

## v0.4

* [ ] Permission helpers.
* [ ] Job helpers.
* [ ] Gang helpers.
* [ ] Character state helpers.

## Futuro

O `bgrz_core` deverá oferecer APIs compartilhadas como:

```lua
exports.bgrz_core:GetCharacter(source)

exports.bgrz_core:GetCitizenId(source)

exports.bgrz_core:IsCharacterLoaded(source)

exports.bgrz_core:HasJob(source, job)

exports.bgrz_core:HasJobGrade(source, job, grade)

exports.bgrz_core:HasLicense(source, license)

exports.bgrz_core:Log(...)

exports.bgrz_core:Audit(...)
```

Essas APIs devem ser adicionadas apenas quando houver necessidade real nos demais resources.

---

# Próximo passo

Após validar que o `bgrz_core` está funcionando corretamente, o próximo módulo será:

```text
bgrz_identity
```

Responsável futuramente por:

```text
identidade
documentos
carteira de motorista
licenças
registros
dados civis
SSN / State ID
```

O princípio continuará sendo:

```text
Qbox fornece a fundação
        ↓
BGRZ adiciona as regras de Hard RP
```
