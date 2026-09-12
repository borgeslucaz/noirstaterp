import React, { useCallback, useEffect, useRef, useState } from 'react';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import { Items } from '../../store/items';
import WeightBar from '../utils/WeightBar';
import ItemImage from '../utils/ItemImage';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { Slot, SlotWithItem } from '../../typings';

const HOTBAR_SLOT_COUNT = 5;
const HOTBAR_TIMEOUT = 3000;

/**
 * Presentation layer for ox_inventory's native hotkeys (inventory slots 1–5).
 * Keep the slot mapping in the upstream client; this component intentionally
 * has no custom binding or persistence contract with the Lua core.
 */
interface InventoryHotbarProps {
  inventoryOpen: boolean;
}

const InventoryHotbar: React.FC<InventoryHotbarProps> = ({ inventoryOpen }) => {
  const [hotbarVisible, setHotbarVisible] = useState(false);
  const inventoryItems = useAppSelector(selectLeftInventory).items;
  const items: Slot[] = Array.from({ length: HOTBAR_SLOT_COUNT }, (_, index) =>
    inventoryItems[index] || { slot: index + 1 }
  );
  const hideTimer = useRef<number | null>(null);

  const clearHideTimer = useCallback(() => {
    if (hideTimer.current === null) return;

    clearTimeout(hideTimer.current);
    hideTimer.current = null;
  }, []);

  useEffect(() => clearHideTimer, [clearHideTimer]);

  useNuiEvent('toggleHotbar', () => {
    clearHideTimer();
    setHotbarVisible(true);

    hideTimer.current = window.setTimeout(() => {
      hideTimer.current = null;
      setHotbarVisible(false);
    }, HOTBAR_TIMEOUT);
  });

  return (
    <div className={`hotbar-wrapper ${hotbarVisible || inventoryOpen ? 'hotbar-visible' : ''}`}>
      <div className="hotbar-container">
        {items.map((item) => (
          <div
            className={`hotbar-item-slot ${isSlotWithItem(item) ? '' : 'hotbar-slot-empty'}`}
            key={`hotbar-${item.slot}`}
          >
            <div className="hotbar-slot-noise" />
            <div className="hotbar-slot-number">{item.slot}</div>

            {isSlotWithItem(item) && (
              <div className="hotbar-item-wrapper">
                {item.count !== undefined && item.count > 0 && (
                  <div className="hotbar-slot-count">{item.count}</div>
                )}

                <ItemImage src={getItemUrl(item as SlotWithItem)} className="hotbar-slot-image" />

                <div className="hotbar-slot-label">
                  {item.metadata?.label ? item.metadata.label : Items[item.name]?.label || item.name}
                </div>

                {item.durability !== undefined && (
                  <div className="hotbar-slot-durability">
                    <WeightBar percent={item.durability} durability />
                  </div>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default InventoryHotbar;
