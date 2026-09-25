import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { SlotWithItem } from '../typings';

export type AmountAction = 'split' | 'give' | 'drop';

interface ContextMenuState {
  coords: {
    x: number;
    y: number;
  } | null;
  item: SlotWithItem | null;
  // janela de quantidade aberta pelo menu (Dividir, Dar, Soltar)
  amountDialog: { action: AmountAction; item: SlotWithItem } | null;
}

const initialState: ContextMenuState = {
  coords: null,
  item: null,
  amountDialog: null,
};

export const contextMenuSlice = createSlice({
  name: 'contextMenu',
  initialState,
  reducers: {
    openContextMenu(state, action: PayloadAction<{ item: SlotWithItem; coords: { x: number; y: number } }>) {
      state.coords = action.payload.coords;
      state.item = action.payload.item;
    },
    closeContextMenu(state) {
      state.coords = null;
    },
    openAmountDialog(state, action: PayloadAction<{ action: AmountAction; item: SlotWithItem }>) {
      state.amountDialog = action.payload;
    },
    closeAmountDialog(state) {
      state.amountDialog = null;
    },
  },
});

export const { openContextMenu, closeContextMenu, openAmountDialog, closeAmountDialog } = contextMenuSlice.actions;

export default contextMenuSlice.reducer;
