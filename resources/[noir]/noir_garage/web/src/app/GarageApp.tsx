import React, { useState, useEffect } from 'react';
import { isEnvBrowser } from "../utils/misc";
import { VehicleProps, GarageDataProps } from "../utils/interface";
import { Button, ActionIcon, Group, Container, Text, Input } from "@mantine/core";
import { FaStar, FaRegStar, FaAngleDown, FaAngleUp, FaXmark, FaWarehouse, FaMagnifyingGlass } from 'react-icons/fa6';

import VehicleDetails from '../components/VehicleDetails';
import VehiclePreview from '../components/VehiclePreview';
import { getVehicleIcon } from '../components/VehicleIcons';

import { fetchNui } from '../utils/fetchNui';
import { useNuiEvent } from '../hooks/useNuiEvent';
import { useDraggable } from "../components/Drag";
import VehicleBadges from '../components/VehicleBadges';
import { VehicleNameModal } from '../components/modal/ChangeName';
import { ChangeGarageModal } from '../components/modal/ChangeGarage';

const FAVORITE_STORAGE_KEY = 'garage_favorite';

const loadFavorites = (): Record<string, boolean> => {
  try {
    return JSON.parse(localStorage.getItem(FAVORITE_STORAGE_KEY) || '{}');
  } catch {
    return {};
  }
};

