import { TextUiProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugTextUI = (position: TextUiProps['position'] = 'left-center') => {
  debugData<TextUiProps>([
    {
      action: 'textUi',
      data: {
        text: 'Access locker inventory ',
        key: 'Q',
        position,
        icon: 'door-open',
      },
    },
  ]);
};
