import { Music2, Pause, Play, SkipBack, SkipForward } from 'lucide-react';

import type { WidgetSize } from '@/apps/appstore/appsApi';
import { coverGradient, coverUrl } from '@/apps/music/data';
import type { Track } from '@/apps/music/data';
import { useMusic } from '@/apps/music/MusicContext';
import { t } from '@/i18n';
import { WidgetTile } from './WidgetTile';

function Bleed({ track }: { track: Track | null }) {
    const img = track ? coverUrl(track) : null;
    return (
        <>
            <div
                className="absolute inset-0"
                style={{
                    backgroundImage: img ? `url("${img}")` : (track ? coverGradient(track.id + track.title) : undefined),
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                    filter: 'blur(26px) saturate(180%)',
                    transform: 'scale(1.35)',
                    opacity: track ? 0.85 : 0,
                }}
            />
            <div className="absolute inset-0" style={{ background: 'linear-gradient(165deg, rgba(0,0,0,0.32), rgba(0,0,0,0.72))' }} />
        </>
    );
}

function Art({ track, size, radius }: { track: Track | null; size: number; radius: number }) {
    const img = track ? coverUrl(track) : null;
    return (
        <div
            className="relative flex shrink-0 items-center justify-center overflow-hidden"
            style={{
                width: size, height: size, borderRadius: radius,
                background: track ? coverGradient(track.id + track.title) : 'linear-gradient(150deg, #3a3a3c, #1c1c1e)',
                boxShadow: '0 6px 16px rgba(0,0,0,0.45)',
            }}
        >
            {img
                ? <img src={img} alt="" draggable={false} className="h-full w-full object-cover" />
                : <Music2 className="opacity-55" style={{ width: size * 0.32, height: size * 0.32 }} strokeWidth={2.2} />}
        </div>
    );
}

function Transport({ scale = 1, onPrev, onToggle, onNext, playing }: {
    scale?: number; playing: boolean;
    onPrev: () => void; onToggle: () => void; onNext: () => void;
}) {
    const stop = (e: React.MouseEvent | React.PointerEvent) => e.stopPropagation();
    const btn = 'text-white active:scale-90 active:opacity-60';
    return (
        <div className="flex items-center justify-center" style={{ gap: 30 * scale }}>
            <button type="button" aria-label={t('music.previous', 'Previous')} onPointerDown={stop}
                onClick={e => { stop(e); onPrev(); }} className={btn} style={{ transition: 'transform 0.12s' }}>
                <SkipBack style={{ width: 21 * scale, height: 21 * scale }} fill="currentColor" strokeWidth={0} />
            </button>
            <button type="button" aria-label={playing ? t('music.pause', 'Pause') : t('music.play', 'Play')} onPointerDown={stop}
                onClick={e => { stop(e); onToggle(); }} className={btn} style={{ transition: 'transform 0.12s' }}>
                {playing
                    ? <Pause style={{ width: 27 * scale, height: 27 * scale }} fill="currentColor" strokeWidth={0} />
                    : <Play  style={{ width: 27 * scale, height: 27 * scale }} fill="currentColor" strokeWidth={0} />}
            </button>
            <button type="button" aria-label={t('music.next', 'Next')} onPointerDown={stop}
                onClick={e => { stop(e); onNext(); }} className={btn} style={{ transition: 'transform 0.12s' }}>
                <SkipForward style={{ width: 21 * scale, height: 21 * scale }} fill="currentColor" strokeWidth={0} />
            </button>
        </div>
    );
}

export function NowPlayingWidget({ size, width, height }: { size: WidgetSize; width: number; height: number }) {
    const { current, playing, toggle, next, prev } = useMusic();

    const title  = current?.title  ?? t('music.nothingPlaying', 'Not Playing');
    const artist = current?.artist ?? t('music.pickSomething', 'Nothing queued');

    if (size === 'sm') {
        return (
            <WidgetTile width={width} height={height} radius={22} bleed={<Bleed track={current} />} hairline={false}>
                <div className="flex h-full w-full flex-col justify-between p-3.5 text-white">
                    <Art track={current} size={Math.round(height * 0.42)} radius={12} />
                    <div className="min-w-0">
                        <div className="truncate text-[13px] font-semibold leading-tight">{title}</div>
                        <div className="truncate text-[11px] leading-tight opacity-60">{artist}</div>
                    </div>
                </div>
            </WidgetTile>
        );
    }

    if (size === 'lg') {
        const art = Math.min(width - 36, Math.round(height * 0.56));
        return (
            <WidgetTile width={width} height={height} radius={28} bleed={<Bleed track={current} />} hairline={false}>
                <div className="flex h-full w-full flex-col items-center gap-3 p-4 text-white">
                    <Art track={current} size={art} radius={18} />
                    <div className="w-full min-w-0 text-center">
                        <div className="truncate text-[18px] font-semibold leading-tight">{title}</div>
                        <div className="truncate text-[14px] leading-tight opacity-60">{artist}</div>
                    </div>
                    <div className="mt-auto w-full pb-1">
                        <Transport scale={1.15} playing={playing} onPrev={prev} onToggle={toggle} onNext={next} />
                    </div>
                </div>
            </WidgetTile>
        );
    }

    const art = height - 28;
    return (
        <WidgetTile width={width} height={height} radius={26} bleed={<Bleed track={current} />} hairline={false}>
            <div className="flex h-full w-full items-stretch gap-4 p-3.5 text-white">
                <Art track={current} size={art} radius={14} />
                <div className="flex min-w-0 flex-1 flex-col justify-between py-0.5">
                    <div className="min-w-0">
                        <div className="line-clamp-2 text-[16px] font-semibold leading-[19px]">{title}</div>
                        <div className="mt-1 truncate text-[13px] leading-tight opacity-60">{artist}</div>
                    </div>
                    <Transport playing={playing} onPrev={prev} onToggle={toggle} onNext={next} />
                </div>
            </div>
        </WidgetTile>
    );
}
