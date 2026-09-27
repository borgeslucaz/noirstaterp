import { t } from '@/i18n';
import { useTheme, type MotionLevel } from '@/stores/themeStore';
import { ListGroup, ListRow, ToggleRow } from '@/ui/ListGroup';
import { SubPage } from '../SettingsSubPage';

const MOTION_OPTIONS: { id: MotionLevel; label: () => string; sub: () => string }[] = [
    {
        id: 'full',
        label: () => t('settings.motionFull', 'Normal'),
        sub:   () => t('settings.motionFullSub', 'Everything animates'),
    },
    {
        id: 'reduced',
        label: () => t('settings.motionReduced', 'Reduce Motion'),
        sub:   () => t('settings.motionReducedSub', 'Calms apps and panels. Unlocking and the Home Screen still animate.'),
    },
    {
        id: 'off',
        label: () => t('settings.motionOff', 'No Motion'),
        sub:   () => t('settings.motionOffSub', 'Nothing animates anywhere, including unlocking.'),
    },
];

export function AccessibilityPage({ onBack }: { onBack: () => void }) {
    const { motion, setMotion, boldText, setBoldText } = useTheme(
        'motion', 'setMotion', 'boldText', 'setBoldText',
    );

    return (
        <SubPage
            title={t('settings.accessibility', 'Accessibility')}
            backLabel={t('settings.settings', 'Settings')}
            onBack={onBack}
        >
            <ListGroup header={t('settings.a11yMotionHeader', 'MOTION')}>
                {MOTION_OPTIONS.map((o, i) => (
                    <ListRow
                        key={o.id}
                        label={o.label()}
                        sub={o.sub()}
                        chevron={false}
                        selected={motion === o.id}
                        onPress={() => setMotion(o.id)}
                        divider={i < MOTION_OPTIONS.length - 1}
                    />
                ))}
            </ListGroup>

            <ListGroup
                header={t('settings.a11yDisplayHeader', 'DISPLAY')}
                footer={t('settings.a11yBoldTextFooter', 'Thickens lighter text so it reads more easily. Headings keep their weight.')}
            >
                <ToggleRow
                    label={t('settings.a11yBoldText', 'Bold Text')}
                    on={boldText}
                    onToggle={() => setBoldText(!boldText)}
                />
            </ListGroup>
        </SubPage>
    );
}
