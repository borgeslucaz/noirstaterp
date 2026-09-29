# Noir Guncraft

Advanced FiveM crafting system with weapon customization, placeable benches, and blueprint-based recipes. made with AI tools as an expiremnetal project.
## Screenshots
-Attachments Window!
<img src="https://i.vgy.me/Oilh2E.png" alt="Oilh2E.png">
<img src="https://i.vgy.me/b7kxBB.png" alt="b7kxBB.png">
-Crafting Window!
<img src="https://i.vgy.me/cy2c4N.png" alt="cy2c4N.png">

## Features

- **Placeable Crafting Benches** — Deploy custom crafting stations anywhere
- **Blueprint System** — Unlock recipes via consumable blueprints
- **Three-Stash Storage** — Separate materials, blueprints, and finished items
- **Weapon Customization** — Preview and attach components directly in the UI
- **Framework Support** — Auto-detects QB-Core/QBX-Core
- **Target Integration** — Works with qb-target, ox_target, or interact

## Dependencies

### Required
- [ox_inventory](https://github.com/overextended/ox_inventory) (v2.41.0+)
- [oxmysql](https://github.com/overextended/oxmysql)
- [object_gizmo](https://github.com/DemiAutomatic/object_gizmo)

### Framework (Auto-detected)
- [qbx_core](https://github.com/Qbox-project/qbx_core) **OR** [qb-core](https://github.com/qbcore-framework/qb-core)

### Target System (Choose One)
- [ox_target](https://github.com/overextended/ox_target) **OR** [qb-target](https://github.com/qbcore-framework/qb-target) **OR** [interact](https://github.com/darktrovx/interact)

## Installation

1. `ensure object_gizmo` e `ensure noir_guncraft` no server.cfg, depois do ox_inventory.
2. As tabelas (`noir_guncraft_benches`, `noir_guncraft_queue`) são criadas sozinhas
   no `MySQL.ready`. O `database_complete.sql` fica só como referência do schema.
3. Registrar os itens em `ox_inventory/data/items.lua`: `crafting_bench`,
   os materiais das receitas e um item por blueprint de `config/blueprints.lua`.

## Configuration

### Adding New Recipes

Edit `config/recipes.lua`:

```lua
['item_name'] = {
    label = 'Item Display Name',
    materials = { steel = 5, aluminum = 3 },
    time = 30000, -- milliseconds
    blueprint = 'blueprint_item_name',
    prop = 'prop_model_name', -- optional
    massCraft = true -- optional, for stackable items
}
```

Remember to add the blueprint item to both `ox_inventory/data/items.lua` and `config/blueprints.lua`.

### Disabling Direct Component Equipping

To force players to use crafting benches for weapon customization, see [disableoxcomponents.md](disableoxcomponents.md).

## Commands

- `/pickupbench` - Pickup your placed crafting bench (Owner only)
- `/refundbench <serial>` - Refund a crafting bench by serial number in case of lost bench during pick up and placing (Admin only)

## Support

This is a **free** resource provided **as-is** with no guaranteed support.

- Report issues: [GitHub Issues](https://github.com/Nmil4/noir_guncraft/issues)

---

## Diferenças em relação ao upstream

Fork de [Nmil4/n4-crafting](https://github.com/Nmil4/n4-crafting). O que mudou:

**Segurança.** Nenhum evento de rede do upstream conferia dono ou distância, e o
`benchId` é um inteiro sequencial — dava para abrir a stash, craftar e cancelar a
fila de qualquer bancada do servidor chutando ids. Todo evento passa agora por
`server/access.lua`. Colocar bancada consome o item de verdade (antes, um slot
inválido fazia o `RemoveItem` falhar em silêncio e a bancada nascia de graça).
`quantity` é normalizada: valor negativo devolvia usos ao blueprint.

**Duplicação.** `cancelCraft` criava um blueprint do nada quando não achava o
original na stash, o que dava blueprint infinito. `equipAccessory` gravava a
metadata da arma antes de consumir o item e não checava retorno, o que duplicava
o attachment.

**Perda de item.** A limpeza periódica apagava craft pronto e não coletado sem
devolver nada. Agora o item vai para a storage da bancada antes de a linha sair.

**Performance.** As bancadas viram objeto por distância (`Config.StreamDistance`),
em vez de um `CreateObject` por bancada do servidor em todo cliente, para sempre.

**Outros.** Tabelas com prefixo; `Config.Stashes` no lugar dos 5.000.000g fixos;
webhooks do Discord ligados de fato (o módulo existia e nada o chamava); `Logger`
indefinido em `camera.lua`; carregamentos de modelo com timeout; a varredura de
`GetGamePool('CObject')` que apagava qualquer prop num raio de 2 m da bancada;
eventos de notificação unificados; `qb-core` hardcoded em `weapon_attachments.lua`.