const App: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [garageData, setGarageData] = useState<GarageDataProps | null>(null);
  const [vehicles, setVehicles] = useState<VehicleProps[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [isMinimized, setIsMinimized] = useState<boolean>(false);
  const [showPreviewMode, setShowPreviewMode] = useState<boolean>(false);

  const { isDragging, position, garageRef, setIsDragging, setStartPos, onMouseDown, onMouseMove, onMouseUp } = useDraggable();

  const [favorites, setFavorites] = useState<Record<string, boolean>>(loadFavorites);
  const [showOnlyFavorites, setShowOnlyFavorites] = useState(false);

  const [showChangeNameModal, setShowChangeNameModal] = useState<boolean>(false);
  const [showChangeGarageModal, setShowChangeGarageModal] = useState<boolean>(false);

  const selectedVehicle = vehicles.find(vehicle => vehicle.id === selectedId) ?? null;

  const resetState = () => {
    setVisible(false);
    setSelectedId(null);
    setIsMinimized(false);
    setShowOnlyFavorites(false);
    setShowChangeNameModal(false);
    setShowChangeGarageModal(false);
    setShowPreviewMode(false);
    setSearchTerm('');
  };

  const handleClose = () => {
    resetState();
    if (!isEnvBrowser()) {
      fetchNui('exit');
    }
  };

  useNuiEvent('setVisible', (data: { visible: boolean, vehicles?: VehicleProps[], garage?: GarageDataProps }) => {
    if (!data.visible) {
      resetState();
      return;
    }

    setVisible(true);
    setVehicles(Array.isArray(data.vehicles) ? data.vehicles : []);
    if (data.garage) setGarageData(data.garage);
  });

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && visible && !showChangeNameModal && !showChangeGarageModal && !showPreviewMode) {
        handleClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [visible, showChangeNameModal, showChangeGarageModal, showPreviewMode]);

  const toggleFavorite = (vehicleId: number) => {
    setFavorites(prev => {
      const next = { ...prev, [vehicleId]: !prev[vehicleId] };
      try {
        localStorage.setItem(FAVORITE_STORAGE_KEY, JSON.stringify(next));
      } catch {
        // sem localStorage, o favorito vale so ate fechar o jogo
      }
      return next;
    });
  };

  const spawnVehicle = () => {
    if (!selectedVehicle?.canTakeOut) return;
    fetchNui('spawnVehicle', { vehicleId: selectedVehicle.id });
    resetState();
  };

  const updateVehicleName = (newName: string) => {
    setVehicles(prev => prev.map(vehicle => vehicle.id === selectedId ? { ...vehicle, name: newName } : vehicle));
    setShowChangeNameModal(false);
  };

  const handleTransferSuccess = (vehicleId: number) => {
    setVehicles(prev => prev.filter(v => v.id !== vehicleId));
    setShowChangeGarageModal(false);
    setSelectedId(null);
  };

  const search = searchTerm.toLowerCase();
  const filteredVehicles = vehicles.filter(vehicle => {
    const matchesSearch = vehicle.name.toLowerCase().includes(search)
      || vehicle.modelLabel.toLowerCase().includes(search)
      || vehicle.plate.toLowerCase().includes(search);

    return matchesSearch && (!showOnlyFavorites || favorites[vehicle.id]);
  });

  if (!visible || !garageData) return null;

  if (showPreviewMode && selectedVehicle) {
    return (
      <VehiclePreview
        selectedVehicle={selectedVehicle}
        onClose={() => setShowPreviewMode(false)}
      />
    );
  }

  return (
    <div
      ref={garageRef}
      className="absolute shadow-lg rounded-lg overflow-hidden flex"
      style={{
        left: `${position.x}px`,
        top: `${position.y}px`,
        width: selectedVehicle ? '1000px' : '600px',
        cursor: isDragging ? 'grabbing' : 'default',
        zIndex: 1000
      }}
      onMouseDown={onMouseDown}
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
    >
      <div className="bg-[var(--mantine-color-dark-8)] text-white" style={{ width: '600px', minWidth: '600px', flexShrink: 0 }}>
        <div
          className={`p-4 ${!isMinimized && 'border-b border-[var(--mantine-color-dark-4)]'} flex items-center justify-between cursor-grab`}
          onMouseDown={(e) => {
            e.preventDefault();
            setIsDragging(true);
            setStartPos({
              x: e.clientX - position.x,
              y: e.clientY - position.y
            });
          }}
        >
          <div className="flex items-center">
            <FaWarehouse className="mr-2 w-7 h-7 text-[var(--mantine-color-dark-1)]" />
            <h1 className="text-xl text-[var(--mantine-color-dark-1)] font-bold">{garageData.label}</h1>
          </div>

          <Group justify="flex-end" gap="xs">
            <ActionIcon variant="light" size="md" aria-label="Minimizar" onClick={() => { setIsMinimized(!isMinimized); setSelectedId(null); }}>
              {isMinimized ? <FaAngleDown className="w-5 h-5" /> : <FaAngleUp className="w-5 h-5" />}
            </ActionIcon>
            <ActionIcon variant="light" size="md" color='red' aria-label="Fechar" onClick={handleClose}>
              <FaXmark className="w-5 h-5" />
            </ActionIcon>
          </Group>
        </div>

        <div className={isMinimized ? 'hidden' : 'block'}>
          <Container className="pt-3">
            <Group justify='flex-end' gap='xs'>
              <Input
                placeholder="Buscar por nome ou placa"
                value={searchTerm}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setSearchTerm(e.target.value)}
                style={{ width: '522px' }}
                rightSection={<FaMagnifyingGlass aria-label="Buscar" />}
              />

              <ActionIcon
                variant="light"
                color={showOnlyFavorites ? "yellow" : "gray"}
                size="lg"
                onClick={() => setShowOnlyFavorites(prev => !prev)}
                title="Só favoritos"
              >
                <FaStar className="w-5 h-5" />
              </ActionIcon>
            </Group>
          </Container>

          <div className="p-3">
            <div className="border h-[560px] border-[var(--mantine-color-dark-4)] rounded-lg overflow-hidden">
              <div className="h-full overflow-y-auto p-3">
                {filteredVehicles.length > 0 ? (
                  <div className="grid grid-cols-2 gap-3">
                    {filteredVehicles.map((vehicle) => (
                      <div
                        key={vehicle.id}
                        className={`relative rounded-md bg-[var(--mantine-color-dark-7)] overflow-hidden ${vehicle.id === selectedId ? 'ring-2 ring-[var(--mantine-color-blue-6)]' : ''}`}
                      >
                        <ActionIcon
                          variant="subtle"
                          color="yellow"
                          size="md"
                          onClick={() => toggleFavorite(vehicle.id)}
                          className="!absolute top-2 right-2 z-10"
                          aria-label="Favoritar"
                        >
                          {favorites[vehicle.id] ? <FaStar className="w-5 h-5" /> : <FaRegStar className="w-5 h-5" />}
                        </ActionIcon>

                        <div className="p-3 flex flex-col items-center">
                          <div className="rounded-4 mb-4">
                            {getVehicleIcon(vehicle.icon || 'car')}
                          </div>

                          <div className="font-medium text-[var(--mantine-color-dark-1)] text-center text-lg mb-3 truncate w-full">
                            {vehicle.name}
                          </div>

                          <div className="flex flex-wrap justify-center gap-1 mb-4 min-h-6 w-full">
                            <VehicleBadges vehicle={vehicle} isDepot={garageData.isDepot} />
                          </div>

                          <Button variant="light" color="blue" size="sm" fullWidth onClick={() => { setSelectedId(vehicle.id); setShowPreviewMode(false); }}>
                            DETALHES
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex justify-center items-center h-[500px]">
                    <Text ta="center" fz="xl" fw={700} c="dimmed">
                      Nenhum veículo
                    </Text>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {selectedVehicle && (
        <VehicleDetails
          closeVehicleDetails={() => setSelectedId(null)}
          selectedVehicle={selectedVehicle}
          garage={garageData}
          updateVehicleName={() => setShowChangeNameModal(true)}
          updateVehicleGarage={() => setShowChangeGarageModal(true)}
          spawnVehicle={spawnVehicle}
          onShowPreview={() => setShowPreviewMode(true)}
        />
      )}

      {showChangeNameModal && selectedVehicle && (
        <VehicleNameModal
          vehicle={selectedVehicle}
          maxLength={garageData.renameMaxLength}
          onUpdateName={updateVehicleName}
          onClose={() => setShowChangeNameModal(false)}
        />
      )}

      {showChangeGarageModal && selectedVehicle && (
        <ChangeGarageModal
          vehicle={selectedVehicle}
          price={garageData.transferPrice}
          onTransferSuccess={handleTransferSuccess}
          onClose={() => setShowChangeGarageModal(false)}
        />
      )}
    </div>
  );
};

export default App;
