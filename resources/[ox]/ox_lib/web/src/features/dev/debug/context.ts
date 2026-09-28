import { ContextMenuProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugContext = () => {
  debugData<ContextMenuProps>([
    {
      action: 'showContext',
      data: {
        title: 'Garagem pública',
        menu: 'garage_root',
        options: [
          { title: 'Botão vazio' },
          {
            title: 'Karin Kuruma',
            description: 'Placa 12ABC345',
            icon: 'car',
            image: 'https://i.imgur.com/YAe7k17.jpeg',
            metadata: [
              { label: 'Carroceria', value: '55%', progress: 55, colorScheme: 'orange' },
              { label: 'Motor', value: '100%', progress: 100, colorScheme: 'green' },
              { label: 'Combustível', value: '11%', progress: 11, colorScheme: 'red' },
            ],
          },
          {
            title: 'Retirar do pátio',
            description: 'O veículo está na rua. Guarde-o antes de retirar.',
            icon: 'warehouse',
            metadata: [{ label: 'Taxa', value: '$500' }],
            disabled: true,
          },
          {
            title: 'Nível de óleo',
            description: 'Óleo restante no motor',
            progress: 30,
            icon: 'oil-can',
            colorScheme: 'orange',
          },
          {
            title: 'Durabilidade',
            progress: 80,
            icon: 'car-side',
            readOnly: true,
          },
          {
            title: 'Outro menu',
            icon: 'bars',
            menu: 'other_example_menu',
            description: 'Abre outro menu',
            metadata: ['Também tem metadados'],
          },
          {
            title: 'Um título bem comprido para ver como a linha quebra dentro da coluna',
            description: 'Envia um evento com argumentos',
            icon: 'check',
            event: 'some_event',
            args: { value1: 300, value2: 'Outro valor' },
          },
        ],
      },
    },
  ]);
};
