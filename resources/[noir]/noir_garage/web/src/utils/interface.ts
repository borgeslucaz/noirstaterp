export interface VehicleStatusProps {
    fuel: number;
    body: number;
    engine: number;
}

export interface VehicleStatsProps {
    speed: number;
    acceleration: number;
    braking: number;
    handling: number;
    traction: number;
}

export type VehicleIcon = 'car' | 'motorcycle' | 'bicycle' | 'boat' | 'helicopter' | 'plane';

/** Estados do qbx_vehicles: 0 fora, 1 guardado, 2 apreendido. */
export type VehicleState = 0 | 1 | 2;

export interface VehicleProps {
    id: number;
    icon: VehicleIcon;
    name: string;
    modelLabel: string;
    plate: string;
    state: VehicleState;
    depotPrice: number;
    canTakeOut: boolean;
    notice?: string;
    isOwner: boolean;
    canManageKeys: boolean;
    canTransfer: boolean;
    canRename: boolean;
    vehicle_status: VehicleStatusProps;
}

export interface PositionProps {
    x: number;
    y: number;
}

export interface GarageDataProps {
    label: string;
    isDepot: boolean;
    rename: boolean;
    renameMaxLength: number;
    transfer: boolean;
    transferPrice: number;
    keys?: { copy: number; lock: number };
}

export interface GarageOption {
    value: string;
    label: string;
}

export interface LogProps {
    date: string;
    message: string;
}

export const formatMoney = (value: number) => value.toLocaleString('pt-BR');
