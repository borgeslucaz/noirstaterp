import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';

import { useAsyncData } from '@/hooks/useAsyncData';
import { useSessionState } from '@/hooks/useSessionState';
import { useDeckActive } from '@/shell/deckActive';

import { mdtViewEnter } from './mdtTheme';
import { SECTION_PERMISSION } from './data';
import type { Department, DepartmentType, MdtPermission, MdtSection, Offence, Officer } from './data';
import { mdtBootstrap } from './mdtApi';

export interface MdtTab {
    id:        string;
    section:   MdtSection;
    selection: Partial<Record<MdtSection, string | null>>;
}

export const MDT_MAX_TABS = 8;

export interface MdtSessionValue {
    me:         Officer | null;
    department: Department | null;
    offences:   Offence[];
    loading:    boolean;
    ready:      boolean;
    can:        (key: MdtPermission) => boolean;
    canOpen:    (section: MdtSection) => boolean;
    section:    MdtSection;
    setSection: (section: MdtSection) => void;
    selected:   string | null;
    select:     (ref: string | null) => void;
    open:       (section: MdtSection, ref?: string | null) => void;
    openRecord: (section: MdtSection, ref?: string | null) => void;
    setMe:      (officer: Officer) => void;
    refresh:    () => void;
    tabs:       MdtTab[];
    activeTab:  string;
    newTab:     () => void;
    closeTab:   (id: string) => void;
    selectTab:  (id: string) => void;
}

const MdtSessionContext = createContext<MdtSessionValue | null>(null);

export const MdtSessionProvider = MdtSessionContext.Provider;

export function useMdtSession(): MdtSessionValue {
    const value = useContext(MdtSessionContext);
    if (!value) throw new Error('useMdtSession used outside the MDT session provider');
    return value;
}

export function useViewEnter(mode: string | null): string {
    const shown = useRef<{ mode: string; cls: string } | null>(null);
    if (mode === null) return '';
    if (shown.current?.mode !== mode) {
        shown.current = { mode, cls: shown.current ? mdtViewEnter : '' };
    }
    return shown.current.cls;
}

export function useDeckRefresh(fn: () => void): void {
    const active = useDeckActive();
    const wasActive = useRef(active);
    const fnRef = useRef(fn);
    fnRef.current = fn;

    useEffect(() => {
        if (active && !wasActive.current) fnRef.current();
        wasActive.current = active;
    }, [active]);
}

const FIRST_TAB: MdtTab = { id: 't1', section: 'home', selection: {} };

function freeTabId(tabs: MdtTab[]): string {
    const used = new Set(tabs.map(tab => tab.id));
    let n = 1;
    while (used.has(`t${n}`)) n += 1;
    return `t${n}`;
}

export function useMdtSessionState(devDomain?: DepartmentType): MdtSessionValue {
    const [rawTabs, setTabs] = useSessionState<MdtTab[]>('mdt:tabs', [FIRST_TAB]);
    const [rawActive, setActive] = useSessionState<string>('mdt:activeTab', FIRST_TAB.id);
    const [meOverride, setMeOverride] = useState<Officer | null>(null);

    const tabs = useMemo(() => (rawTabs.length > 0 ? rawTabs : [FIRST_TAB]), [rawTabs]);
    const active = tabs.some(tab => tab.id === rawActive) ? rawActive : tabs[0].id;
    const current = tabs.find(tab => tab.id === active) ?? tabs[0];
    const section = current.section;
    const selection = current.selection;

    const patchActive = useCallback((patch: (tab: MdtTab) => MdtTab) => {
        setTabs(prev => {
            const list = prev.length > 0 ? prev : [FIRST_TAB];
            const at = list.some(tab => tab.id === active) ? active : list[0].id;
            return list.map(tab => (tab.id === at ? patch(tab) : tab));
        });
    }, [active, setTabs]);

    const setSection = useCallback((target: MdtSection) => {
        patchActive(tab => ({ ...tab, section: target }));
    }, [patchActive]);

    const newTab = useCallback(() => {
        setTabs(prev => {
            const list = prev.length > 0 ? prev : [FIRST_TAB];
            if (list.length >= MDT_MAX_TABS) return list;
            const id = freeTabId(list);
            setActive(id);
            return [...list, { id, section: 'home', selection: {} }];
        });
    }, [setTabs, setActive]);

    const closeTab = useCallback((id: string) => {
        setTabs(prev => {
            const list = prev.length > 0 ? prev : [FIRST_TAB];
            if (list.length <= 1) return list;
            const at = list.findIndex(tab => tab.id === id);
            if (at < 0) return list;
            const next = list.filter(tab => tab.id !== id);
            setActive(cur => (cur === id ? next[Math.min(at, next.length - 1)].id : cur));
            return next;
        });
    }, [setTabs, setActive]);

    const selectTab = useCallback((id: string) => setActive(id), [setActive]);

    const { data, loading, refetch } = useAsyncData(() => mdtBootstrap(devDomain), [devDomain]);
    const [settled, setSettled] = useState(false);

    useEffect(() => {
        if (!loading) setSettled(true);
    }, [loading]);

    useDeckRefresh(refetch);

    const grants = useMemo(() => new Set<string>(data?.grants ?? []), [data]);

    const can = useCallback((key: MdtPermission) => grants.has(key), [grants]);

    const canOpen = useCallback(
        (target: MdtSection) => grants.has(SECTION_PERMISSION[target]),
        [grants],
    );

    const select = useCallback(
        (ref: string | null) => patchActive(tab => ({
            ...tab,
            selection: { ...tab.selection, [tab.section]: ref },
        })),
        [patchActive],
    );

    const open = useCallback((target: MdtSection, ref?: string | null) => {
        patchActive(tab => ({
            ...tab,
            section: target,
            selection: ref === undefined ? tab.selection : { ...tab.selection, [target]: ref },
        }));
    }, [patchActive]);

    const setMe = useCallback((officer: Officer) => setMeOverride(officer), []);

    const me = meOverride ?? data?.me ?? null;

    return useMemo(() => ({
        me,
        department: data?.department ?? null,
        offences:   data?.offences ?? [],
        loading,
        ready:      data !== null || settled,
        can,
        canOpen,
        section,
        setSection,
        selected:   selection[section] ?? null,
        select,
        open,
        openRecord: open,
        setMe,
        refresh:    refetch,
        tabs,
        activeTab:  active,
        newTab,
        closeTab,
        selectTab,
    }), [me, data, loading, settled, can, canOpen, section, setSection, selection, select, open, setMe, refetch,
        tabs, active, newTab, closeTab, selectTab]);
}
