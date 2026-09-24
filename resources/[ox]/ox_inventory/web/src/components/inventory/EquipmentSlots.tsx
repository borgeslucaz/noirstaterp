import React from 'react';
import { Equipment, EquipmentSlotDef } from '../../store/equipment';
import { getSlot } from '../../helpers';
import { Inventory } from '../../typings';
import InventorySlot from './InventorySlot';

const groups: { group: EquipmentSlotDef['group']; label: string }[] = [
  { group: 'body', label: 'Corpo' },
  { group: 'clothing', label: 'Roupas' },
];

// equipment: slots de equipamento de um inventario de jogador (o proprio ou o de quem esta sendo revistado)
const EquipmentSlots: React.FC<{ inventory: Inventory; className?: string }> = ({ inventory, className }) => (
  <div className={`equipment-slots${className ? ` ${className}` : ''}`}>
    {groups.map(({ group, label }) => {
      const defs = Equipment.list.filter((def) => def.group === group);

      if (defs.length === 0) return null;

      return (
        <section key={group} className={`equipment-group equipment-group-${group}`}>
          <h3>{label}</h3>
          <div className="equipment-grid">
            {defs.map((def) => (
              <InventorySlot
                key={`${inventory.id}-equipment-${def.slot}`}
                item={getSlot(inventory, def.slot)}
                inventoryType={inventory.type}
                inventoryGroups={inventory.groups}
                inventoryId={inventory.id}
                emptyLabel={def.label}
                emptyIcon={def.name}
              />
            ))}
          </div>
        </section>
      );
    })}
  </div>
);

export default EquipmentSlots;
