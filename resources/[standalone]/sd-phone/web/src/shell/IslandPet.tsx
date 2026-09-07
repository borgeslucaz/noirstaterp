import { useEffect, useRef, useState } from 'react';

import { IslandPetArt, SPRITE_H, SPRITE_W, type IslandPetId, type PetMood } from './islandPets';

const LEAVE_MS = 240;
const SWAP_MS = 420;
const CHEER_MS = 1800;
const LOW_BATTERY = 20;
const MIN_RUN = 24;

const WALK_MS: [number, number] = [5500, 11000];
const REST_MS: [number, number] = [2000, 4500];

const rand = ([lo, hi]: [number, number]) => lo + Math.random() * (hi - lo);

export interface PetStage {
    left: number;
    run:  number;
}

export function IslandPet({ id, stage, top, height, battery, playing, ringing }: {
    id:      IslandPetId;
    stage:   PetStage | null;
    top:     number;
    height:  number;
    battery: number;
    playing: boolean;
    ringing: boolean;
}) {
    const [live,     setLive]     = useState<PetStage | null>(stage);
    const [leaving,  setLeaving]  = useState(false);
    const [cheering, setCheering] = useState(false);
    const [resting,  setResting]  = useState(false);
    const stageRef   = useRef(stage);
    const swapTimer  = useRef<ReturnType<typeof setTimeout> | null>(null);
    const cheerTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

    useEffect(() => { stageRef.current = stage; });

    const stageKey = stage ? `${Math.round(stage.left)}:${Math.round(stage.run)}` : 'off';
    const liveKey  = live  ? `${Math.round(live.left)}:${Math.round(live.run)}`   : 'off';

    useEffect(() => {
        if (stageKey === liveKey) {
            if (swapTimer.current) { clearTimeout(swapTimer.current); swapTimer.current = null; }
            setLeaving(false);
            return;
        }
        if (liveKey === 'off') { setLive(stageRef.current); setLeaving(false); return; }
        if (swapTimer.current) return;
        setLeaving(true);
        swapTimer.current = setTimeout(() => {
            swapTimer.current = null;
            setLive(stageRef.current);
            setLeaving(false);
        }, stageKey === 'off' ? LEAVE_MS : SWAP_MS);
    }, [stageKey, liveKey]);

    useEffect(() => () => {
        if (swapTimer.current)  clearTimeout(swapTimer.current);
        if (cheerTimer.current) clearTimeout(cheerTimer.current);
    }, []);

    const alive = live !== null;
    useEffect(() => {
        if (!alive) return;
        let stop = false;
        let timer: ReturnType<typeof setTimeout>;
        const step = () => {
            if (stop) return;
            setResting(was => {
                const next = !was;
                timer = setTimeout(step, next ? rand(REST_MS) : rand(WALK_MS));
                return next;
            });
        };
        timer = setTimeout(step, rand(WALK_MS));
        return () => { stop = true; clearTimeout(timer); };
    }, [alive]);

    if (id === 'none' || !live) return null;

    const mood: PetMood =
        ringing                  ? 'startled'
        : playing                ? 'dancing'
        : cheering               ? 'happy'
        : battery <= LOW_BATTERY ? 'sleepy'
        : 'idle';

    const roaming = (mood === 'idle' || mood === 'happy') && live.run >= MIN_RUN;
    const still   = roaming && resting;
    const width   = height * (SPRITE_W / SPRITE_H);

    function poke() {
        if (cheerTimer.current) clearTimeout(cheerTimer.current);
        setCheering(true);
        cheerTimer.current = setTimeout(() => { setCheering(false); cheerTimer.current = null; }, CHEER_MS);
    }

    return (
        <button
            type="button"
            onClick={poke}
            aria-hidden
            tabIndex={-1}
            className={`absolute z-[301] cursor-pointer bg-transparent p-0 ${leaving ? 'sd-pet-out' : 'sd-pet-in'}`}
            style={{ left: live.left, top, width, height }}
        >
            <span
                className={roaming ? 'sd-pet-walker' : undefined}
                style={{
                    display: 'block',
                    ['--pet-run' as string]: `${live.run}px`,
                    animationTimingFunction: `steps(${Math.max(1, live.run)}, end)`,
                    animationPlayState: still ? 'paused' : 'running',
                }}
            >
                <IslandPetArt id={id} mood={still ? 'resting' : mood} height={height} />
            </span>
        </button>
    );
}
