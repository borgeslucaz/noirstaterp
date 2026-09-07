import { t } from '@/i18n';
import { ListGroup, ToggleRow } from '@/ui/ListGroup';
import { useTheme } from '@/stores/themeStore';
import { STREAMER_HIDE_KEYS, type StreamerHideKey } from '@/shell/streamerMode';
import { SubPage } from '../SettingsSubPage';

function labelFor(key: StreamerHideKey): string {
    switch (key) {
        case 'balance':      return t('settings.streamerHideBalance', 'Bank Balance');
        case 'transactions': return t('settings.streamerHideTransactions', 'Transaction Amounts');
        case 'card':         return t('settings.streamerHideCard', 'Card Number');
        case 'investments':  return t('settings.streamerHideInvestments', 'Investments');
        case 'number':       return t('settings.streamerHideNumber', 'Phone Numbers');
        case 'previews':     return t('settings.streamerHidePreviews', 'Notification Previews');
    }
}

export function StreamerModePage({ onBack }: { onBack: () => void }) {
    const { streamerMode, setStreamerMode, streamerHide, setStreamerHide } =
        useTheme('streamerMode', 'setStreamerMode', 'streamerHide', 'setStreamerHide');

    return (
        <SubPage title={t('settings.streamerMode', 'Streamer Mode')} backLabel={t('settings.settings', 'Settings')} onBack={onBack}>
            <ListGroup footer={t('settings.streamerModeFooter', 'Blanks the details below so they cannot be read off your stream. Nothing is changed for anyone else, and turning it off puts everything straight back.')}>
                <ToggleRow
                    label={t('settings.streamerMode', 'Streamer Mode')}
                    on={streamerMode}
                    onToggle={() => setStreamerMode(!streamerMode)}
                />
            </ListGroup>

            <ListGroup
                header={t('settings.streamerHideHeader', 'Hide')}
                footer={t('settings.streamerHideFooter', 'Pick exactly what gets blanked. These stay as you set them while Streamer Mode is off.')}
            >
                {STREAMER_HIDE_KEYS.map((key, i) => (
                    <ToggleRow
                        key={key}
                        label={labelFor(key)}
                        on={streamerHide[key] !== false}
                        onToggle={() => setStreamerHide(key, streamerHide[key] === false)}
                        divider={i < STREAMER_HIDE_KEYS.length - 1}
                    />
                ))}
            </ListGroup>
        </SubPage>
    );
}
