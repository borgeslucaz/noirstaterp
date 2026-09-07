import { useEffect, useMemo, useState } from 'react'
import type { Language, LeaderboardEntry, LeaderboardResponse } from '../types/trucking'
import { fetchNui, isFiveM } from '../utils/nui'
import { makeT } from '../utils/format'

type Props = {
  language: Language
}

type Metric = 'level' | 'global'

export function LeaderboardView({ language }: Props) {
  const t = useMemo(() => makeT(language), [language])
  const [metric, setMetric] = useState<Metric>('level')
  const [drivers, setDrivers] = useState<LeaderboardEntry[]>([])
  const [me, setMe] = useState<LeaderboardResponse['me']>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let mounted = true
    setLoading(true)
    if (!isFiveM()) {
      setDrivers([])
      setMe(null)
      setLoading(false)
      return
    }
    void fetchNui<LeaderboardResponse>('getLeaderboard', { metric }).then((response) => {
      if (!mounted) return
      setDrivers(response?.data ?? [])
      setMe(response?.me ?? null)
      setLoading(false)
    })
    return () => {
      mounted = false
    }
  }, [metric])

  const valueOf = (driver: LeaderboardEntry) =>
    metric === 'global'
      ? `${driver.globalCompleted} ${t('deliveries', 'entregas')}`
      : `${t('level', 'Nível')} ${driver.level}`

  const meInTop = drivers.some((driver) => driver.isMe)

  return (
    <div className="leaderboard-view">
      <div className="leaderboard-toolbar">
        <button className={metric === 'level' ? 'is-active' : ''} onClick={() => setMetric('level')}>{t('metric_level', 'Nível')}</button>
        <button className={metric === 'global' ? 'is-active' : ''} onClick={() => setMetric('global')}>{t('metric_global', 'Entregas globais')}</button>
        {me && !meInTop && (
          <span className="leaderboard-me">
            {t('your_position', 'Sua posição')}: {me.ranked && me.position ? `#${me.position}` : '—'}
          </span>
        )}
      </div>
      {!loading && drivers.length === 0 ? (
        <div className="board-empty board-empty--tall">
          <strong>{t('leaderboard_empty', 'Nenhum motorista classificado ainda.')}</strong>
        </div>
      ) : (
        <>
          <section className="podium">
            {drivers.slice(0, 3).map((driver, index) => (
              <article className={`podium-driver podium-driver--${index + 1} ${driver.isMe ? 'is-me' : ''}`} key={`${driver.name}-${index}`}>
                <img src={driver.avatar ?? './assets/images/test-pp.png'} alt="" />
                <span>#{index + 1}</span>
                <h2>{driver.name}</h2>
                <p>{valueOf(driver)}</p>
              </article>
            ))}
          </section>
          <section className="rank-list">
            {drivers.map((driver, index) => (
              <div className={`rank-row ${driver.isMe ? 'is-me' : ''}`} key={`${driver.name}-${index}`}>
                <strong>#{index + 1}</strong>
                <span>{driver.name}</span>
                <p>{valueOf(driver)}</p>
              </div>
            ))}
          </section>
        </>
      )}
    </div>
  )
}
