import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { getSlot, getTargetInventory, itemDurability, setSlot } from '../helpers';
import { Inventory, SlotWithItem, State } from '../typings';

export const swapSlotsReducer: CaseReducer<
  State,
  PayloadAction<{
    fromSlot: SlotWithItem;
    fromType: Inventory['type'];
    toSlot: SlotWithItem;
    toType: Inventory['type'];
  }>
> = (state, action) => {
  const { fromSlot, fromType, toSlot, toType } = action.payload;
  const { sourceInventory, targetInventory } = getTargetInventory(state, fromType, toType);
  const curTime = Math.floor(Date.now() / 1000);
  const sourceItem = { ...getSlot(sourceInventory, fromSlot.slot) };
  const targetItem = { ...getSlot(targetInventory, toSlot.slot) };

  setSlot(sourceInventory, fromSlot.slot, {
    ...targetItem,
    slot: fromSlot.slot,
    durability: itemDurability(toSlot.metadata, curTime),
  });

  setSlot(targetInventory, toSlot.slot, {
    ...sourceItem,
    slot: toSlot.slot,
    durability: itemDurability(fromSlot.metadata, curTime),
  });
};
