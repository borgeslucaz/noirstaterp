import { useMemo } from 'react'
import type { HistoryEntry, Language, PlayerData, XpTable } from '../types/trucking'
import { makeT, money } from '../utils/format'

type Props = {
  playerData: PlayerData
  language: Language
  xp: XpTable
}

export function ProfileView({ playerData, language, xp }: Props) {
  const t = useMemo(() => makeT(language), [language])
  const level = playerData.level ?? 1
  const currentXp = playerData.xp ?? 0
  const nextXp = Array.isArray(xp) ? xp[level - 1] ?? level * 1000 : xp[level] ?? level * 1000
  const progress = nextXp > 0 ? Math.min(100, Math.round((currentXp / nextXp) * 100)) : 100
  const history = [...(playerData.history ?? [])].sort((a, b) => (b.date ?? 0) - (a.date ?? 0))

  return (
    <div className="profile-view">
      <section className="profile-stats">
        <Stat
          label={t('completed_jobs', 'Entregas Concluídas')}
          value={`${playerData.globalCompleted ?? playerData.completedJobs ?? 0}`}
          helper={`${t('total_missions_completed', '')}${playerData.failedJobs ? ` · ${playerData.failedJobs} ${t('result_failed', 'Fracassada').toLowerCase()}` : ''}`}
        />
        <Stat label={t('total_earnings', 'Ganhos Totais')} value={money(playerData.totalEarnings)} helper={t('total_earnings_desc', '')} />
        <article className="stat">
          <p>{t('current_level', 'Nível Atual')}</p>
          <h2>{level}</h2>
          <div className="meter__track"><span style={{ width: `${progress}%` }} /></div>
          <span>{currentXp.toLocaleString('en-US')} / {nextXp.toLocaleString('en-US')} XP · {Math.max(0, nextXp - currentXp).toLocaleString('en-US')} {t('xp_to_next', 'XP para o próximo nível')}</span>
        </article>
      </section>
      <section className="history-panel">
        <div className="section-heading">
          <div>
            <p>{t('latest_works', 'Últimas Entregas')}</p>
            <h2>{t('recent_deliveries', 'Entregas recentes')}</h2>
          </div>
        </div>
        {history.length === 0 && <p className="history-empty">{t('no_history', 'Nenhuma entrega registrada ainda.')}</p>}
        {history.map((entry) => (
          <HistoryRow entry={entry} key={`${entry.sessionId ?? entry.label}-${entry.date}`} language={language} />
        ))}
      </section>
    </div>
  )
}

function HistoryRow({ entry, language }: { entry: HistoryEntry; language: Language }) {
  const t = makeT(language)
  const status = entry.status ?? 'completed'
  const resultLabel =
    status === 'completed' ? t('result_completed', 'Concluída')
      : status === 'failed_system' ? t('result_failed_system', 'Encerrada (técnica)')
        : t('result_failed', 'Fracassada')
  const date = entry.completedAt ?? entry.date

  return (
    <div className={`history-row history-row--${status}`}>
      <div className={`history-grade history-grade--${entry.grade ?? 'none'}`}>{entry.grade ?? '—'}</div>
      <div>
        <strong>{entry.label}</strong>
        <span>
          {entry.company ? `${entry.company} · ` : ''}
          {entry.tier ? `${t(`tier_${entry.tier}`, entry.tier)} · ` : ''}
          {entry.routeLabel ?? entry.supply ?? ''}
        </span>
      </div>
      <div className="history-money">
        {status === 'completed' ? (
          <>
            <p>{money(entry.total ?? entry.earn)}</p>
            <span>
              {t('base', 'Base')} {money(entry.basePay ?? entry.earn)}
              {entry.bonus ? ` · ${t('bonus', 'Bônus')} +${money(entry.bonus)}` : ''}
              {entry.penalty ? ` · -${money(entry.penalty)}` : ''}
            </span>
          </>
        ) : (
          <p className="is-muted">{resultLabel}</p>
        )}
      </div>
      <time>{date ? new Date(date * 1000).toLocaleDateString() : ''}</time>
    </div>
  )
}

function Stat({ label, value, helper }: { label: string; value: string; helper: string }) {
  return (
    <article className="stat">
      <p>{label}</p>
      <h2>{value}</h2>
      <span>{helper}</span>
    </article>
  )
}
