import { create } from 'zustand';

import type { AppDef } from '@/core/types';

interface InstalledAppsState {
    apps:    AppDef[];
    setApps: (apps: AppDef[]) => void;
}

export const useInstalledAppsStore = create<InstalledAppsState>((set) => ({
    apps: [],
    setApps: (apps) => set(s => (
        s.apps.length === apps.length && s.apps.every((a, i) => a.id === apps[i]?.id)
            ? s
            : { apps }
    )),
}));

export function useInstalledApps(): AppDef[] {
    return useInstalledAppsStore(s => s.apps);
}
