import { NotificationProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugCustomNotification = (position: NotificationProps['position'] = 'top-center') => {
  debugData<NotificationProps>([
    {
      action: 'notify',
      data: {
        title: 'Veículo guardado',
        description: 'O Karin Kuruma está na garagem da Legion Square.',
        type: 'success',
        duration: 20000,
        position,
      },
    },
    {
      action: 'notify',
      data: {
        title: 'Sem dinheiro',
        description: 'Você precisa de **$5.000** na conta.',
        type: 'error',
        duration: 20000,
        position,
      },
    },
    {
      action: 'notify',
      data: {
        title: 'Combustível baixo',
        type: 'warning',
        duration: 20000,
        position,
      },
    },
    {
      action: 'notify',
      data: {
        description: 'Só descrição, sem título, com ícone próprio e sem contagem.',
        icon: 'microchip',
        showDuration: false,
        duration: 20000,
        position,
      },
    },
  ]);
};
