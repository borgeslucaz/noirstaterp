import { TextUiProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugTextUI = (position: TextUiProps['position'] = 'left-center') => {
  debugData<TextUiProps>([
    {
      action: 'textUi',
      data: {
        text: 'Abrir armário',
        key: 'E',
        position,
        icon: 'door-open',
      },
    },
  ]);
};
