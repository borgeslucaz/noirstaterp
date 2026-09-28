import { debugData } from '../../../utils/debugData';
import { MenuSettings } from '../../../typings';

export const debugMenu = () => {
  debugData<MenuSettings>([
    {
      action: 'setMenu',
      data: {
        title: 'Mecânica',
        items: [
          { label: 'Reparar veículo', icon: 'wrench', description: '$1.250' },
          {
            label: 'Farol de neblina',
            icon: 'lightbulb',
            description: 'Liga e desliga o farol',
            checked: true,
          },
          {
            label: 'Classe do veículo',
            values: ['Esportivo', 'Sedã', { label: 'Off-road', description: 'Descrição do valor escolhido' }],
            icon: 'tag',
            description: 'Descrição geral da lista',
          },
          {
            label: 'Nível de óleo',
            progress: 30,
            icon: 'oil-can',
            description: 'Óleo restante: 30%',
            colorScheme: 'orange',
          },
          {
            label: 'Durabilidade',
            progress: 80,
            icon: 'car-side',
            description: 'Durabilidade: 80%',
            colorScheme: 'green',
          },
          { label: 'Suspensão', icon: 'arrows-up-down' },
          { label: 'Freios', icon: 'circle-stop' },
          {
            label: 'Rodas',
            values: ['Estoque', 'Esportiva', 'Muscle', 'Lowrider', 'SUV'],
            defaultIndex: 2,
          },
          { label: 'Blindagem', icon: 'shield' },
          { label: 'Turbo', icon: 'gauge-high', checked: false },
          {
            label: 'Cor primária',
            values: ['Preto', 'Branco', 'Vermelho'],
          },
        ],
      },
    },
  ]);
};
