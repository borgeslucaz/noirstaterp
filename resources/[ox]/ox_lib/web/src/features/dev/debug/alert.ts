import { debugData } from '../../../utils/debugData';
import { AlertProps } from '../../../typings';

export const debugAlert = () => {
  debugData<AlertProps>([
    {
      action: 'sendAlert',
      data: {
        header: 'Vender veículo',
        content:
          '**Karin Kuruma** placa 12ABC345\n\nO veículo sai da sua garagem e não pode ser recuperado depois.\n\nValor: **$18.500**',
        centered: true,
        cancel: true,
      },
    },
  ]);
};
