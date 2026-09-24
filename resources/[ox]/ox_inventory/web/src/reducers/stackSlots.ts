import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { getSlot, getTargetInventory, setSlot } from '../helpers';
import { Inventory, InventoryType, SlotWithItem, State } from '../typings';

export const stackSlotsReducer: CaseReducer<
  State,
  PayloadAction<{
    fromSlot: SlotWithItem;
    fromType: Inventory['type'];
    toSlot: SlotWithItem;
    toType: Inventory['type'];
    count: number;
  }>
> = (state, action) => {
  const { fromSlot, fromType, toSlot, toType, count } = action.payload;

  const { sourceInventory, targetInventory } = getTargetInventory(state, fromType, toType);

  const pieceWeight = fromSlot.weight / fromSlot.count;

  setSlot(targetInventory, toSlot.slot, {
    ...getSlot(targetInventory, toSlot.slot),
    count: toSlot.count + count,
    weight: pieceWeight * (toSlot.count + count),
  });

  if (fromType === InventoryType.SHOP || fromType === InventoryType.CRAFTING) return;

  setSlot(
    sourceInventory,
    fromSlot.slot,
    fromSlot.count - count > 0
      ? {
          ...getSlot(sourceInventory, fromSlot.slot),
          count: fromSlot.count - count,
          weight: pieceWeight * (fromSlot.count - count),
        }
      : {
          slot: fromSlot.slot,
        }
  );
};
