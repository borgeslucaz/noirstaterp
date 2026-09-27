import { useState } from 'react';
import { Modal, TextInput, Button, Group } from '@mantine/core';
import { VehicleProps } from '../../utils/interface';
import { fetchNui } from '../../utils/fetchNui';

export const VehicleNameModal = ({ vehicle, maxLength, onUpdateName, onClose }: {
  vehicle: VehicleProps;
  maxLength: number;
  onUpdateName: (newName: string) => void;
  onClose: () => void;
}) => {
  const [newName, setNewName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);

  const trimmedName = newName.trim();
  const invalid = !trimmedName || trimmedName.length > maxLength || trimmedName === vehicle.name;

  const handleChangeName = async () => {
    if (isProcessing || invalid) return;

    setIsProcessing(true);
    setError(null);

    try {
      const result = await fetchNui<string | false>('updateVehicleName', { vehicleId: vehicle.id, newName: trimmedName }, {
        data: trimmedName,
        delay: 500
      });

      if (result) {
        onUpdateName(result);
        return;
      }
      setError('Não foi possível mudar o apelido.');
    } catch {
      setError('Não foi possível mudar o apelido.');
    }
    setIsProcessing(false);
  };

  return (
    <Modal
      opened
      onClose={onClose}
      title="Apelido do veículo"
      centered
      closeOnClickOutside={false}
      closeOnEscape={false}
      withCloseButton={false}
      className='text-[var(--mantine-color-dark-1)]'
    >
      <div className="mb-4">
        <TextInput
          label="Nome atual"
          value={vehicle.name}
          disabled
          mb="md"
        />

        <TextInput
          label="Novo apelido"
          description={`Até ${maxLength} caracteres`}
          value={newName}
          maxLength={maxLength}
          onChange={(e) => {
            setNewName(e.target.value);
            setError(null);
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') handleChangeName();
          }}
          error={error}
          mb="md"
          placeholder="Meu carro"
          autoFocus
        />
      </div>
      <Group mt="xl" justify='flex-end'>
        <Button variant="light" color='red' onClick={onClose} disabled={isProcessing}>
          Cancelar
        </Button>

        <Button variant='light' onClick={handleChangeName} loading={isProcessing} disabled={invalid || isProcessing}>
          Salvar
        </Button>
      </Group>
    </Modal>
  );
};
