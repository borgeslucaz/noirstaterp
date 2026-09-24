// equipment: slots de equipamento do jogador (corpo e roupas), definidos em
// modules/equipment/shared.lua e enviados no init. Ficam fora da grade.
export interface EquipmentSlotDef {
  slot: number;
  group: 'body' | 'clothing';
  name: string;
  label: string;
  items: string[];
  // roupa que quem revista pode tirar
  stealable?: boolean;
}

export const Equipment: { list: EquipmentSlotDef[]; bySlot: Record<number, EquipmentSlotDef> } = {
  list: [],
  bySlot: {},
};

export const setEquipment = (list: EquipmentSlotDef[] = []) => {
  Equipment.list = list;
  Equipment.bySlot = {};

  for (const def of list) Equipment.bySlot[def.slot] = def;
};
