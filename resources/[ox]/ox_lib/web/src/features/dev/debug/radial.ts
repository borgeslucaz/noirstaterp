import { debugData } from '../../../utils/debugData';
import type { RadialMenuItem } from '../../../typings';

export const debugRadial = () => {
  debugData<{ items: RadialMenuItem[]; sub?: boolean }>([
    {
      action: 'openRadialMenu',
      data: {
        items: [
          { icon: 'user', label: 'Cidadão' },
          { icon: 'car', label: 'Veículo' },
          { icon: 'warehouse', label: 'Garagem' },
          { icon: 'face-smile', label: 'Emotes' },
          { icon: 'star', label: 'Habilidades' },
          { icon: 'shirt', label: 'Roupas e acessórios' },
          { icon: 'briefcase', label: 'Trabalho' },
        ],
      },
    },
  ]);
};
