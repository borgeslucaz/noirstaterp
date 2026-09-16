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

  const selfFromList = drivers.find((driver) => driver.isMe)
  const selfPosition = me?.position ?? (selfFromList ? drivers.indexOf(selfFromList) + 1 : null)
  const self = me ?? (selfFromList
    ? {
        position: selfPosition,
        name: selfFromList.name,
        level: selfFromList.level,
        globalCompleted: selfFromList.globalCompleted,
        ranked: true,
      }
    : null)

  const row = (driver: LeaderboardEntry, index: number, selfRow = false) => (
    <div
      className={`rank-row ${driver.isMe || selfRow ? 'is-me' : ''} ${index === 0 && !selfRow ? 'rank-row--first' : ''}`}
      key={selfRow ? 'self' : `${driver.name}-${index}`}
    >
      <strong className="rank-row__position">{selfRow ? (selfPosition ? `${selfPosition}º` : '—') : `${index + 1}º`}</strong>
      <span className="rank-row__name">{driver.name}</span>
      <span className="rank-row__level">{t('level', 'Nível')} {driver.level}</span>
      <p className="rank-row__deliveries">{driver.globalCompleted} {t('deliveries', 'entregas')}</p>
    </div>
  )

  return (
    <div className="leaderboard-view">
      <div className="leaderboard-toolbar">
        <div>
          <p className="eyebrow">CLASSIFICAÇÃO DA CENTRAL</p>
          <h2>{t('leaderboard_intro', 'Caminhoneiros em destaque')}</h2>
        </div>
        <div className="leaderboard-filters" role="group" aria-label="Critério do ranking">
          <button className={metric === 'level' ? 'is-active' : ''} onClick={() => setMetric('level')}>{t('metric_level', 'Nível')}</button>
          <button className={metric === 'global' ? 'is-active' : ''} onClick={() => setMetric('global')}>{t('metric_global', 'Entregas globais')}</button>
        </div>
      </div>

      {self && (
        <section className="leaderboard-self" aria-label={t('your_position', 'Sua posição')}>
          <span className="leaderboard-self__label">{t('your_position', 'SUA POSIÇÃO')}</span>
          {row({
            rank: selfPosition ?? 0,
            name: self.name ?? t('driver', 'Motorista'),
            level: self.level ?? 1,
            globalCompleted: self.globalCompleted ?? 0,
            isMe: true,
          }, Math.max(0, (selfPosition ?? 1) - 1), true)}
        </section>
      )}

      {loading ? (
        <div className="board-empty board-empty--tall">
          <strong>{t('board_loading', 'Carregando classificação...')}</strong>
        </div>
      ) : drivers.length === 0 ? (
        <div className="board-empty board-empty--tall">
          <strong>{t('leaderboard_empty', 'Nenhum motorista classificado ainda.')}</strong>
        </div>
      ) : (
        <section className="rank-list" aria-label={t('leaderboard', 'Ranking')}>
          {drivers.map((driver, index) => row(driver, index))}
        </section>
      )}
    </div>
  )
}
