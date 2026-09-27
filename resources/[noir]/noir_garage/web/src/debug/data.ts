import { GarageDataProps, VehicleProps } from "../utils/interface";

// Dados falsos para abrir a tela no navegador (npm run dev).

export const debugGarage: GarageDataProps = {
    label: 'Motel Parking',
    isDepot: false,
    rename: true,
    renameMaxLength: 24,
    transfer: true,
    transferPrice: 0,
    keys: { copy: 2000, lock: 5000 },
};

const base = {
    state: 1 as const,
    depotPrice: 0,
    canTakeOut: true,
    isOwner: true,
    canManageKeys: true,
    canTransfer: true,
    canRename: true,
};

export const defaultVehicles: VehicleProps[] = [
    {
        ...base,
        id: 1,
        icon: 'motorcycle',
        name: 'Nagasaki BF400',
        modelLabel: 'Nagasaki BF400',
        plate: '40BGB809',
        vehicle_status: { engine: 50, body: 35, fuel: 80 },
    },
    {
        ...base,
        id: 2,
        icon: 'car',
        name: 'Carro do trampo',
        modelLabel: 'Karin Sultan RS',
        plate: '87KKV380',
        vehicle_status: { engine: 90, body: 85, fuel: 60 },
    },
    {
        ...base,
        id: 3,
        icon: 'car',
        name: 'Pegassi Zentorno',
        modelLabel: 'Pegassi Zentorno',
        plate: '45AKL192',
        state: 0,
        canTakeOut: false,
        canManageKeys: true,
        canTransfer: false,
        notice: 'Seu veículo ainda está na rua',
        vehicle_status: { engine: 34, body: 45, fuel: 67 },
    },
    {
        ...base,
        id: 4,
        icon: 'car',
        name: 'Bravado Buffalo',
        modelLabel: 'Bravado Buffalo',
        plate: '12ABC345',
        state: 2,
        canTakeOut: false,
        canManageKeys: false,
        canTransfer: false,
        notice: 'Seu veículo foi apreendido pela polícia',
        vehicle_status: { engine: 78, body: 23, fuel: 56 },
    },
    ...[
        ['Declasse Vigero', '31FXT882'], ['Übermacht Zion', '09LRA114'], ['Albany Emperor', '72BPD310'],
        ['Vapid Dominator', '55QWE901'], ['Obey Tailgater', '18MNB447'], ['Grotti Cheetah', '63HJK205'],
    ].map(([name, plate], i) => ({
        ...base,
        id: 10 + i,
        icon: 'car' as const,
        name,
        modelLabel: name,
        plate,
        vehicle_status: { engine: 100 - i * 9, body: 90 - i * 7, fuel: 40 + i * 8 },
    })),
];

export const debugDepot: GarageDataProps = {
    ...debugGarage,
    label: 'Pátio de Los Santos',
    isDepot: true,
    transfer: false,
};

export const depotVehicles: VehicleProps[] = [
    {
        ...base,
        id: 3,
        icon: 'car',
        name: 'Pegassi Zentorno',
        modelLabel: 'Pegassi Zentorno',
        plate: '45AKL192',
        state: 0,
        depotPrice: 1500,
        canTransfer: false,
        vehicle_status: { engine: 34, body: 45, fuel: 67 },
    },
    {
        ...base,
        id: 5,
        icon: 'motorcycle',
        name: 'Shitzu Hakuchou',
        modelLabel: 'Shitzu Hakuchou',
        plate: '88ZXC019',
        state: 0,
        canTakeOut: false,
        canTransfer: false,
        notice: 'Seu veículo ainda está na rua',
        vehicle_status: { engine: 92, body: 88, fuel: 20 },
    },
    {
        ...base,
        id: 4,
        icon: 'car',
        name: 'Bravado Buffalo',
        modelLabel: 'Bravado Buffalo',
        plate: '12ABC345',
        state: 2,
        canTakeOut: false,
        canManageKeys: false,
        canTransfer: false,
        notice: 'Seu veículo foi apreendido pela polícia',
        vehicle_status: { engine: 78, body: 23, fuel: 56 },
    },
];
