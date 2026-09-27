import React, { useState, useEffect } from 'react';
import { Modal, Button, NativeSelect, Group, Text, Loader } from '@mantine/core';

import { GarageOption, VehicleProps, formatMoney } from "../../utils/interface";
import { fetchNui } from '../../utils/fetchNui';

export const ChangeGarageModal: React.FC<{
    vehicle: VehicleProps;
    price: number;
    onClose: () => void;
    onTransferSuccess: (vehicleId: number) => void;
}> = ({
    vehicle,
    price,
    onClose,
    onTransferSuccess
}) => {
    const [selectedGarage, setSelectedGarage] = useState<string>('');
    const [garageList, setGarageList] = useState<GarageOption[]>([]);
    const [isLoadingGarages, setIsLoadingGarages] = useState(true);
    const [isTransferring, setIsTransferring] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        let active = true;

        fetchNui<GarageOption[]>('getGarageList', { vehicleId: vehicle.id }, {
            data: [
                { value: 'motelgarage', label: 'Motel Parking' },
                { value: 'pillboxgarage', label: 'Pillbox Garage Parking' },
            ],
            delay: 300
        })
        .then(response => {
            if (!active) return;
            const list = Array.isArray(response) ? response : [];
            setGarageList(list);
            if (list.length === 0) setError('Nenhuma garagem disponível para este veículo.');
        })
        .catch(() => {
            if (active) setError('Não foi possível carregar as garagens.');
        })
        .finally(() => {
            if (active) setIsLoadingGarages(false);
        });

        return () => { active = false; };
    }, [vehicle.id]);

    const handleTransfer = async () => {
        if (isTransferring || !selectedGarage) return;

        setIsTransferring(true);
        setError(null);

        try {
            const success = await fetchNui<boolean>('updateGarageName', { vehicleId: vehicle.id, garage: selectedGarage }, {
                data: true,
                delay: 500
            });

            if (success) {
                onTransferSuccess(vehicle.id);
                return;
            }
            setError('Não foi possível transferir o veículo.');
        } catch {
            setError('Não foi possível transferir o veículo.');
        }
        setIsTransferring(false);
    };

    return (
        <Modal
            opened
            onClose={onClose}
            title={`Transferir ${vehicle.name} (${vehicle.plate})`}
            centered
            size="md"
            closeOnClickOutside={false}
            closeOnEscape={false}
            withCloseButton={false}
            className='text-[var(--mantine-color-dark-1)]'
        >
            {isLoadingGarages ? (
                <div className="flex flex-col items-center justify-center py-8">
                    <Loader color="blue" size="xl" type="dots" className='mb-5' />
                    <Text className="mt-4">Carregando garagens...</Text>
                </div>
            ) : (
                <>
                    <div className="mb-4">
                        <NativeSelect
                            label='Garagem de destino'
                            description={price > 0 ? `Custo da transferência: $${formatMoney(price)}` : 'Transferência gratuita'}
                            data={[{ value: '', label: 'Escolha uma garagem', disabled: true }, ...garageList]}
                            value={selectedGarage}
                            size='sm'
                            onChange={(event) => setSelectedGarage(event.currentTarget.value)}
                            disabled={isTransferring || garageList.length === 0}
                            className="w-full mt-1"
                        />
                    </div>

                    {error && (
                        <Text c="red" size="sm" className="mb-4">
                            {error}
                        </Text>
                    )}

                    <Group gap="md" justify="flex-end" className="mt-6">
                        <Button variant="light" onClick={onClose} disabled={isTransferring} color='red'>
                            Cancelar
                        </Button>

                        <Button
                            variant="light"
                            onClick={handleTransfer}
                            loading={isTransferring}
                            disabled={!selectedGarage || isTransferring}
                        >
                            Transferir
                        </Button>
                    </Group>
                </>
            )}
        </Modal>
    );
};
