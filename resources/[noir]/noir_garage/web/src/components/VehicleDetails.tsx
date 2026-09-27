import React, { useEffect, useRef, useState } from "react";
import ProgresStatus from "./ProgresStatus";

import { VehicleProps, GarageDataProps, LogProps, formatMoney } from "../utils/interface";
import { ActionIcon, Container, Button, Loader, Group, Modal, Stack, Text, Tooltip } from "@mantine/core";
import { FaArrowLeft, FaCircleInfo, FaPenToSquare, FaRightLeft, FaEye, FaKey, FaLock } from "react-icons/fa6";
import VehicleBadges from "./VehicleBadges";
import { fetchNui } from "../utils/fetchNui";

const VehicleDetails: React.FC<{
        closeVehicleDetails: () => void,
        selectedVehicle: VehicleProps,
        garage: GarageDataProps,
        updateVehicleName: () => void,
        updateVehicleGarage: () => void,
        spawnVehicle: () => void,
        onShowPreview: () => void
    }> = ({
        closeVehicleDetails,
        selectedVehicle,
        garage,
        updateVehicleName,
        updateVehicleGarage,
        spawnVehicle,
        onShowPreview
    }) => {

    const logsRef = useRef<HTMLDivElement>(null);

    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [logs, setLogs] = useState<LogProps[]>([]);
    const [busy, setBusy] = useState<'copy' | 'lock' | null>(null);
    const [confirmLock, setConfirmLock] = useState<boolean>(false);

    useEffect(() => {
        let active = true;
        setIsLoading(true);
        setLogs([]);

        if (!selectedVehicle.isOwner) {
            setIsLoading(false);
            return;
        }

        fetchNui<LogProps[] | null>('getVehicleLogs', { vehicleId: selectedVehicle.id }, {
            data: [{ date: new Date().toLocaleString('pt-BR'), message: 'Retirado de Motel Parking' }],
            delay: 300
        })
        .then(response => {
            if (active && Array.isArray(response)) setLogs(response);
        })
        .finally(() => {
            if (active) setIsLoading(false);
        });

        return () => { active = false; };
    }, [selectedVehicle.id]);

    useEffect(() => {
        if (logsRef.current) {
            logsRef.current.scrollTop = logsRef.current.scrollHeight;
        }
    }, [logs, isLoading]);

    const buyKeyCopy = async () => {
        if (busy) return;
        setBusy('copy');
        await fetchNui<boolean>('keyCopy', { vehicleId: selectedVehicle.id }, { data: true, delay: 500 });
        setBusy(null);
    };

    const changeLock = async () => {
        if (busy) return;
        setConfirmLock(false);
        setBusy('lock');
        await fetchNui<boolean>('lockChange', { vehicleId: selectedVehicle.id }, { data: true, delay: 500 });
        setBusy(null);
    };

    const takeOutLabel = garage.isDepot && selectedVehicle.canTakeOut && selectedVehicle.depotPrice > 0
        ? `Retirar ($${formatMoney(selectedVehicle.depotPrice)})`
        : 'Retirar veículo';

    return (
        <div
            className="bg-[var(--mantine-color-dark-8)] border-l border-[var(--mantine-color-dark-4)] overflow-hidden"
            style={{ width: '400px', flexShrink: 0 }}
        >
            <div className="p-3 mt-0.5 bg-[var(--mantine-color-dark-8)] border-b border-[var(--mantine-color-dark-4)] flex items-center justify-between">
                <div className="flex mb-[6px] items-center">
                    <FaCircleInfo className="mr-2 w-7 h-7 text-[var(--mantine-color-dark-1)]" />
                    <h2 className="text-lg text-[var(--mantine-color-dark-1)] font-bold">Detalhes do veículo</h2>
                </div>

                <ActionIcon variant="light" size="md" aria-label="Voltar" onClick={closeVehicleDetails}>
                    <FaArrowLeft style={{ width: '70%', height: '70%' }} />
                </ActionIcon>
            </div>

            <div className="p-4">
                <div className="mb-3 bg-[var(--mantine-color-dark-6)] p-3 rounded-lg">
                    <div className="flex justify-between items-start mb-3 gap-2">
                        <div className="min-w-0">
                            <h3 className="text-lg text-[var(--mantine-color-dark-1)] font-semibold truncate">{selectedVehicle.name}</h3>
                            {selectedVehicle.name !== selectedVehicle.modelLabel && (
                                <Text size="xs" c="dimmed" truncate>{selectedVehicle.modelLabel}</Text>
                            )}
                        </div>

                        <Tooltip label="Ver o veículo">
                            <ActionIcon variant="light" color="blue" size="md" aria-label="Ver o veículo" onClick={onShowPreview}>
                                <FaEye style={{ width: '70%', height: '70%' }} />
                            </ActionIcon>
                        </Tooltip>
                    </div>

                    <div className="flex flex-wrap gap-2">
                        <VehicleBadges vehicle={selectedVehicle} isDepot={garage.isDepot} size="md" />
                    </div>

                    {selectedVehicle.notice && (
                        <Text size="sm" c="yellow" mt="sm">{selectedVehicle.notice}</Text>
                    )}
                </div>

                <Container className="rounded-lg bg-[var(--mantine-color-dark-6)] p-4 space-y-4 mt-4 mb-4">
                    <ProgresStatus name="Combustível" level={selectedVehicle.vehicle_status.fuel} />
                    <ProgresStatus name="Carroceria" level={selectedVehicle.vehicle_status.body} />
                    <ProgresStatus name="Motor" level={selectedVehicle.vehicle_status.engine} />
                </Container>

                {selectedVehicle.isOwner && (
                    <Container size='xs' className="rounded-lg bg-[var(--mantine-color-dark-6)] p-4">
                        <div className="flex items-center mb-2">
                            <div className="w-3 h-3 rounded-full bg-[var(--mantine-color-green-5)] mr-2"></div>
                            <h4 className="text-sm font-mono text-[var(--mantine-color-dark-1)]">HISTÓRICO</h4>
                        </div>

                        <div
                            ref={logsRef}
                            className="bg-[var(--mantine-color-dark-9)] rounded p-2 h-32 overflow-y-auto font-mono text-xs"
                            style={{ scrollBehavior: 'smooth' }}
                        >
                            {isLoading ? (
                                <div className="flex flex-col items-center justify-center h-full">
                                    <Loader size="sm" color="teal" />
                                </div>
                            ) : logs.length > 0 ? (
                                logs.map((log, index) => (
                                    <div key={index} className="py-1">
                                        <span className="text-[var(--mantine-color-green-5)]">[{log.date}]</span>
                                        <span className="text-gray-300"> {log.message}</span>
                                    </div>
                                ))
                            ) : (
                                <div className="py-2 text-[var(--mantine-color-dark-2)]">
                                    {'>'} Nenhum registro ainda.
                                </div>
                            )}
                        </div>
                    </Container>
                )}

                <div className="mt-5 space-y-2">
                    <Group gap="xs" grow>
                        <Button variant="light" size="sm" onClick={spawnVehicle} disabled={!selectedVehicle.canTakeOut}>
                            {takeOutLabel}
                        </Button>

                        {(selectedVehicle.canRename || selectedVehicle.canTransfer) && (
                            <Group gap="xs" grow wrap="nowrap">
                                {selectedVehicle.canRename && (
                                    <Tooltip label="Mudar apelido">
                                        <Button variant="light" size="sm" onClick={updateVehicleName} aria-label="Mudar apelido">
                                            <FaPenToSquare className="w-5 h-5" />
                                        </Button>
                                    </Tooltip>
                                )}
                                {selectedVehicle.canTransfer && (
                                    <Tooltip label="Transferir de garagem">
                                        <Button variant="light" size="sm" onClick={updateVehicleGarage} aria-label="Transferir de garagem">
                                            <FaRightLeft className="w-5 h-5" />
                                        </Button>
                                    </Tooltip>
                                )}
                            </Group>
                        )}
                    </Group>

                    {selectedVehicle.canManageKeys && garage.keys && (
                        <Stack gap="xs">
                            <Button
                                variant="light"
                                color="teal"
                                size="sm"
                                leftSection={<FaKey />}
                                loading={busy === 'copy'}
                                disabled={busy !== null}
                                onClick={buyKeyCopy}
                            >
                                Cópia da chave ${formatMoney(garage.keys.copy)}
                            </Button>
                            <Button
                                variant="light"
                                color="orange"
                                size="sm"
                                leftSection={<FaLock />}
                                loading={busy === 'lock'}
                                disabled={busy !== null}
                                onClick={() => setConfirmLock(true)}
                            >
                                Trocar fechadura ${formatMoney(garage.keys.lock)}
                            </Button>
                        </Stack>
                    )}
                </div>
            </div>

            {garage.keys && (
                <Modal
                    opened={confirmLock}
                    onClose={() => setConfirmLock(false)}
                    title="Trocar fechadura"
                    centered
                    className='text-[var(--mantine-color-dark-1)]'
                >
                    <Text size="sm">
                        Todas as chaves deste veículo, inclusive cópias com outras pessoas, deixam de funcionar.
                        Você recebe uma chave nova. Custo: ${formatMoney(garage.keys.lock)}.
                    </Text>
                    <Group mt="xl" justify="flex-end">
                        <Button variant="light" color="red" onClick={() => setConfirmLock(false)}>Cancelar</Button>
                        <Button variant="light" onClick={changeLock}>Confirmar</Button>
                    </Group>
                </Modal>
            )}
        </div>
    );
};

export default VehicleDetails;
