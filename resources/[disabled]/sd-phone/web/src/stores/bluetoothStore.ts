import { create } from 'zustand';

import { apiData } from '@/core/api';
import { isFiveM } from '@/core/nui';

export interface BluetoothDevice {
    id:        string;
    name:      string;
    kind:      string;
    paired:    boolean;
    connected: boolean;
    full:      boolean;
    inRange:   boolean;
}

interface ScanResult {
    enabled: boolean;
    devices: BluetoothDevice[];
}

interface BluetoothState {
    enabled: boolean;
    configured: boolean;
    devices: BluetoothDevice[];
    loading: boolean;
    busyId:  string | null;
    setConfigured: (on: boolean) => void;
    scan:       (quiet?: boolean) => Promise<void>;
    setEnabled: (on: boolean) => Promise<void>;
    pair:       (id: string) => Promise<boolean>;
    forget:     (id: string) => Promise<void>;
    disconnect: (id: string) => Promise<void>;
}

const DEV_DEVICES: BluetoothDevice[] = [
    { id: 'car_sultan',  name: 'Sultan RS',       kind: 'vehicle', paired: true,  connected: true,  full: false, inRange: true },
    { id: 'speaker_pier', name: 'Pier Speaker',    kind: 'audio',   paired: false, connected: false, full: false, inRange: true },
    { id: 'earpiece_1',  name: 'Earpiece',        kind: 'audio',   paired: false, connected: false, full: true,  inRange: true },
    { id: 'watch_old',   name: 'Old Smartwatch',  kind: 'device',  paired: true,  connected: false, full: false, inRange: false },
];

function toDevice(raw: unknown): BluetoothDevice | null {
    if (!raw || typeof raw !== 'object') return null;
    const r = raw as Record<string, unknown>;
    const id = typeof r.id === 'string' ? r.id : '';
    if (!id) return null;
    return {
        id,
        name:      typeof r.name === 'string' && r.name ? r.name : id,
        kind:      typeof r.kind === 'string' ? r.kind : 'device',
        paired:    r.paired === true,
        connected: r.connected === true,
        full:      r.full === true,
        inRange:   r.inRange === true,
    };
}

export const useBluetoothStore = create<BluetoothState>()((set, get) => ({
    enabled: true,
    configured: false,
    devices: [],
    loading: false,
    busyId:  null,

    setConfigured: on => set({ configured: on }),

    scan: async (quiet = false) => {
        if (!quiet) set({ loading: true });
        if (!isFiveM) {
            set({ enabled: true, devices: DEV_DEVICES.map(d => ({ ...d })), loading: false });
            return;
        }
        const res = await apiData<ScanResult>('sd-phone:bluetooth:scan');
        set({
            enabled: res ? res.enabled === true : get().enabled,
            devices: Array.isArray(res?.devices)
                ? res.devices.map(toDevice).filter((d): d is BluetoothDevice => d !== null)
                : [],
            loading: false,
        });
    },

    setEnabled: async (on) => {
        const before = get().enabled;
        set({ enabled: on });
        if (!isFiveM) {
            set({ devices: on ? DEV_DEVICES.map(d => ({ ...d })) : [] });
            return;
        }
        const res = await apiData<{ enabled: boolean }>('sd-phone:bluetooth:setEnabled', { on });
        if (!res) { set({ enabled: before }); return; }
        await get().scan(true);
    },

    pair: async (id) => {
        set({ busyId: id });
        if (!isFiveM) {
            set(s => ({
                busyId: null,
                devices: s.devices.map(d => (d.id === id ? { ...d, paired: true, connected: !d.full } : d)),
            }));
            return true;
        }
        const res = await apiData<{ id: string }>('sd-phone:bluetooth:pair', { id });
        set({ busyId: null });
        await get().scan(true);
        return res !== null;
    },

    forget: async (id) => {
        set({ busyId: id });
        if (!isFiveM) {
            set(s => ({ busyId: null, devices: s.devices.filter(d => d.id !== id || d.inRange)
                .map(d => (d.id === id ? { ...d, paired: false, connected: false } : d)) }));
            return;
        }
        await apiData('sd-phone:bluetooth:forget', { id });
        set({ busyId: null });
        await get().scan(true);
    },

    disconnect: async (id) => {
        set({ busyId: id });
        if (!isFiveM) {
            set(s => ({ busyId: null, devices: s.devices.map(d => (d.id === id ? { ...d, connected: false } : d)) }));
            return;
        }
        await apiData('sd-phone:bluetooth:disconnect', { id });
        set({ busyId: null });
        await get().scan(true);
    },
}));

export function useBluetoothConfigured(): boolean {
    return useBluetoothStore(s => s.configured);
}
