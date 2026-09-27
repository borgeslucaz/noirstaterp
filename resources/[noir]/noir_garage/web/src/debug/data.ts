import { EditorGarage, EditorGroupOptions, GarageDataProps, VehicleProps } from "../utils/interface";

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

export const debugEditorGarages: EditorGarage[] = [
    {
        name: 'motelgarage',
        label: 'Motel Parking',
        vehicleType: 'car',
        depot: false,
        shared: false,
        stored: 4,
        accessPoints: [{
            coords: { x: 275.58, y: -344.74, z: 45.17, w: 70 },
            spawns: [{ x: 271.26, y: -342.32, z: 44.7, w: 159.97 }],
            blip: { name: 'Public Parking', sprite: 357, color: 3 },
        }],
    },
    {
        name: 'policegarage',
        label: 'Garagem da Polícia',
        vehicleType: 'car',
        depot: false,
        shared: true,
        groups: { police: 2 },
        stored: 0,
        accessPoints: [{
            coords: { x: 454.6, y: -1017.4, z: 28.4, w: 90 },
            spawns: [
                { x: 438.4, y: -1018.3, z: 27.7, w: 90 },
                { x: 438.4, y: -1022.1, z: 27.7, w: 90 },
                { x: 438.4, y: -1025.9, z: 27.7, w: 90 },
            ],
            dropPoint: { x: 434.1, y: -1016.5, z: 28.6 },
            ped: { model: 's_m_y_cop_01', scenario: 'WORLD_HUMAN_CLIPBOARD' },
            interaction: 'target',
        }],
    },
    {
        name: 'cartelgarage',
        label: 'Garagem do Cartel',
        vehicleType: 'car',
        depot: false,
        shared: true,
        groups: { cartel: 0 },
        stored: 0,
        accessPoints: [{ coords: { x: 1394.2, y: 1141.6, z: 114.6, w: 90 } }],
    },
    {
        name: 'impoundlot',
        label: 'Pátio de Los Santos',
        vehicleType: 'car',
        depot: true,
        shared: false,
        stored: 0,
        accessPoints: [{
            coords: { x: 400.45, y: -1630.87, z: 29.29, w: 228.88 },
            spawns: [{ x: 407.2, y: -1645.58, z: 29.31, w: 228.28 }],
            blip: { name: 'Pátio', sprite: 68, color: 3 },
        }],
    },
];

const grades = (...names: string[]) => names.map((name, level) => ({ level, name }));

export const debugGroupOptions: EditorGroupOptions = {
    jobs: [
        { name: 'ambulance', label: 'EMS', grades: grades('Recruit', 'Paramedic', 'Doctor', 'Surgeon', 'Chief') },
        { name: 'police', label: 'LSPD', grades: grades('Recruit', 'Officer', 'Sergeant', 'Lieutenant', 'Chief') },
        { name: 'mechanic', label: 'Mecânico', grades: grades('Recruit', 'Novice', 'Experienced', 'Advanced', 'Manager') },
        { name: 'taxi', label: 'Taxi', grades: grades('Recruit', 'Driver', 'Event Driver', 'Sales', 'Manager') },
    ],
    gangs: [
        { name: 'ballas', label: 'Ballas', grades: grades('Novato', 'Membro', 'Tenente', 'Chefe') },
        { name: 'families', label: 'Families', grades: grades('Novato', 'Membro', 'Chefe') },
        { name: 'vagos', label: 'Vagos', grades: grades('Novato', 'Membro', 'Chefe') },
    ],
};
