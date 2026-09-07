import { X } from 'lucide-react';

import { t } from '@/i18n';
import { useIosPush } from '@/hooks/useIosPush';
import { useTheme } from '@/stores/themeStore';
import { NavBar } from '@/ui/NavBar';
import { ISLAND_PETS, IslandPetArt, islandPetLabel, SPRITE_H, SPRITE_W } from '@/shell/islandPets';

const ISLAND_W = 126;
const ISLAND_H = 37;
const PET_H = 26;
const PET_W = PET_H * (SPRITE_W / SPRITE_H);
const PET_LEFT = 9;
const PET_FLOOR = 4;
const PET_RUN = Math.floor(ISLAND_W - PET_LEFT - PET_W - 26);

export function IslandPetPage({ onBack }: { onBack: () => void }) {
    const { goBack, pageStyle } = useIosPush(onBack);
    const { islandPet, setIslandPet } = useTheme('islandPet', 'setIslandPet');

    return (
        <div
            className="absolute inset-0 z-20 flex flex-col bg-base text-black dark:text-white"
            style={pageStyle}
        >
            <div className="h-11 shrink-0" aria-hidden />

            <NavBar
                backLabel={t('settings.settings', 'Settings')}
                onBack={goBack}
                title={t('settings.islandPet', 'Island Pets')}
                hairline
            />

            <div className="flex-1 overflow-y-auto no-scrollbar">
                <div className="mt-6 flex flex-col gap-7 px-4 pb-10">

                    <section className="flex flex-col items-center gap-3">
                        <div
                            className="flex w-full justify-center rounded-[16px] py-6"
                            style={{ background: 'linear-gradient(160deg, #2b2f45 0%, #14161f 100%)' }}
                        >
                            <div
                                className="relative rounded-full bg-black"
                                style={{ width: ISLAND_W, height: ISLAND_H }}
                            >
                                {islandPet !== 'none' && (
                                    <span
                                        className="sd-pet-walker absolute block"
                                        style={{
                                            left:   PET_LEFT,
                                            top:    ISLAND_H - PET_FLOOR - PET_H,
                                            width:  PET_W,
                                            height: PET_H,
                                            ['--pet-run' as string]: `${PET_RUN}px`,
                                            animationTimingFunction: `steps(${PET_RUN}, end)`,
                                        }}
                                    >
                                        <IslandPetArt id={islandPet} mood="idle" height={PET_H} />
                                    </span>
                                )}
                            </div>
                        </div>
                        <p className="px-2 text-center text-[12.5px] leading-snug text-ios-gray">
                            {t('settings.islandPetHint', 'Your pet lives on the Dynamic Island and steps aside for calls, music and alarms. Tap it on the island to say hello.')}
                        </p>
                    </section>

                    <section>
                        <p className="mb-2 text-[12px] uppercase tracking-widest text-ios-gray">
                            {t('settings.islandPetChoose', 'Choose a Pet')}
                        </p>
                        <div className="rounded-[12px] bg-surface px-3 py-4">
                            <div className="grid grid-cols-4 gap-x-2 gap-y-4">
                                {ISLAND_PETS.map(id => {
                                    const selected = id === islandPet;
                                    return (
                                        <button
                                            key={id}
                                            type="button"
                                            onClick={() => setIslandPet(id)}
                                            className="flex flex-col items-center gap-1.5"
                                        >
                                            <span
                                                className={[
                                                    'flex h-[54px] w-[54px] items-center justify-center rounded-[14px] transition-colors',
                                                    selected
                                                        ? 'bg-ios-blue'
                                                        : 'bg-black/[0.06] dark:bg-white/[0.08]',
                                                ].join(' ')}
                                            >
                                                {id === 'none'
                                                    ? <X className="h-[19px] w-[19px] text-ios-gray" strokeWidth={2.4} />
                                                    : <IslandPetArt id={id} mood="idle" height={32} />}
                                            </span>
                                            <span className={[
                                                'text-[11px] leading-tight',
                                                selected ? 'font-semibold text-ios-blue' : 'text-ios-gray',
                                            ].join(' ')}>
                                                {islandPetLabel(id)}
                                            </span>
                                        </button>
                                    );
                                })}
                            </div>
                        </div>
                    </section>

                    <section>
                        <p className="mb-2 text-[12px] uppercase tracking-widest text-ios-gray">
                            {t('settings.islandPetMoods', 'Moods')}
                        </p>
                        <div className="overflow-hidden rounded-[12px] bg-surface">
                            <MoodRow label={t('settings.islandPetMoodDance', 'Dances while music plays')} />
                            <MoodRow label={t('settings.islandPetMoodStartle', 'Jumps at calls and alarms')} />
                            <MoodRow label={t('settings.islandPetMoodSleep', 'Naps when the battery is low')} />
                            <MoodRow label={t('settings.islandPetMoodHide', 'Steps off for Live Activities')} last />
                        </div>
                    </section>

                </div>
            </div>
        </div>
    );
}

function MoodRow({ label, last }: { label: string; last?: boolean }) {
    return (
        <div className={`px-4 py-3 text-[15px] text-black dark:text-white ${last ? '' : 'border-b border-ios-gray4 dark:border-control'}`}>
            {label}
        </div>
    );
}
