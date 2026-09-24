import { Slot } from './slot';

export enum InventoryType {
  PLAYER = 'player',
  SHOP = 'shop',
  CONTAINER = 'container',
  CRAFTING = 'crafting',
  // equipment: mochila equipada, aberta ao lado do inventario
  BACKPACK = 'backpack',
  OTHERPLAYER = 'otherplayer',
}

export type Inventory = {
  id: string;
  type: string;
  slots: number;
  items: Slot[];
  // equipment: slots de equipamento (corpo e roupas) do jogador, fora da grade
  equipment?: Record<number, Slot>;
  weight?: number;
  maxWeight?: number;
  label?: string;
  groups?: Record<string, number>;
};
