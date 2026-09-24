import React from 'react';
import { Equipment, EquipmentSlotDef } from '../../store/equipment';
import { getSlot, isSlotWithItem } from '../../helpers';
import { fetchNui } from '../../utils/fetchNui';
import { Inventory } from '../../typings';
import InventorySlot from './InventorySlot';

const groups: { group: EquipmentSlotDef['group']; label: string }[] = [
  { group: 'body', label: 'Corpo' },
  { group: 'clothing', label: 'Roupas' },
];

// equipment: slots de equipamento de um inventario de jogador (o proprio ou o de quem esta sendo revistado)
// worn: slots de roupa com a peca vestida; so no inventario do proprio jogador
const EquipmentSlots: React.FC<{ inventory: Inventory; className?: string; worn?: number[] }> = ({
  inventory,
  className,
  worn,
}) => (
  <div className={`equipment-slots${className ? ` ${className}` : ''}`}>
    {groups.map(({ group, label }) => {
      const defs = Equipment.list.filter((def) => def.group === group);

      if (defs.length === 0) return null;

      return (
        <section key={group} className={`equipment-group equipment-group-${group}`}>
          <h3>{label}</h3>
          <div className="equipment-grid">
            {defs.map((def) => {
              const item = getSlot(inventory, def.slot);
              const isWorn = !isSlotWithItem(item) && !!worn?.includes(def.slot);

              return (
                <InventorySlot
                  key={`${inventory.id}-equipment-${def.slot}`}
                  item={item}
                  inventoryType={inventory.type}
                  inventoryGroups={inventory.groups}
                  inventoryId={inventory.id}
                  emptyLabel={def.label}
                  emptyIcon={def.name}
                  worn={isWorn}
                  onEmptyClick={isWorn ? () => fetchNui('removeClothing', def.slot) : undefined}
                />
              );
            })}
          </div>
        </section>
      );
    })}
  </div>
);

export default EquipmentSlots;
