import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { createEmptyInventory, getItemData, hasEquipment, itemDurability } from '../helpers';
import { Items } from '../store/items';
import { Equipment } from '../store/equipment';
import { Inventory, Slot, State } from '../typings';

const prepareItem = (item: Slot, curTime: number) => {
  if (!item.name) return item;

  if (typeof Items[item.name] === 'undefined') {
    getItemData(item.name);
  }

  item.durability = itemDurability(item.metadata, curTime);
  return item;
};

const densifyItems = (inventory: Inventory, curTime: number): Slot[] =>
  Array.from(Array(inventory.slots), (_, index) => {
    const item = Object.values(inventory.items).find((item) => item?.slot === index + 1) || {
      slot: index + 1,
    };

    return prepareItem(item, curTime);
  });

// equipment: itens nos slots de equipamento ficam fora da grade
const equipmentItems = (inventory: Inventory, curTime: number): Record<number, Slot> | undefined => {
  if (!hasEquipment(inventory)) return;

  const equipment: Record<number, Slot> = {};

  // vindo do Lua os itens estao todos em items; num inventario ja montado, em equipment
  for (const item of [...Object.values(inventory.items), ...Object.values(inventory.equipment ?? {})]) {
    if (item && Equipment.bySlot[item.slot]) equipment[item.slot] = prepareItem(item, curTime);
  }

  return equipment;
};

const prepareInventory = (inventory: Inventory, curTime: number): Inventory => ({
  ...inventory,
  items: densifyItems(inventory, curTime),
  equipment: equipmentItems(inventory, curTime),
});

export const setupInventoryReducer: CaseReducer<
  State,
  PayloadAction<{
    leftInventory?: Inventory;
    rightInventory?: Inventory;
    // equipment: false fecha o painel da mochila; ausente mantem como esta
    backpackInventory?: Inventory | false;
  }>
> = (state, action) => {
  const { leftInventory, rightInventory, backpackInventory } = action.payload;
  const curTime = Math.floor(Date.now() / 1000);

  if (leftInventory) state.leftInventory = prepareInventory(leftInventory, curTime);

  if (rightInventory) state.rightInventory = prepareInventory(rightInventory, curTime);

  if (backpackInventory !== undefined)
    state.backpackInventory = backpackInventory
      ? prepareInventory(backpackInventory, curTime)
      : createEmptyInventory();

  state.shiftPressed = false;
  state.isBusy = false;
};
