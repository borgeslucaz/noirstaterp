import { useNuiState } from '../../hooks/nuiState';

import SelectInput from './components/SelectInput';

import { PedSettings } from './interfaces';
import './Ped.css';

interface PedProps {
  settings: PedSettings;
  storedData: string;
  data: string;
  handleModelChange: (value: string) => void;
}

const Ped = ({ settings, storedData, data, handleModelChange }: PedProps) => {
  const { locales } = useNuiState();

  if (!locales) {
    return null;
  }

  return (
    <div className="ped-container">
        <SelectInput
          title={locales.ped.model}
          items={settings.model.items}
          defaultValue={data}
          clientValue={storedData}
          onChange={value => handleModelChange(value)}
        />
    </div>
  );
};

export default Ped;
