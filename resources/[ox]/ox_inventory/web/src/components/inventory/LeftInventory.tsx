import InventoryGrid from './InventoryGrid';
import InventorySlot from './InventorySlot';
import EquipmentSlots from './EquipmentSlots';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';

const HOTSLOTS = 5;

const LeftInventory: React.FC = () => {
  const leftInventory = useAppSelector(selectLeftInventory);
  const worn = useAppSelector((state) => state.inventory.worn);

  return (
    <>
      <EquipmentSlots
        inventory={leftInventory}
        className="clothing-rail"
        worn={worn}
        filter={(def) => def.group === 'clothing'}
      />
      <div className="inventory-column">
        <EquipmentSlots
          inventory={leftInventory}
          className="inventory-panel body-row"
          filter={(def) => def.group === 'body'}
        />
        <InventoryGrid inventory={leftInventory} start={HOTSLOTS} className="player-panel" />
        <div className="inventory-panel fast-slots">
          <div className="inventory-panel-header">
            <div className="inventory-panel-title">
              <p>Atalhos</p>
              <span>teclas 1 a {HOTSLOTS}</span>
            </div>
          </div>
          <div className="inventory-grid-container">
            {leftInventory.items.slice(0, HOTSLOTS).map((item) => (
              <InventorySlot
                key={`fast-${leftInventory.id}-${item.slot}`}
                item={item}
                inventoryType={leftInventory.type}
                inventoryGroups={leftInventory.groups}
                inventoryId={leftInventory.id}
              />
            ))}
          </div>
        </div>
      </div>
    </>
  );
};

export default LeftInventory;
