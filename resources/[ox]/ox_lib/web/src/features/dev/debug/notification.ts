import { NotificationProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugCustomNotification = (position: NotificationProps['position'] = 'top-center') => {
  debugData<NotificationProps>([
    {
      action: 'notify',
      data: {
        title: 'Success',
        description: 'Notification description',
        type: 'success',
        id: 'pogchamp',
        duration: 20000,
        position,
        style: {
          '.description': {
            color: 'red',
          },
        },
      },
    },
  ]);
  debugData<NotificationProps>([
    {
      action: 'notify',
      data: {
        title: 'Error',
        description: 'Notification description',
        type: 'error',
        position,
      },
    },
  ]);
  debugData<NotificationProps>([
    {
      action: 'notify',
      data: {
        title: 'Custom icon success',
        description: 'Notification description',
        type: 'success',
        icon: 'microchip',
        showDuration: false,
        position,
      },
    },
  ]);
};
