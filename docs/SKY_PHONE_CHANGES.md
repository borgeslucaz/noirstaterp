# sky_phone — mudanças locais

Registro do que foi alterado ao trocar o sd-phone pelo [sky_phone](https://github.com/sky-systems/sky_phone),
para refazer tudo numa atualização ou reinstalação.

- Versão instalada: **1.0.1** (release `sky_phone-1.0.1.zip`, commit `8db471e2459fb222a91908aba9c8b9fb19b78b16`).
- Resource: `resources/[standalone]/sky_phone`.
- Patches de código: `resources/[standalone]/sky_phone/patches/`.
- Data: 2026-09-26/27.

---

## 1. Checklist de atualização

Ao trocar a versão do sky_phone, refazer nesta ordem:

1. Baixar o **zip da release** (não o "Source code" do GitHub, que vem sem a interface compilada) e conferir o `.sha256`.
2. Guardar a pasta atual (`config/`, `patches/`) antes de sobrescrever.
3. Reaplicar a config da seção 3 em `config/config.lua` e `config/media.lua`.
4. Reaplicar o patch do prop (seção 5.1).
5. Recompilar a interface com o patch da câmera (seção 5.2). **Sem isso, a câmera volta a sair com faixas em telas cuja largura não é múltipla de 64 px.**
6. Apagar a pasta `stream/` e a linha `data_file ... sky_phone_prop.ytyp` do `fxmanifest.lua` (seção 5.1).
7. Conferir que o ox_inventory continua sem o handler do NPWD (seção 4). Atualizar o ox_inventory pode trazê-lo de volta.
8. `restart sky_phone`, ou reiniciar o servidor se o ox_inventory também mudou.

---

## 2. Instalação e server.cfg

- sd-phone movido para `resources/[disabled]/sd-phone`. Backup completo em `/home/ubuntu/enhanced/backups/sd-phone-2026-09-26/`:
  - resources (`sd-phone` e `sd-phone-props`);
  - tabelas `phone_*`, `darkchat_*` etc.;
  - dump do banco inteiro;
  - `server.cfg`;
  - arquivos do ox_inventory.
- sky_phone usa tabelas próprias com prefixo `sky_phone_` e as cria sozinho. Ele não toca nas tabelas do sd-phone.
- `sd-phone-props` **continua ativo**: o sky_phone usa o prop dele (seção 5.1).

`server.cfg` (fora do git, porque tem segredos):

```cfg
ensure sd-phone-props
ensure sky_phone        # depois de oxmysql, qbx_core, ox_inventory e [voice]

set sky_phone_fivemanage_key "<token Media do FiveManage>"
```

---

## 3. Configuração (`config/config.lua` e `config/media.lua`)

| Opção | Valor | Motivo |
|---|---|---|
| `Config.PhoneConfigurator.Enabled` | `false` | Ligado, o `/phonepanel` grava a config no banco (`sky_phone_configurator`) e **ignora** este arquivo. Na instalação ele gravou os padrões do pacote, e nada do arquivo valia. |
| `Config.Bridge.Framework` | `"qbox"` | Explícito, sem autodetecção. |
| `Config.Bridge.Inventory` | `"ox"` | Explícito; havia `ox_inventory_old` em `[disabled]`. |
| `Config.Bridge.Locale` | `"pt"` | |
| `Config.Server.*Pepper` (4 valores) | aleatórios, gerados na instalação | Os padrões do pacote são públicos. **Não trocar de novo**: trocar invalida as senhas e passcodes existentes. Manter os valores atuais numa atualização. |
| `Config.Animations.PropModel` | `"sd_phone_black"` | Prop do sd-phone-props (seção 5.1). |
| `Config.Garage.VehicleKeySystem` | `"none"` | O mri_Qcarkeys (`provide 'qbx_vehiclekeys'`) não dá chave nova ao dono de carro de jogador e responde `false`; o valet lia isso como falha e abortava a entrega ("A entrega não pôde ser confirmada"). Carro de jogador abre com o item de chave. |
| `Config.Media.FiveManage.ApiKey` (`media.lua`) | `GetConvar("sky_phone_fivemanage_key", "")` | Chave fora do git. `media.lua` roda só no servidor. |

---

## 4. ox_inventory

- `modules/items/client.lua`: removido o handler `Item('phone', ...)` do **NPWD**. Ele interceptava o item `phone`, mesmo com o NPWD desligado.
- `data/items.lua`:
  - `phone` com `client.export = 'sky_phone.UsePhoneItem'` e o botão "Ejetar SIM" (`exports.sky_phone:EjectSimFromSlot`);
  - novos itens `sky_phone_sim_registered` e `sky_phone_sim_anonymous` (`client.export = 'sky_phone.UseSimItem'`);
  - imagens dos chips copiadas para `web/images/`.
- Os itens antigos do sd-phone (`phone_black`…`phone_yellow`, `sim_card`, powerbank, cabo) ficaram definidos, mas apontam para exports do sd-phone e não fazem nada.
- Hotbar: atalho removido de `client.lua` e `inventory:keys` reduzido para `["TAB", "K"]` no `ox.cfg`, para o **F1** ficar só com o celular. As teclas 1 a 5 continuam usando os slots.

---

## 5. Patches de código

### 5.1 Prop na mão: `patches/prop-sd-phone.patch`

Os props do sky_phone (`stream/phone_prop/*.ydr`) são **RSC7 versão 165**. O servidor espera 159 e pula os arquivos (`Rsc7 file ... has version 165, expected 159`). Por isso:

- a pasta `stream/` do sky_phone foi apagada e a linha `data_file 'DLC_ITYP_REQUEST' 'stream/phone_prop/sky_phone_prop.ytyp'` saiu do `fxmanifest.lua`;
- `source/shared/phone_prop.lua` → `SkyPhoneProp.Model`: com `PropModel = "sd_phone_black"`, devolve `sd_phone_<cor da moldura>`.
  - Cores existentes no sd-phone-props: black, blue, green, orange, pink, purple, red, yellow.
  - As outras molduras (lavender, white, gold, rgb…) caem no preto.

Aplicar: `patch -p1` a partir da pasta que contém `sky_phone/`, ou editar à mão. O patch é pequeno.

### 5.2 Câmera com faixas horizontais: `patches/camera-linhas-enhanced.patch`

**Sintoma:** no FiveM Enhanced, o visor, a foto e o vídeo saem com faixas horizontais quando a largura da tela **não é múltipla de 64 px** (ex.: 3024×1296, 3440×1440). 1920, 2560 e 3840 funcionam.

**Causa:**
- O Enhanced entrega a imagem do jogo para a interface com cada linha completada até um múltiplo de **256 bytes**.
- O CEF/ANGLE lê essa memória como se cada linha tivesse `largura × 4` bytes, sem a sobra.
- Cada linha começa alguns pixels depois do lugar certo, e isso vira as faixas.
- Não é bug do sky_phone. O screencapture, e com ele o mugshot do ps-mdt, tem o mesmo defeito.

**Como foi provado:**
- Uma captura do screencapture em 3024×1296, relida com **3072** px por linha (3024 × 4 = 12.096 bytes → próximo múltiplo de 256 = 12.288 = 3072 px), vira a imagem perfeita do jogo.
- A varredura de larguras de 1000 a 8192 apontou 3072 como única largura coerente.

**Correção (fragment shader em `frontend/src/utils/gameView.ts`):**
- Para cada pixel, calcula onde ele está de fato na memória com linhas preenchidas (`paddedRowPixels(w) = ceil(w*4/256)*64`) e lê esse pixel.
- Com largura já alinhada, o shader se comporta igual ao original.
- A textura tem **v=0 na base da imagem**, e a sobra das linhas está na ordem da memória, de cima para baixo. Por isso o shader converte para a ordem da memória, corrige e converte de volta. A primeira tentativa, sem essa inversão, não funcionou.
- As últimas ~1,6% das linhas não existem nos dados e se repetem na base. É imperceptível no visor.
- Visor, foto e vídeo usam o mesmo `gameView`, então os três ficam corrigidos.
- Testes em `gameView.test.ts` (`paddedRowPixels`); o mock de WebGL ganhou `uniform1f` e `uniform2f`.

**Rebuild da interface** (Node 22+; o pnpm roda via npx):

```bash
git clone https://github.com/sky-systems/sky_phone && cd sky_phone
git checkout <commit da release>          # ver SOURCE.txt do zip
git apply <caminho>/patches/camera-linhas-enhanced.patch
cd frontend
npx -y pnpm@10 install --frozen-lockfile
npx -y pnpm@10 exec vitest run src/utils/gameView.test.ts
npx -y pnpm@10 build                      # publica em ../sky_phone/source/html
rsync -a --delete ../sky_phone/source/html/ "<servidor>/resources/[standalone]/sky_phone/source/html/"
```

Copiar **só** `source/html`. O build também regenera `source/shared/config_default.lua` no clone, mas isso não interessa ao servidor.

Se um dia a Cfx corrigir o Enhanced, o shader passa a desalinhar imagens que já chegam certas. Sinal: faixas **no sentido contrário** em larguras fora dos 64 px. Aí é só voltar ao `gameView.ts` original.

**Como diagnosticar de novo, se voltar:** medir antes de mexer.
1. Capturar a tela com o screencapture em PNG, no modo `protocol 'nui'`.
2. Varrer larguras de linha até achar a que deixa as linhas vizinhas coerentes.
3. Remontar a imagem com essa largura pra confirmar.

---

## 6. Outros resources afetados

| Resource | Estado |
|---|---|
| **bgrz_core** | Provider de `phone` e `dispatch` ainda aponta para `sd-phone`. Com o sd-phone parado, as notificações e apps via bgrz_core retornam `provider_unavailable`. A API do sky_phone é outra (`SendCustomAppNotification`, `AddCustomAppPolicy`…), então falta um adaptador. |
| **ps-mdt** | `Config.Phone.Resource = 'sd-phone'`: número vem do `charinfo`; SMS e e-mail do tribunal desligados. `ps_mdt_fivemanage_key_images` recebeu o mesmo token FiveManage. O botão de mugshot não existe na interface dele (upstream). |
| **noir_drugselling** | Aviso de território por celular desligado (checa `sd-phone` started). |
| **noir_burnerphone** | Funciona, mas não fecha mais o celular principal ao abrir. |
| **screencapture** | `protocol 'nui'` no `fxmanifest.lua`. Em `http` o cliente dava `Failed to fetch` no upload. Tem o mesmo defeito de faixas da seção 5.2, sem correção. |

---

## 7. Mudanças relacionadas feitas na mesma sessão

- **Chat:** `noir_chat` voltou para `[standalone]` e `qbx_chat_theme` foi religado.
  - O chat embutido (`system_resources/chat`) sobe antes do `server.cfg`, mesmo com `set resources_useSystemChat false`. Por isso há `stop chat` antes do `ensure noir_chat`.
  - O L deixou de ser do chat; o T só executa comandos.
  - Com `Config.AllowPlayerMessages = false` no noir_chat, texto livre e comando inexistente são descartados em silêncio.
- **F1:** só o celular. Hotbar sem atalho (seção 4).

---

## 8. Voltar ao sd-phone

1. Mover `resources/[disabled]/sd-phone` de volta para `[standalone]`.
2. Restaurar `server.cfg` e os arquivos do ox_inventory a partir do backup (seção 2).
3. Apagar `resources/[standalone]/sky_phone`.

As tabelas `sky_phone_*` podem ficar no banco.
