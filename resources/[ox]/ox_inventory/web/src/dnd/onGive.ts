import { store } from '../store';
import { Slot } from '../typings';
import { fetchNui } from '../utils/fetchNui';

// count: quantidade escolhida na janela do menu; sem ela vale a digitada no rodape
export const onGive = (item: Slot, count?: number) => {
  const {
    inventory: { itemAmount },
  } = store.getState();
  fetchNui('giveItem', { slot: item.slot, count: count ?? itemAmount });
};
