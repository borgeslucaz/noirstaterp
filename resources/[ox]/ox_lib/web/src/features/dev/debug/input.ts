import { debugData } from '../../../utils/debugData';
import type { InputProps } from '../../../typings';

export const debugInput = () => {
  debugData<InputProps>([
    {
      action: 'openDialog',
      data: {
        heading: 'Armário da polícia',
        rows: [
          {
            type: 'input',
            label: 'Número do armário',
            placeholder: '420',
            description: 'Número gravado na porta do armário',
            required: true,
          },
          { type: 'input', label: 'Senha', password: true, icon: 'lock' },
          {
            type: 'select',
            label: 'Tipo de armário',
            options: [
              { value: 'pessoal', label: 'Pessoal' },
              { value: 'evidencias', label: 'Evidências' },
              { value: 'arsenal', label: 'Arsenal' },
            ],
          },
          { type: 'number', label: 'Quantidade', default: 3, min: 1, max: 10, icon: 'hashtag' },
          { type: 'checkbox', label: 'Trancar ao sair', checked: true },
          { type: 'slider', label: 'Volume do alarme', min: 10, max: 50, step: 2 },
          { type: 'textarea', label: 'Observação', placeholder: 'Opcional', autosize: true },
        ],
      },
    },
  ]);
};
