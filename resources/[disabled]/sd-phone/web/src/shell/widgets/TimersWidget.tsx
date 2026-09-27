import { AlarmClock, Pause, Timer as TimerIcon } from 'lucide-react';

import type { WidgetSize, WidgetTheme } from '@/apps/appstore/appsApi';
import type { AlarmDef } from '@/apps/clock/data';
import { formatClockTime, useClock } from '@/hooks/useClock';
import { t } from '@/i18n';
import { useAlarms } from '@/stores/alarmStore';
import { useTheme } from '@/stores/themeStore';
import { useTimer } from '@/stores/timerStore';
import { WidgetTile, palette } from './WidgetTile';
import type { Palette } from './WidgetTile';

const ACCENT = '#ff9f0a';

function clock(ms: number): string {
    const total = Math.max(0, Math.ceil(ms / 1000));
    const h = Math.floor(total / 3600);
    const m = Math.floor((total % 3600) / 60);
    const s = total % 60;
    const pad = (n: number) => String(n).padStart(2, '0');
    return h ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

function until(ms: number): string {
    const mins = Math.max(0, Math.round(ms / 60000));
    const h = Math.floor(mins / 60);
    const m = mins % 60;
    if (h && m) return t('widgets.inHM', 'in {h}h {m}m', { h, m });
    if (h)      return t('widgets.inH', 'in {h}h', { h });
    return t('widgets.inM', 'in {m}m', { m });
}

function nextAlarm(alarms: AlarmDef[], now: Date): { alarm: AlarmDef; at: Date; inMs: number } | null {
    let best: { alarm: AlarmDef; at: Date; inMs: number } | null = null;
    for (const a of alarms) {
        if (!a.enabled) continue;
        const at = new Date(now);
        at.setHours(a.hour, a.minute, 0, 0);
        if (at.getTime() <= now.getTime()) at.setDate(at.getDate() + 1);
        const inMs = at.getTime() - now.getTime();
        if (!best || inMs < best.inMs) best = { alarm: a, at, inMs };
    }
    return best;
}

function Dial({ px, frac, track, children }: {
    px: number; frac: number; track: string; children?: React.ReactNode;
}) {
    const stroke = Math.max(4, Math.round(px * 0.07));
    const r = px / 2 - stroke / 2;
    const circ = 2 * Math.PI * r;
    return (
        <div className="relative shrink-0" style={{ width: px, height: px }}>
            <svg width={px} height={px} viewBox={`0 0 ${px} ${px}`} aria-hidden className="absolute inset-0">
                <circle cx={px / 2} cy={px / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
                <circle
                    cx={px / 2} cy={px / 2} r={r}
                    fill="none" stroke={ACCENT} strokeWidth={stroke} strokeLinecap="round"
                    strokeDasharray={circ}
                    strokeDashoffset={circ * (1 - Math.max(0, Math.min(1, frac)))}
                    transform={`rotate(-90 ${px / 2} ${px / 2})`}
                    style={{ transition: 'stroke-dashoffset 0.9s linear' }}
                />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">{children}</div>
        </div>
    );
}

function AlarmRow({ a, hour24, p, h }: { a: AlarmDef; hour24: boolean; p: Palette; h: number }) {
    const d = new Date();
    d.setHours(a.hour, a.minute, 0, 0);
    const ink = a.enabled ? p.fg : p.faint;
    return (
        <div className="flex items-center gap-2" style={{ height: h }}>
            <span className="w-[72px] shrink-0 text-[15px] font-medium tabular-nums" style={{ color: ink }}>
                {formatClockTime(d, hour24)}
            </span>
            <span className="min-w-0 flex-1 truncate text-[11px]" style={{ color: a.enabled ? p.sub : p.faint }}>
                {a.label}
            </span>
            <span
                className="h-[6px] w-[6px] shrink-0 rounded-full"
                style={{ background: a.enabled ? ACCENT : 'transparent', border: a.enabled ? undefined : `1px solid ${p.rule}` }}
            />
        </div>
    );
}

export function TimersWidget({ size, width, height, theme = 'dark' }: {
    size: WidgetSize; width: number; height: number; theme?: WidgetTheme;
}) {
    const now = useClock('second');
    const { hour24 } = useTheme('hour24');
    const { status, endsAt, totalSecs } = useTimer();
    const { alarms } = useAlarms();

    const p = palette(theme);
    const radius = size === 'sm' ? 22 : 26;

    const live = status === 'running' || status === 'paused';
    const remainMs = live ? Math.max(0, endsAt - now.getTime()) : 0;
    const frac = totalSecs > 0 ? remainMs / (totalSecs * 1000) : 0;
    const next = nextAlarm(alarms, now);
    const endsAtLabel = live ? formatClockTime(new Date(now.getTime() + remainMs), hour24) : '';

    if (!live && !next && alarms.length === 0) {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col items-center justify-center gap-2 p-4 text-center">
                    <AlarmClock className="h-6 w-6" strokeWidth={2} style={{ color: p.faint }} />
                    <span className="text-[12px] leading-snug" style={{ color: p.sub }}>
                        {t('widgets.noTimers', 'No timer or alarm set')}
                    </span>
                </div>
            </WidgetTile>
        );
    }

    const Kicker = ({ px }: { px: number }) => (
        <div className="flex items-center gap-1.5">
            {live
                ? <TimerIcon className="shrink-0" strokeWidth={2.6} style={{ color: ACCENT, width: px, height: px }} />
                : <AlarmClock className="shrink-0" strokeWidth={2.6} style={{ color: ACCENT, width: px, height: px }} />}
            <span className="truncate text-[11px] font-semibold uppercase tracking-[0.1em]" style={{ color: p.sub }}>
                {live
                    ? (status === 'paused' ? t('clock.paused', 'Paused') : t('clock.timer', 'Timer'))
                    : t('widgets.nextAlarm', 'Next Alarm')}
            </span>
        </div>
    );

    if (size === 'sm') {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col justify-center p-3.5">
                    {live ? (
                        <div className="flex flex-col items-center">
                            <Dial px={width - 56} frac={frac} track={p.chip}>
                                <span className="text-[15px] font-medium tabular-nums" style={{ color: p.fg }}>{clock(remainMs)}</span>
                                {status === 'paused' && <Pause className="mt-0.5 h-3 w-3" strokeWidth={2.6} style={{ color: p.faint }} />}
                            </Dial>
                            <span className="mt-2 text-[10px] font-semibold uppercase tracking-[0.1em]" style={{ color: p.sub }}>
                                {status === 'paused' ? t('clock.paused', 'Paused') : t('clock.timer', 'Timer')}
                            </span>
                        </div>
                    ) : next ? (
                        <>
                            <Kicker px={12} />
                            <div className="mt-1 text-[30px] font-light leading-none tabular-nums tracking-tight" style={{ color: p.fg }}>
                                {formatClockTime(next.at, hour24)}
                            </div>
                            <div className="mt-1.5 truncate text-[11px]" style={{ color: p.sub }}>{next.alarm.label}</div>
                            <div className="truncate text-[11px]" style={{ color: p.faint }}>{until(next.inMs)}</div>
                        </>
                    ) : (
                        <div className="flex flex-col items-center gap-2 text-center">
                            <AlarmClock className="h-6 w-6" strokeWidth={2} style={{ color: p.faint }} />
                            <span className="text-[11px]" style={{ color: p.sub }}>{t('widgets.noTimers', 'No timer or alarm set')}</span>
                        </div>
                    )}
                </div>
            </WidgetTile>
        );
    }

    const pool = live ? alarms : alarms.filter(a => a.id !== next?.alarm.id);
    const rows = pool.slice(0, size === 'lg' ? 5 : 2);

    if (size === 'md') {
        const px = height - 46;
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full items-center gap-4 p-4">
                    {live ? (
                        <Dial px={px} frac={frac} track={p.chip}>
                            {status === 'paused' && <Pause className="h-4 w-4" strokeWidth={2.6} style={{ color: p.faint }} />}
                        </Dial>
                    ) : (
                        <Dial px={px} frac={1} track={p.chip}>
                            <AlarmClock className="h-5 w-5" strokeWidth={2.2} style={{ color: ACCENT }} />
                        </Dial>
                    )}
                    <div className="flex min-w-0 flex-1 flex-col">
                        <Kicker px={12} />
                        <div className="mt-0.5 font-light leading-none tabular-nums tracking-tight" style={{ color: p.fg, fontSize: live ? 40 : 44 }}>
                            {live ? clock(remainMs) : next ? formatClockTime(next.at, hour24) : '--:--'}
                        </div>
                        <div className="mt-1.5 truncate text-[12px]" style={{ color: p.sub }}>
                            {live
                                ? t('widgets.endsAt', 'Ends {time}', { time: endsAtLabel })
                                : next ? `${next.alarm.label} · ${until(next.inMs)}` : ''}
                        </div>
                        <div className="mt-auto flex flex-col pt-1.5" style={{ borderTop: `1px solid ${p.rule}` }}>
                            {rows.map(a => <AlarmRow key={a.id} a={a} hour24={hour24} p={p} h={20} />)}
                        </div>
                    </div>
                </div>
            </WidgetTile>
        );
    }

    const listed = rows;
    const dialPx = Math.min(width - 96, 196);
    return (
        <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
            <div className="flex h-full w-full flex-col p-4">
                <Kicker px={13} />
                <div className="mt-2 flex shrink-0 justify-center">
                    <Dial px={dialPx} frac={live ? frac : 1} track={p.chip}>
                        {live ? (
                            <>
                                <span className="text-[34px] font-light leading-none tabular-nums tracking-tight" style={{ color: p.fg }}>
                                    {clock(remainMs)}
                                </span>
                                <span className="mt-1.5 text-[11px] tabular-nums" style={{ color: p.sub }}>
                                    {t('widgets.endsAt', 'Ends {time}', { time: endsAtLabel })}
                                </span>
                                {status === 'paused' && <Pause className="mt-1 h-4 w-4" strokeWidth={2.6} style={{ color: p.faint }} />}
                            </>
                        ) : next ? (
                            <>
                                <span className="text-[38px] font-light leading-none tabular-nums tracking-tight" style={{ color: p.fg }}>
                                    {formatClockTime(next.at, hour24)}
                                </span>
                                <span className="mt-1.5 max-w-[80%] truncate text-[12px]" style={{ color: p.sub }}>{next.alarm.label}</span>
                                <span className="text-[11px]" style={{ color: p.faint }}>{until(next.inMs)}</span>
                            </>
                        ) : (
                            <AlarmClock className="h-7 w-7" strokeWidth={2} style={{ color: p.faint }} />
                        )}
                    </Dial>
                </div>

                <div className="mt-3 flex min-h-0 flex-1 flex-col pt-2" style={{ borderTop: `1px solid ${p.rule}` }}>
                    <span className="mb-1 shrink-0 text-[10px] font-semibold uppercase tracking-[0.12em]" style={{ color: p.faint }}>
                        {t('widgets.alarms', 'Alarms')}
                    </span>
                    {listed.length > 0 ? (
                        <div className="flex min-h-0 flex-1 flex-col justify-between">
                            {listed.map(a => <AlarmRow key={a.id} a={a} hour24={hour24} p={p} h={24} />)}
                        </div>
                    ) : (
                        <div className="flex min-h-0 flex-1 items-center justify-center">
                            <span className="text-[12px]" style={{ color: p.faint }}>
                                {live
                                    ? t('widgets.noAlarmsSet', 'No alarms set')
                                    : t('widgets.noOtherAlarms', 'No other alarms')}
                            </span>
                        </div>
                    )}
                </div>
            </div>
        </WidgetTile>
    );
}
