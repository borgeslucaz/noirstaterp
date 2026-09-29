import { Car } from 'lucide-react';

import type { WidgetSize, WidgetTheme } from '@/apps/appstore/appsApi';
import type { Vehicle, VehicleStatus } from '@/apps/garages/data';
import { t } from '@/i18n';
import { useWidgetData } from '@/stores/widgetDataStore';
import { WidgetTile, palette } from './WidgetTile';
import type { Palette } from './WidgetTile';

const STATUS: Record<VehicleStatus, { dot: string; label: () => string }> = {
    stored:  { dot: '#34c759', label: () => t('garages.stored', 'Stored') },
    out:     { dot: '#ff9f0a', label: () => t('garages.out', 'Out') },
    impound: { dot: '#ff3b30', label: () => t('garages.impound', 'Impounded') },
};

function Row({ v, showImage, h, p }: { v: Vehicle; showImage: boolean; h: number; p: Palette }) {
    const s = STATUS[v.status] ?? STATUS.stored;
    const imgH = Math.round(Math.min(h - 14, 78));
    const model = h >= 84 ? 19 : h >= 64 ? 17 : 15;
    const meta  = h >= 84 ? 13 : h >= 64 ? 12 : 11;
    const dot   = h >= 64 ? 9 : 8;
    return (
        <div className="flex shrink-0 items-center gap-3" style={{ height: h }}>
            {showImage && (
                <div
                    className="shrink-0 rounded-[7px]"
                    style={{
                        height: imgH,
                        width: Math.round(imgH * 1.55),
                        background: p.chip,
                        ...(v.image ? { backgroundImage: `url("${v.image}")`, backgroundSize: 'contain', backgroundRepeat: 'no-repeat', backgroundPosition: 'center' } : {}),
                    }}
                />
            )}
            <div className="min-w-0 flex-1">
                <div className="truncate font-semibold leading-tight" style={{ color: p.fg, fontSize: model }}>{v.model}</div>
                <div className="truncate leading-tight" style={{ color: p.sub, fontSize: meta }}>{v.location}</div>
                {h >= 58 && (
                    <div className="mt-[3px]">
                        <span
                            className="inline-block max-w-full truncate rounded-[4px] px-1.5 py-[1px] font-semibold uppercase leading-tight tracking-[0.13em]"
                            style={{ background: p.chip, color: p.fg, fontSize: meta - 1 }}
                        >
                            {v.plate}
                        </span>
                    </div>
                )}
            </div>
            <div className="flex shrink-0 items-center gap-1.5">
                <span className="rounded-full" style={{ width: dot, height: dot, background: s.dot }} />
                <span className="font-medium" style={{ color: p.sub, fontSize: meta }}>{s.label()}</span>
            </div>
        </div>
    );
}

export function GarageWidget({ size, width, height, theme = 'dark' }: {
    size: WidgetSize; width: number; height: number; theme?: WidgetTheme;
}) {
    const vehicles = useWidgetData(s => s.vehicles);
    const p = palette(theme);

    const sorted = [...vehicles].sort((a, b) => {
        const rank = (v: Vehicle) => (v.status === 'impound' ? 0 : v.status === 'out' ? 1 : 2);
        return rank(a) - rank(b);
    });

    const radius = size === 'sm' ? 22 : 26;

    if (sorted.length === 0) {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col items-center justify-center gap-2 p-4 text-center">
                    <Car className="h-6 w-6" strokeWidth={2} style={{ color: p.faint }} />
                    <span className="text-[12px]" style={{ color: p.sub }}>{t('garages.empty', 'No vehicles')}</span>
                </div>
            </WidgetTile>
        );
    }

    if (size === 'sm') {
        const v = sorted[0];
        const s = STATUS[v.status] ?? STATUS.stored;
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col p-3.5">
                    <div
                        className="min-h-0 w-full flex-1 rounded-[8px]"
                        style={{
                            background: p.chip,
                            ...(v.image ? { backgroundImage: `url("${v.image}")`, backgroundSize: 'contain', backgroundRepeat: 'no-repeat', backgroundPosition: 'center' } : {}),
                        }}
                    />
                    <div className="mt-2 min-w-0">
                        <div className="truncate text-[14px] font-semibold leading-tight" style={{ color: p.fg }}>{v.model}</div>
                        <div className="truncate text-[10px] leading-tight" style={{ color: p.sub }}>{v.location}</div>
                        <div className="mt-1 flex items-center gap-1.5">
                            <span className="h-[7px] w-[7px] rounded-full" style={{ background: s.dot }} />
                            <span className="text-[10px] font-medium" style={{ color: p.sub }}>{s.label()}</span>
                        </div>
                    </div>
                </div>
            </WidgetTile>
        );
    }

    const MAX_ROWS: Record<WidgetSize, number> = { sm: 1, md: 2, lg: 4 };
    const CHROME  = 62;
    const ROW_MIN = 56;
    const ROW_MAX = 112;
    const listH   = Math.max(ROW_MIN, height - CHROME);
    const rows    = sorted.slice(0, MAX_ROWS[size]);
    const rowH    = Math.max(ROW_MIN, Math.min(ROW_MAX, listH / rows.length));

    return (
        <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
            <div className="flex h-full w-full flex-col p-3.5">
                <div className="mb-1.5 flex shrink-0 items-center gap-1.5">
                    <Car className="h-[12px] w-[12px]" strokeWidth={2.6} style={{ color: p.sub }} />
                    <span className="text-[11px] font-semibold uppercase tracking-[0.12em]" style={{ color: p.sub }}>
                        {t('widgets.garage', 'Garage')}
                    </span>
                </div>
                <div className="flex min-h-0 flex-1 flex-col justify-between" style={{ color: p.fg }}>
                    {rows.map((v, i) => (
                        <div key={v.id} style={i ? { borderTop: `1px solid ${p.rule}` } : undefined}>
                            <Row v={v} showImage h={rowH} p={p} />
                        </div>
                    ))}
                </div>
            </div>
        </WidgetTile>
    );
}
