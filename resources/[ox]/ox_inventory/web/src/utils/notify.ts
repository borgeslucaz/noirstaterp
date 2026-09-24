import { fetchNui } from './fetchNui';

// Aviso para o jogador (lib.notify no cliente) quando uma regra recusa o movimento.
export const notify = (message: string) => {
  fetchNui('notify', message);
};
