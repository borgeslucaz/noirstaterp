import { createAsyncThunk } from '@reduxjs/toolkit';
import { setContainerWeight } from '../store/inventory';
import { fetchNui } from '../utils/fetchNui';

export const validateMove = createAsyncThunk(
  'inventory/validateMove',
  async (
    data: {
      fromSlot: number;
      fromType: string;
      toSlot: number;
      toType: string;
      count: number;
      containerId: string;
    },
    { rejectWithValue, dispatch }
  ) => {
    try {
      const { containerId, ...move } = data;
      const response = await fetchNui<boolean | number>('swapItems', move);

      if (response === false) return rejectWithValue(response);

      if (typeof response === 'number') dispatch(setContainerWeight({ id: containerId, weight: response }));
    } catch (error) {
      return rejectWithValue(false);
    }
  }
);
