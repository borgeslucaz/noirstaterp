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

// ── Editor de garagens (/garagem) ─────────────────────────────────────────

export interface Vec3 { x: number; y: number; z: number }
export interface Vec4 extends Vec3 { w: number }

export interface EditorBlip {
    name?: string;
    sprite: number;
    color: number;
}

export interface EditorPoint {
    coords?: Vec4;
    spawn?: Vec4;
    dropPoint?: Vec3;
    blip?: EditorBlip;
    /** Raios que a tela nao edita; voltam ao servidor como vieram. */
    useRadius?: number;
    dropUseRadius?: number;
    drawRadius?: number;
    dropDrawRadius?: number;
}

export type EditorVehicleType = 'car' | 'air' | 'sea';

export interface EditorGarage {
    /** Identificador; vazio numa garagem nova (o servidor gera ao salvar). */
    name?: string;
    label: string;
    vehicleType: EditorVehicleType;
    depot: boolean;
    shared: boolean;
    groups?: Record<string, number>;
    accessPoints: EditorPoint[];
    /** Carros guardados nela (so leitura). */
    stored?: number;
}

export interface EditorResult {
    ok: boolean;
    error?: string;
    name?: string;
    list?: EditorGarage[];
}
