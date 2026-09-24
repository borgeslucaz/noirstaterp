import InventoryGrid from './InventoryGrid';
import EquipmentSlots from './EquipmentSlots';
import { useAppSelector } from '../../store';
import { selectBackpackInventory, selectRightInventory } from '../../store/inventory';
import { InventoryType } from '../../typings';

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);
  const backpackInventory = useAppSelector(selectBackpackInventory);
  // equipment: a mochila equipada aparece embaixo, a menos que ja esteja aberta aqui pelo uso
  const showBackpack = backpackInventory.id !== '' && backpackInventory.id !== rightInventory.id;
  const otherPlayer = rightInventory.type === InventoryType.OTHERPLAYER;

  return (
    <div className={`inventory-column inventory-side${showBackpack ? ' with-backpack' : ''}`}>
      <InventoryGrid inventory={rightInventory} className={`right-panel${otherPlayer ? ' with-equipment' : ''}`}>
        {otherPlayer && (
          <EquipmentSlots
            inventory={rightInventory}
            className="equipment-strip"
            filter={(def) => def.group !== 'clothing' || !!def.stealable}
          />
        )}
      </InventoryGrid>
      {showBackpack && <InventoryGrid inventory={backpackInventory} className="backpack-panel" />}
    </div>
  );
};

export default RightInventory;
