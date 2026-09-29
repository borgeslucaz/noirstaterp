import { useEffect, useRef, useState } from 'react';

import { t } from '@/i18n';
import { apiData } from '@/core/api';
import { AlertDialog } from '@/ui/AlertDialog';
import { requestPhoneReset, type PhoneResetScope } from '@/core/phoneReset';
import { ListGroup, ListRow } from '@/ui/ListGroup';
import { SubPage } from '../SettingsSubPage';

type Deadlines = Record<PhoneResetScope, number>;

const NONE: Deadlines = { settings: 0, erase: 0 };

export function ResetPhonePage({ onBack }: { onBack: () => void }) {
    const [confirm, setConfirm] = useState<PhoneResetScope | null>(null);
    const [deadlines, setDeadlines] = useState<Deadlines>(NONE);
    const [now, setNow] = useState(() => Date.now());
    const armed = useRef(false);

    useEffect(() => {
        let alive = true;
        void apiData<{ settings?: number; erase?: number }>('sd-phone:settings:resetCooldown').then(d => {
            if (!alive || !d) return;
            const at = Date.now();
            setDeadlines({
                settings: d.settings ? at + d.settings : 0,
                erase:    d.erase    ? at + d.erase    : 0,
            });
        });
        return () => { alive = false; };
    }, []);

    const waiting = Math.max(deadlines.settings, deadlines.erase) > now;
    useEffect(() => {
        if (!waiting) return;
        const id = window.setInterval(() => setNow(Date.now()), 250);
        return () => window.clearInterval(id);
    }, [waiting]);

    function leftFor(scope: PhoneResetScope): number {
        return Math.max(0, Math.ceil((deadlines[scope] - now) / 1000));
    }

    function run(scope: PhoneResetScope, windowMs: number) {
        if (armed.current) return;
        armed.current = true;
        setConfirm(null);
        setDeadlines(d => ({ ...d, [scope]: Date.now() + windowMs }));
        setNow(Date.now());
        requestPhoneReset(scope);
    }

    function subFor(scope: PhoneResetScope): string | undefined {
        const secs = leftFor(scope);
        return secs > 0 ? t('settings.resetAvailableIn', 'Available again in {n}s', { n: secs }) : undefined;
    }

    return (
        <>
            <SubPage title={t('settings.resetPhone', 'Reset Phone')} onBack={onBack}>
                <ListGroup footer={t('settings.resetAllFooter', 'Resetting puts every setting back to default. It does not sign you out or remove anything you have installed.')}>
                    <ListRow
                        label={t('settings.resetAllSettings', 'Reset All Settings')}
                        sub={subFor('settings')}
                        destructive
                        disabled={leftFor('settings') > 0}
                        onPress={() => setConfirm('settings')}
                    />
                </ListGroup>

                <ListGroup footer={t('settings.eraseAllFooter', 'Erases everything on this phone and takes you back through setup. Your saved passwords stay in the Passwords app, so you can sign back into your accounts. This cannot be undone.')}>
                    <ListRow
                        label={t('settings.eraseAllContent', 'Reset Phone Fully')}
                        sub={subFor('erase')}
                        destructive
                        disabled={leftFor('erase') > 0}
                        onPress={() => setConfirm('erase')}
                    />
                </ListGroup>
            </SubPage>

            {confirm === 'settings' && (
                <AlertDialog
                    title={t('settings.resetAllTitle', 'Reset All Settings?')}
                    message={t('settings.resetAllMessage', 'Your theme, wallpaper, Home Screen layout and other preferences go back to default. Your apps, accounts, passcode and contact card are kept.')}
                    confirmLabel={t('settings.resetConfirm', 'Reset')}
                    destructive
                    onCancel={() => setConfirm(null)}
                    onConfirm={() => run('settings', 2000)}
                />
            )}

            {confirm === 'erase' && (
                <AlertDialog
                    title={t('settings.eraseAllTitle', 'Reset Phone Fully?')}
                    message={t('settings.eraseAllMessage', 'Your phone is wiped back to factory defaults and you will be taken through setup again. Your saved passwords stay in the Passwords app, so you can sign back into your accounts. Server-side data such as mail accounts and group memberships is preserved.')}
                    confirmLabel={t('settings.eraseConfirm', 'Reset')}
                    destructive
                    onCancel={() => setConfirm(null)}
                    onConfirm={() => run('erase', 30000)}
                />
            )}
        </>
    );
}
