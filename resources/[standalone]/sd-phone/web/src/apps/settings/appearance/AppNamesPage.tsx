import { useState } from 'react';

import { t } from '@/i18n';
import { useTheme, APP_LABEL_MAX } from '@/stores/themeStore';
import { useInstalledAppsStore } from '@/stores/installedAppsStore';
import { ListGroup, ListRow } from '@/ui/ListGroup';
import { PromptDialog } from '@/ui/PromptDialog';
import { SubPage } from '../SettingsSubPage';

export function AppNamesPage({ onBack }: { onBack: () => void }) {
    const { appLabels, setAppLabel, resetAppLabels } = useTheme('appLabels', 'setAppLabel', 'resetAppLabels');
    const apps = useInstalledAppsStore(s => s.apps);
    const [renaming, setRenaming] = useState<string | null>(null);

    const target = renaming === null ? null : apps.find(a => a.id === renaming) ?? null;
    const renamedCount = Object.keys(appLabels).length;
    const sorted = [...apps].sort((a, b) => a.label.localeCompare(b.label));

    return (
        <SubPage
            title={t('settings.renameApps', 'Rename Apps')}
            backLabel={t('settings.appIcons', 'App Icons')}
            onBack={onBack}
        >
            <ListGroup footer={t('settings.renameAppsFooter', 'Names change only on your phone. Nobody else sees them.')}>
                {sorted.map((app, i) => (
                    <ListRow
                        key={app.id}
                        label={app.label}
                        sub={appLabels[app.id] ? t('settings.renameAppsRenamed', 'Renamed') : undefined}
                        onPress={() => setRenaming(app.id)}
                        divider={i < sorted.length - 1}
                    />
                ))}
            </ListGroup>

            {renamedCount > 0 && (
                <ListGroup>
                    <ListRow
                        label={t('settings.renameAppsReset', 'Reset All Names')}
                        destructive
                        chevron={false}
                        onPress={resetAppLabels}
                    />
                </ListGroup>
            )}

            {target && (
                <PromptDialog
                    title={t('settings.renameAppTitle', 'Rename App')}
                    message={t('settings.renameAppBody', 'Type the original name to put it back.')}
                    placeholder={target.label}
                    initialValue={appLabels[target.id] ?? target.label}
                    maxLength={APP_LABEL_MAX}
                    confirmLabel={t('settings.save', 'Save')}
                    onConfirm={value => { setAppLabel(target.id, value); setRenaming(null); }}
                    onCancel={() => setRenaming(null)}
                />
            )}
        </SubPage>
    );
}
