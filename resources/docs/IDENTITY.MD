# Identidade de personagem — Estado atual

## Situação

Não existe atualmente um resource chamado bgrz_identity no diretório [bgrz], nem ele é iniciado pelo server.cfg. Este arquivo não descreve um sistema independente: explica onde a identidade é tratada hoje.

## Responsabilidades atuais

~~~text
noir_multichar
├── formulário inicial
├── validação básica de campos vazios
└── envio para qbx_core

qbx_core
├── criação do personagem
├── citizen ID
├── PlayerData e persistência
└── carregamento/exclusão

illenium-appearance
├── aparência do ped
└── persistência em playerskins

bgrz_core
└── leitura normalizada da identidade já criada
~~~

## Dados coletados na criação

A NUI do noir_multichar solicita:

- primeiro nome;
- sobrenome;
- data de nascimento;
- nacionalidade;
- altura;
- gênero.

Antes de criar, o client Lua verifica apenas se nome, sobrenome, data e nacionalidade estão vazios. A seleção de data usa os limites 1970–2005 configurados.

Enviado ao qbx_core:

| Campo NUI | Campo Qbox | Observação |
|---|---|---|
| firstName | firstname | enviado diretamente |
| lastName | lastname | enviado diretamente |
| DOB | birthdate | enviado diretamente |
| nationality | nationality | enviado diretamente |
| gender | gender | Male = 0; outros = 1 |
| slot | cid | número escolhido |
| height | — | não é enviado atualmente |

Não há neste resource validação server-side própria de tamanho, caracteres permitidos, idade Hard RP, nomes proibidos ou duplicidade.

## Dados disponíveis depois da criação

bgrz_core:GetCharacter expõe citizen ID, nome, nascimento, nacionalidade, telefone, emprego, gangue, dinheiro, status, licenças e fingerprint. Ele é somente leitura: não edita a identidade.

## Aparência

noir_multichar consulta playerskins por citizen ID/model ativo e aplica a skin via illenium-appearance durante o preview.

O sistema atual não possui NUI BGRZ própria para genética/rosto. Depois do spawn direto do novo personagem, noir_multichar dispara qb-clothes:client:CreateFirstCharacter; illenium-appearance atende esse evento e conduz a criação visual.

## Documentos e itens iniciais

shared.lua declara phone, id_card e driver_license como itens iniciais. No caminho Qbox do próprio noir_multichar essa lista não é iterada. A entrega e os metadados desses itens dependem do qbx_core e dos demais resources instalados.

qbx_idcard fornece a infraestrutura de documentos. Não existe tabela BGRZ separada de identidade no estado atual.

## Persistência atual

- identidade base e PlayerData: banco/tabelas do Qbox;
- aparência: playerskins;
- slot: charinfo.cid no personagem;
- slots adicionais da conta: multicharacter_slots;
- foto visual do slot: KVP local do cliente.

## O que não está implementado

- resource bgrz_identity;
- workflow próprio em dez etapas;
- tabela bgrz_identities;
- flags identity_created/creator_completed;
- validação Hard RP dedicada;
- documentos BGRZ customizados;
- restrições próprias de edição pós-criação;
- adaptador BGRZ de aparência;
- NUI própria de genética/face/roupas.

Esses itens estavam descritos como arquitetura futura. Nenhum deve ser considerado disponível hoje.

## Como acompanhar o fluxo real

1. MULTICHAR.md: criação, seleção e payload.
2. CORE.md: leitura normalizada após o login.
3. NUI.md: telas frontend existentes.
4. GENERAL.MD: integração com o restante do servidor.
