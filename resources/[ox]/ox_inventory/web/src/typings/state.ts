import { Inventory } from './inventory';
import { Slot } from './slot';

export type State = {
  leftInventory: Inventory;
  rightInventory: Inventory;
  backpackInventory: Inventory;
  // equipment: slots de roupa cuja peca esta vestida (lido do ped)
  worn: number[];
  itemAmount: number;
  shiftPressed: boolean;
  isBusy: boolean;
  additionalMetadata: Array<{ metadata: string; value: string }>;
  history?: {
    leftInventory: Inventory;
    rightInventory: Inventory;
    backpackInventory: Inventory;
  };
};
