import React, { useEffect, useState } from "react";
import { ActionIcon, Container, Progress, Badge, Text, Loader, Center, Box } from "@mantine/core";
import { FaArrowLeft } from "react-icons/fa6";
import { fetchNui } from "../utils/fetchNui";
import { VehicleProps, VehicleStatsProps } from "../utils/interface";

const StatBar: React.FC<{ label: string; value: number; color: string; suffix?: string }> = ({ label, value, color, suffix = '' }) => (
  <div>
    <div className="flex justify-between items-center mb-1">
      <Text size="sm">{label}</Text>
      <Text size="sm" className="font-mono" style={{ color: `var(--mantine-color-${color}-5)` }}>{value}{suffix}</Text>
    </div>
    <Progress value={value} color={color} size="md" radius="xs" />
  </div>
);

const VehiclePreview: React.FC<{
  selectedVehicle: VehicleProps;
  onClose: () => void;
}> = ({ selectedVehicle, onClose }) => {
  const [vehicleStats, setVehicleStats] = useState<VehicleStatsProps | null>(null);
  const [status, setStatus] = useState<'loading' | 'ready' | 'failed'>('loading');

  useEffect(() => {
    let active = true;
    setStatus('loading');
    setVehicleStats(null);

    fetchNui<boolean>('showVehiclePreview', { vehicleId: selectedVehicle.id }, { data: true, delay: 300 })
      .then(async (shown) => {
        if (!active) return;
        if (!shown) {
          setStatus('failed');
          return;
        }
        const stats = await fetchNui<VehicleStatsProps | null>('getVehicleStats', {}, {
          data: { speed: 70, acceleration: 55, braking: 40, handling: 60, traction: 65 },
          delay: 300
        });
        if (!active) return;
        setVehicleStats(stats);
        setStatus(stats ? 'ready' : 'failed');
      })
      .catch(() => {
        if (active) setStatus('failed');
      });

    return () => {
      active = false;
      fetchNui('hideVehiclePreview', {}, { data: 1 });
    };
  }, [selectedVehicle.id]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-end">
      <div className="w-96 max-h-[800px] bg-[var(--mantine-color-dark-8)] border-l border-[var(--mantine-color-dark-4)] shadow-xl rounded-lg overflow-auto absolute right-6 top-1/2 transform -translate-y-1/2">
        <div className="p-3 bg-[var(--mantine-color-dark-8)] border-b border-[var(--mantine-color-dark-4)] flex items-center justify-between">
          <h2 className="text-lg text-[var(--mantine-color-dark-1)] font-bold">Visualizar veículo</h2>
          <ActionIcon variant="light" size="md" aria-label="Voltar" onClick={onClose}>
            <FaArrowLeft style={{ width: '70%', height: '70%' }} />
          </ActionIcon>
        </div>

        <div className="p-4">
          <Box className="mb-3 bg-[var(--mantine-color-dark-6)] p-3 rounded-lg">
            <h3 className="text-lg text-[var(--mantine-color-dark-1)] font-semibold">{selectedVehicle.name}</h3>
            <Badge variant="light" size="md">{selectedVehicle.plate}</Badge>
          </Box>

          <Text size="xs" c="dimmed" mb="sm">Arraste com o botão direito para girar. Use a roda do mouse para o zoom.</Text>

          {status !== 'ready' || !vehicleStats ? (
            <Container className="rounded-lg bg-[var(--mantine-color-dark-6)] p-8 my-4">
              <Center className="flex flex-col">
                {status === 'loading' ? (
                  <>
                    <Loader size="lg" color="blue" className="mb-4" />
                    <Text size="sm" c="dimmed">Carregando o veículo...</Text>
                  </>
                ) : (
                  <Text size="sm" c="dimmed">Não foi possível mostrar este veículo.</Text>
                )}
              </Center>
            </Container>
          ) : (
            <>
              <Container className="rounded-lg bg-[var(--mantine-color-dark-6)] p-4 space-y-4 mt-4 mb-4">
                <h4 className="text-md font-semibold text-[var(--mantine-color-dark-1)]">Desempenho</h4>
                <StatBar label="Velocidade" value={vehicleStats.speed} color="blue" />
                <StatBar label="Aceleração" value={vehicleStats.acceleration} color="blue" />
                <StatBar label="Frenagem" value={vehicleStats.braking} color="blue" />
                <StatBar label="Dirigibilidade" value={vehicleStats.handling} color="blue" />
                <StatBar label="Tração" value={vehicleStats.traction} color="blue" />
              </Container>

              <Container className="rounded-lg bg-[var(--mantine-color-dark-6)] p-4 space-y-4 mt-4 mb-4">
                <h4 className="text-md font-semibold text-[var(--mantine-color-dark-1)]">Estado</h4>
                <StatBar label="Combustível" value={selectedVehicle.vehicle_status.fuel} color="green" suffix="%" />
                <StatBar label="Carroceria" value={selectedVehicle.vehicle_status.body} color="green" suffix="%" />
                <StatBar label="Motor" value={selectedVehicle.vehicle_status.engine} color="green" suffix="%" />
              </Container>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default VehiclePreview;
